#if canImport(UIKit) && canImport(CryptoKit) && canImport(CommonCrypto) && canImport(Security)
import Foundation
import SwiftUI
import TBBFoundation
import UniformTypeIdentifiers

private extension UTType {
    static let budgetBackup = UTType(exportedAs: "org.garaged.tbb.backup", conformingTo: .data)
}

private struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.budgetBackup]
    let bytes: Data

    init(bytes: Data) { self.bytes = bytes }

    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents,
              bytes.count <= BackupArchive.maximumBytes else { throw BackupArchiveError.tooLarge }
        self.bytes = bytes
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: bytes)
    }
}

private func backupMessage(for error: Error) -> LocalizedStringKey {
    switch error {
    case BackupArchiveError.invalidPassword: "Check the backup password. A damaged encrypted file can also cause this error."
    case BackupArchiveError.unsupportedVersion: "This backup version requires a different version of TBB."
    case BackupArchiveError.tooLarge: "The backup exceeds the supported size."
    case BackupArchiveError.malformed, is BackupValidationError: "The backup format or budget data is invalid."
    default: "TBB could not complete the operation. Check file access and available storage."
    }
}

struct BackupExportView: View {
    @ObservedObject var model: LedgerViewModel
    let space: StoredBudgetSpace
    @State private var encrypted = true
    @State private var password = ""
    @State private var confirmation = ""
    @State private var warnPlaintext = false
    @State private var exporting = false
    @State private var document: BackupDocument?
    @State private var work: Task<Void, Never>?
    @State private var message: LocalizedStringKey?

    var body: some View {
        Form {
            Section("Selected budget") {
                Text(verbatim: space.name)
                if space.scope == .shared || space.role == .participant {
                    Text("This export includes household data. Anyone with a readable copy can keep it after sharing ends.")
                }
            }
            Section("File protection") {
                Toggle("Encrypt with a password", isOn: $encrypted)
                if encrypted {
                    SecureField("Backup password", text: $password).textContentType(.newPassword)
                    SecureField("Confirm backup password", text: $confirmation).textContentType(.newPassword)
                    Text("Keep this password for recovery. Resetting your TBB lock cannot recover a lost backup password.")
                } else {
                    Text("Anyone with this file can read and change your budget.")
                }
            }
            Button("Choose save location") {
                if encrypted { prepare() } else { warnPlaintext = true }
            }
            .disabled(encrypted && (password.isEmpty || password != confirmation || password.utf8.count > 1024))
            if work != nil { ProgressView("Preparing backup…") }
            if let message { Text(message) }
        }
        .disabled(work != nil)
        .navigationTitle("Export budget")
        .confirmationDialog("Export an unencrypted backup?", isPresented: $warnPlaintext, titleVisibility: .visible) {
            Button("Export readable file", role: .destructive) { prepare() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Anyone with this file can read and change your budget.")
        }
        .fileExporter(isPresented: $exporting, document: document, contentType: .budgetBackup,
                      defaultFilename: "TBB Backup") { result in
            switch result {
            case .success: message = "Backup saved."
            case .failure(let error): message = backupMessage(for: error)
            }
            document = nil
        }
        .onChange(of: encrypted) { _, enabled in
            if !enabled { password = ""; confirmation = "" }
        }
        .onChange(of: exporting) { _, presented in if !presented { document = nil } }
        .onDisappear { work?.cancel(); work = nil; password = ""; confirmation = "" }
    }

    private func prepare() {
        guard work == nil else { return }
        message = nil
        let secret = encrypted ? password : nil
        let name = space.name
        password = ""
        confirmation = ""
        work = Task {
            defer { if !Task.isCancelled { work = nil } }
            do {
                let state = try model.exportSnapshot(for: space.id)
                let bytes = try await Task.detached(priority: .userInitiated) {
                    try BackupArchive.encode(name: name, ledger: state, password: secret)
                }.value
                try Task.checkCancellation()
                document = BackupDocument(bytes: bytes)
                exporting = true
            } catch {
                if !Task.isCancelled { message = backupMessage(for: error) }
            }
        }
    }
}

private struct SelectedArchive: Sendable {
    let bytes: Data
    let encrypted: Bool

