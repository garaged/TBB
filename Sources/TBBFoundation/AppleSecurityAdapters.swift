#if canImport(LocalAuthentication)
import Foundation
import LocalAuthentication

public enum LocalAuthenticationError: Error, Equatable, Sendable {
    case unavailable
    case failed
}

public struct AppleLocalAuthenticationClient: LocalAuthenticationClient {
    public init() {}

    public func authenticate(reason: String) async throws {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw LocalAuthenticationError.unavailable
        }

        do {
            try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            throw LocalAuthenticationError.failed
        }
    }
}
#endif

#if canImport(CommonCrypto)
import CommonCrypto

public enum PasswordDerivationError: Error, Equatable, Sendable {
    case invalidParameters
    case derivationFailed
}

public struct PBKDF2SHA256PasswordDeriver: PasswordDeriving {
    public let outputLength: Int

    public init(outputLength: Int = 32) {
        self.outputLength = outputLength
    }

    public func derive(password: String, salt: Data, iterations: Int) throws -> Data {
        guard !salt.isEmpty, iterations > 0, outputLength > 0 else {
            throw PasswordDerivationError.invalidParameters
        }

        let saltBytes = Array(salt)
        var output = Array(repeating: UInt8(0), count: outputLength)
        let status = password.withCString { passwordPointer in
            saltBytes.withUnsafeBufferPointer { saltPointer in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordPointer,
                    password.utf8.count,
                    saltPointer.baseAddress,
                    saltBytes.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    &output,
                    outputLength
                )
            }
        }

        guard status == kCCSuccess else {
            throw PasswordDerivationError.derivationFailed
        }
        return Data(output)
    }
}
#endif

#if canImport(Security)
import Security

public enum KeychainCredentialStoreError: Error, Equatable, Sendable {
    case unexpectedStatus(Int32)
    case invalidStoredRecord
}

public struct KeychainAppLockCredentialStore: AppLockCredentialStore {
    private let service: String
    private let account: String

    public init(service: String = "org.garaged.TBB", account: String = "local-app-lock") {
        self.service = service
        self.account = account
    }

    public func loadPasswordRecord() throws -> PasswordCredentialRecord? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainCredentialStoreError.unexpectedStatus(status)
        }
        guard let record = try? JSONDecoder().decode(PasswordCredentialRecord.self, from: data) else {
            throw KeychainCredentialStoreError.invalidStoredRecord
        }
        return record
    }

    public func savePasswordRecord(_ record: PasswordCredentialRecord) throws {
        let data = try JSONEncoder().encode(record)
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainCredentialStoreError.unexpectedStatus(updateStatus)
        }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainCredentialStoreError.unexpectedStatus(addStatus)
        }
    }

    public func removePasswordRecord() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainCredentialStoreError.unexpectedStatus(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
#endif
