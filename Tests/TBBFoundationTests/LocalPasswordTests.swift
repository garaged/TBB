import Foundation
import Testing
@testable import TBBFoundation

private struct TestDeriver: PasswordDeriving {
    func derive(password: String, salt: Data, iterations: Int) throws -> Data {
        Data("\(password)|\(salt.base64EncodedString())|\(iterations)".utf8)
    }
}

@Test func localPasswordRejectsWeakOrAmbiguousInput() {
    let policy = LocalPasswordPolicy(minimumLength: 8)
    #expect(throws: PasswordValidationError.tooShort(minimumLength: 8)) {
        try policy.validate("short")
    }
    #expect(throws: PasswordValidationError.containsLeadingOrTrailingWhitespace) {
        try policy.validate(" password")
    }
}

@Test func localPasswordRecordVerifiesWithoutPersistingThePassword() throws {
    let authenticator = LocalPasswordAuthenticator(deriver: TestDeriver())
    let record = try authenticator.createRecord(
        password: "a-safe-password",
        salt: Data([1, 2, 3, 4]),
        iterations: 100
    )

    #expect(record.verifier != Data("a-safe-password".utf8))
    #expect(try authenticator.verify(password: "a-safe-password", against: record))
    #expect(!(try authenticator.verify(password: "not-the-password", against: record)))
}