    init(url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        // Coordination also lets document providers materialize their files.
        var coordinationError: NSError?
        var result: Result<Data, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinated in
            result = Result {
                let values = try coordinated.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values.isRegularFile == true else { throw BackupArchiveError.malformed }
                guard (values.fileSize ?? 0) <= BackupArchive.maximumBytes else { throw BackupArchiveError.tooLarge }
                let handle = try FileHandle(forReadingFrom: coordinated)
                defer { try? handle.close() }
                var data = Data()
                while let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
                    guard data.count <= BackupArchive.maximumBytes - chunk.count else { throw BackupArchiveError.tooLarge }
                    data.append(chunk)
                }
                return data
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw BackupArchiveError.malformed }
        bytes = try result.get()
        encrypted = try BackupArchive.requiresPassword(bytes)
    }
}

struct BackupRestoreView: View {
    @ObservedObject var model: LedgerViewModel
    @State private var importing = false
    @State private var selected: SelectedArchive?
    @State private var password = ""
    @State private var preview: BackupPreview?
    @State private var restoredName = ""
    @State private var work: Task<Void, Never>?
    @State private var message: LocalizedStringKey?

    var body: some View {
        Form {
            Section {
                Button("Choose backup file") { importing = true }
            }
            if let preview {
                Section("Restore preview") {
                    if !preview.isEncrypted {
                        Text("This file is unencrypted and unauthenticated. Only restore it if you trust its source.")
                    }
                    LabeledContent("Archived budget", value: preview.name)
                    LabeledContent("Currency", value: preview.ledger.baseCurrencyCode)
                    LabeledContent("Accounts", value: preview.ledger.accounts.count.formatted())
                    LabeledContent("Categories", value: preview.ledger.categories.count.formatted())
                    LabeledContent("Transactions", value: preview.ledger.transactions.count.formatted())
                    LabeledContent("Budget plans", value: preview.ledger.budgets.count.formatted())
                }
                Section("New private budget") {
                    TextField("Copy name", text: $restoredName)
                    Text("Confirm to create a separate private budget. Your existing budgets and household sharing stay as they are.")
                    Button("Create private copy") { commit(preview) }
                        .disabled(restoredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || restoredName.count > 80)
                    Button("Cancel restore", role: .cancel) { clearSelection() }
                }
            } else if let selected {
                Section("Open backup") {
                    if selected.encrypted {
                        SecureField("Backup password", text: $password).textContentType(.password)
                    } else {
                        Text("This file is unencrypted and unauthenticated. Only restore it if you trust its source.")
                    }
                    Button("Preview backup") { validate(selected) }
                        .disabled(selected.encrypted && (password.isEmpty || password.utf8.count > 1024))
                    Button("Cancel restore", role: .cancel) { clearSelection() }
                }
            }
            if work != nil { ProgressView("Reading backup…") }
            if let message { Text(message) }
        }
        .disabled(work != nil)
        .navigationTitle("Restore backup")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.budgetBackup, .data]) { result in
            clearSelection()
            do {
                let url = try result.get()
                start {
                    let file = try await Task.detached(priority: .userInitiated) { try SelectedArchive(url: url) }.value
                    try Task.checkCancellation()
                    selected = file
                }
            } catch { message = backupMessage(for: error) }
        }
        .onDisappear { work?.cancel(); work = nil; clearSelection() }
    }

    private func start(_ operation: @escaping @MainActor () async throws -> Void) {
        guard work == nil else { return }
        message = nil
        work = Task {
            defer { if !Task.isCancelled { work = nil } }
            do { try await operation() }
            catch { if !Task.isCancelled { message = backupMessage(for: error) } }
        }
    }

    private func validate(_ file: SelectedArchive) {
        let secret = file.encrypted ? password : nil
        password = ""
        start {
            let result = try await Task.detached(priority: .userInitiated) {
                try BackupArchive.decode(file.bytes, password: secret)
            }.value
            try Task.checkCancellation()
            let prefix = String(localized: "Restored – ")
            restoredName = String((prefix + result.name).prefix(80))
            preview = result
            selected = nil
        }
    }

    private func commit(_ snapshot: BackupPreview) {
        guard preview != nil else { return }
        do {
            try model.restore(snapshot, name: restoredName)
            clearSelection()
            message = "Private copy created and selected."
        } catch { message = backupMessage(for: error) }
    }

    private func clearSelection() {
        selected = nil
        preview = nil
        password = ""
        restoredName = ""
        message = nil
    }
}
#endif
