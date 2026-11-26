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
    let data: Data
}

private struct BackupPayload: Codable {
    let name: String
    let ledger: LedgerState
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
            envelope = BackupEnvelope(version: 1, encrypted: true, salt: salt, iterations: rounds, data: combined)
        } else {
            envelope = BackupEnvelope(version: 1, encrypted: false, salt: nil, iterations: nil, data: payload)
        }
        let output = try JSONEncoder().encode(envelope)
        guard output.count <= maximumBytes else { throw BackupArchiveError.tooLarge }
        return output
    }

    public static func decode(_ bytes: Data, password: String?) throws -> (name: String, ledger: LedgerState) {
        guard bytes.count <= maximumBytes else { throw BackupArchiveError.tooLarge }
        guard let envelope = try? JSONDecoder().decode(BackupEnvelope.self, from: bytes) else { throw BackupArchiveError.malformed }
        guard envelope.version == 1 else { throw BackupArchiveError.unsupportedVersion }
        let payload: Data
        if envelope.encrypted {
            guard let salt = envelope.salt, salt.count == 16, envelope.iterations == rounds,
                  let password, !password.isEmpty, password.utf8.count <= 1024 else { throw BackupArchiveError.invalidPassword }
            let key = try PBKDF2SHA256PasswordDeriver().derive(password: password, salt: salt, iterations: rounds)
            do {
                payload = try AES.GCM.open(AES.GCM.SealedBox(combined: envelope.data), using: SymmetricKey(data: key), authenticating: associatedData)
            } catch {
                throw BackupArchiveError.invalidPassword
            }
        } else {
            guard envelope.salt == nil, envelope.iterations == nil else { throw BackupArchiveError.malformed }
            payload = envelope.data
        }
        guard payload.count <= maximumBytes / 2,
              let decoded = try? JSONDecoder().decode(BackupPayload.self, from: payload),
              !decoded.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              decoded.name.count <= 80 else { throw BackupArchiveError.malformed }
        return (decoded.name, try BackupLedgerValidator.validate(decoded.ledger))
    }
}
#endif
