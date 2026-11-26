#if canImport(CryptoKit) && canImport(CommonCrypto) && canImport(Security)
import Foundation
import CryptoKit
import Security

public enum BackupArchiveError: Error, Equatable {
    case malformed
    case unsupportedVersion
    case tooLarge
    case invalidPassword
    case randomFailure
}

private struct BackupEnvelope: Codable {
    let version: Int
    let encrypted: Bool
    let salt: Data?
    let iterations: Int?
    let checksum: Data?
    let data: Data
}

private struct BackupPayload: Codable {
    let name: String
    let ledger: LedgerState

    private enum LedgerKeys: String, CodingKey { case budgets }

    init(name: String, ledger: LedgerState) {
        self.name = name
        self.ledger = ledger
    }

    init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let ledgerFields = try fields.nestedContainer(keyedBy: LedgerKeys.self, forKey: .ledger)
        // Old on-device snapshots may omit budgets. Every portable v1 payload includes them.
        guard ledgerFields.contains(.budgets), try !ledgerFields.decodeNil(forKey: .budgets) else {
            throw BackupArchiveError.malformed
        }
        name = try fields.decode(String.self, forKey: .name)
        ledger = try fields.decode(LedgerState.self, forKey: .ledger)
    }
}

/// An authenticated (or explicitly unencrypted), validated snapshot. Only the codec constructs it.
public struct BackupPreview: Sendable {
    public let name: String
    public let ledger: LedgerState
    public let isEncrypted: Bool
    let storePayload: Data

    fileprivate init(name: String, ledger: LedgerState, isEncrypted: Bool) throws {
        self.name = name
        self.isEncrypted = isEncrypted
        self.ledger = try BackupLedgerValidator.validate(ledger)
        storePayload = try JSONEncoder().encode(ledger)
    }
}

/// Portable archive codec. Never logs archive contents or credentials.
public enum BackupArchive {
    public static let maximumBytes = 16 * 1_024 * 1_024
    private static let rounds = 600_000
    private static let associatedData = Data("TBB-backup-v1-PBKDF2-SHA256-AES-GCM".utf8)

    public static func encode(name: String, ledger: LedgerState, password: String?) throws -> Data {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 80 else {
            throw BackupArchiveError.malformed
        }
        let validated = try BackupLedgerValidator.validate(ledger)
        let payload = try JSONEncoder().encode(BackupPayload(name: name, ledger: validated))
        guard payload.count <= maximumBytes / 2 else { throw BackupArchiveError.tooLarge }
        let envelope: BackupEnvelope
        if let password {
            guard !password.isEmpty, password.utf8.count <= 1024 else { throw BackupArchiveError.invalidPassword }
            var salt = Data(count: 16)
            let status = salt.withUnsafeMutableBytes { buffer in
                SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
            }
            guard status == errSecSuccess else { throw BackupArchiveError.randomFailure }
            let key = try PBKDF2SHA256PasswordDeriver().derive(password: password, salt: salt, iterations: rounds)
            let sealed = try AES.GCM.seal(payload, using: SymmetricKey(data: key), authenticating: associatedData)
            guard let combined = sealed.combined else { throw BackupArchiveError.malformed }
            envelope = BackupEnvelope(version: 1, encrypted: true, salt: salt, iterations: rounds, checksum: nil, data: combined)
        } else {
            envelope = BackupEnvelope(version: 1, encrypted: false, salt: nil, iterations: nil, checksum: Data(SHA256.hash(data: payload)), data: payload)
        }
        let output = try JSONEncoder().encode(envelope)
        guard output.count <= maximumBytes else { throw BackupArchiveError.tooLarge }
        return output
    }

    /// Inspects the protection mode without deriving a key or decoding private content.
    public static func requiresPassword(_ bytes: Data) throws -> Bool {
        try readEnvelope(bytes).encrypted
    }

    private static func readEnvelope(_ bytes: Data) throws -> BackupEnvelope {
        guard bytes.count <= maximumBytes else { throw BackupArchiveError.tooLarge }
        guard let envelope = try? JSONDecoder().decode(BackupEnvelope.self, from: bytes) else {
            throw BackupArchiveError.malformed
        }
        guard envelope.version == 1 else { throw BackupArchiveError.unsupportedVersion }
        let overhead = envelope.encrypted ? 28 : 0
        guard envelope.data.count <= maximumBytes / 2 + overhead else { throw BackupArchiveError.tooLarge }
        if envelope.encrypted {
            guard envelope.data.count >= overhead, envelope.salt?.count == 16,
                  envelope.iterations == rounds, envelope.checksum == nil else {
                throw BackupArchiveError.malformed
            }
        } else {
            guard envelope.salt == nil, envelope.iterations == nil,
                  envelope.checksum?.count == 32 else { throw BackupArchiveError.malformed }
        }
        return envelope
    }

    public static func decode(_ bytes: Data, password: String?) throws -> BackupPreview {
        let envelope = try readEnvelope(bytes)
        let payload: Data
        if envelope.encrypted {
            guard let salt = envelope.salt, let password, !password.isEmpty,
                  password.utf8.count <= 1024 else { throw BackupArchiveError.invalidPassword }
            let key = try PBKDF2SHA256PasswordDeriver().derive(password: password, salt: salt, iterations: rounds)
            do {
                let box = try AES.GCM.SealedBox(combined: envelope.data)
                payload = try AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: associatedData)
            } catch {
                throw BackupArchiveError.invalidPassword
            }
        } else {
            guard password == nil, envelope.checksum == Data(SHA256.hash(data: envelope.data)) else {
                throw BackupArchiveError.malformed
            }
            payload = envelope.data
        }
        guard let decoded = try? JSONDecoder().decode(BackupPayload.self, from: payload),
              !decoded.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              decoded.name.count <= 80 else { throw BackupArchiveError.malformed }
        return try BackupPreview(name: decoded.name, ledger: decoded.ledger, isEncrypted: envelope.encrypted)
    }
}
#endif
