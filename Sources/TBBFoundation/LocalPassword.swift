import Foundation

public enum PasswordValidationError: Error, Equatable, Sendable {
    case tooShort(minimumLength: Int)
    case containsLeadingOrTrailingWhitespace
}

public struct LocalPasswordPolicy: Sendable, Equatable {
    public let minimumLength: Int

    public init(minimumLength: Int = 8) {
        self.minimumLength = minimumLength
    }

    public func validate(_ password: String) throws {
        guard password.count >= minimumLength else {
            throw PasswordValidationError.tooShort(minimumLength: minimumLength)
        }
        guard password == password.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw PasswordValidationError.containsLeadingOrTrailingWhitespace
        }
    }
}

public struct PasswordCredentialRecord: Codable, Sendable, Equatable {
    public let formatVersion: Int
    public let salt: Data
    public let verifier: Data
    public let iterations: Int

    public init(formatVersion: Int = 1, salt: Data, verifier: Data, iterations: Int) {
        self.formatVersion = formatVersion
        self.salt = salt
        self.verifier = verifier
        self.iterations = iterations
    }
}

public protocol PasswordDeriving: Sendable {
    func derive(password: String, salt: Data, iterations: Int) throws -> Data
}

public struct LocalPasswordAuthenticator: Sendable {
    private let policy: LocalPasswordPolicy
    private let deriver: any PasswordDeriving

    public init(policy: LocalPasswordPolicy = .init(), deriver: any PasswordDeriving) {
        self.policy = policy
        self.deriver = deriver
    }

    public func createRecord(password: String, salt: Data, iterations: Int) throws -> PasswordCredentialRecord {
        try policy.validate(password)
        return PasswordCredentialRecord(
            salt: salt,
            verifier: try deriver.derive(password: password, salt: salt, iterations: iterations),
            iterations: iterations
        )
    }

    public func verify(password: String, against record: PasswordCredentialRecord) throws -> Bool {
        try policy.validate(password)
        let candidate = try deriver.derive(password: password, salt: record.salt, iterations: record.iterations)
        return constantTimeEqual(candidate, record.verifier)
    }

    private func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }
}

public protocol AppLockCredentialStore: Sendable {
    func loadPasswordRecord() throws -> PasswordCredentialRecord?
    func savePasswordRecord(_ record: PasswordCredentialRecord) throws
    func removePasswordRecord() throws
}
