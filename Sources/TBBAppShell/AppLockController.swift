#if canImport(SwiftUI) && canImport(CommonCrypto) && canImport(Security) && canImport(LocalAuthentication)
import Combine
import Foundation
import TBBFoundation

@MainActor
public final class AppLockController: ObservableObject {
    @Published public private(set) var state: AppLockState = .unlocked
    @Published public private(set) var isPasswordConfigured = false
    @Published public private(set) var errorMessage: String?

    private let store: any AppLockCredentialStore
    private let authenticator: LocalPasswordAuthenticator
    private let biometricClient: any LocalAuthenticationClient

    public init(
        store: any AppLockCredentialStore = KeychainAppLockCredentialStore(),
        biometricClient: any LocalAuthenticationClient = AppleLocalAuthenticationClient()
    ) {
        self.store = store
        self.authenticator = LocalPasswordAuthenticator(deriver: PBKDF2SHA256PasswordDeriver())
        self.biometricClient = biometricClient
        refreshConfiguration()
    }

    public func refreshConfiguration() {
        do {
            isPasswordConfigured = try store.loadPasswordRecord() != nil
        } catch {
            errorMessage = "TBB could not read its secure lock settings."
        }
    }

    public func lockForBackground() {
        guard isPasswordConfigured else { return }
        state = .locked
    }

    public func setPassword(_ password: String, confirmation: String) {
        guard password == confirmation else {
            errorMessage = "The passwords do not match."
            return
        }

        do {
            let salt = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
            let record = try authenticator.createRecord(password: password, salt: salt, iterations: 600_000)
            try store.savePasswordRecord(record)
            isPasswordConfigured = true
            errorMessage = nil
        } catch PasswordValidationError.tooShort {
            errorMessage = "Choose a password with at least eight characters."
        } catch PasswordValidationError.containsLeadingOrTrailingWhitespace {
            errorMessage = "Passwords cannot begin or end with whitespace."
        } catch {
            errorMessage = "TBB could not save the local password."
        }
    }

    public func unlockWithPassword(_ password: String) {
        do {
            guard let record = try store.loadPasswordRecord() else {
                state = .unlocked
                return
            }
            guard try authenticator.verify(password: password, against: record) else {
                errorMessage = "That password is not correct."
                return
            }
            state = .unlocked
            errorMessage = nil
        } catch {
            errorMessage = "TBB could not verify the local password."
        }
    }

    public func unlockWithDeviceAuthentication() async {
        do {
            try await biometricClient.authenticate(reason: "Unlock your private budget.")
            state = .unlocked
            errorMessage = nil
        } catch {
            errorMessage = "Device authentication was not available. Use your local password."
        }
    }

    public func removePassword() {
        do {
            try store.removePasswordRecord()
            isPasswordConfigured = false
            state = .unlocked
            errorMessage = nil
        } catch {
            errorMessage = "TBB could not remove the local password."
        }
    }
}
#endif
