#if canImport(CryptoKit) && canImport(CommonCrypto) && canImport(Security)
import Foundation
import Testing
@testable import TBBFoundation

@Test func encryptedBackupRoundTripAndWrongPassword() throws {
    let ledger = try LedgerState(baseCurrencyCode: "MXN")
    let archive = try BackupArchive.encode(name: "Household", ledger: ledger, password: "test password")
    #expect(!String(decoding: archive, as: UTF8.self).contains("Household"))
    let restored = try BackupArchive.decode(archive, password: "test password")
    #expect(restored.name == "Household")
    #expect(restored.ledger == ledger)
    #expect(throws: BackupArchiveError.invalidPassword) {
        try BackupArchive.decode(archive, password: "wrong password")
    }
}

@Test func plainBackupRoundTripAndTruncation() throws {
    let ledger = try LedgerState(baseCurrencyCode: "USD")
    let archive = try BackupArchive.encode(name: "Personal", ledger: ledger, password: nil)
    #expect(try BackupArchive.decode(archive, password: nil).ledger == ledger)
    #expect(throws: BackupArchiveError.malformed) {
        try BackupArchive.decode(Data(archive.prefix(10)), password: nil)
    }
}

// Independent Python fixture. See docs/specs/TBB-BKP-001.md for the exact inputs.
@Test func readsIndependentV1Archive() throws {
    let bytes = Data(#"{"version":1,"encrypted":true,"salt":"AAECAwQFBgcICQoLDA0ODw==","iterations":600000,"data":"AAECAwQFBgcICQoLbPXX0TmSYxtPyUtF2sztEq1fQwstZZqKadPyJODDckcNnA9SQjInHkDH0UsiW/ZFYDRoDMIrYVarWInb6egFSQjnxTVXs7s+i5AH5K8HD5q6r1VD4F2PN7C0Nrv9ADtUqsDi2sM0y6M41jWb5Bk+hOtMwv6No5vU4IN+pw87DMDjb8o="}"#.utf8)
    let result = try BackupArchive.decode(bytes, password: "fixture-ñ")
    #expect(result.name == "Fixture")
    let expected = try LedgerState(baseCurrencyCode: "MXN")
    #expect(result.ledger == expected)
}

@Test func readsIndependentV2ArchiveAndLegacyPlaintext() throws {
    let encrypted = Data(#"{"version":2,"encrypted":true,"salt":"AAECAwQFBgcICQoLDA0ODw==","iterations":600000,"data":"AAECAwQFBgcICQoLbPXX0TmSYxtPyUtF2sztEq1fQwstZZqKadPyJODDckcNnA9SQjInHkDH0UsiW/ZFYDRoDMIrYVarWInb6egFSQjnxTVXs7s+i5AH5K8HD5q6r1VD4F2PN7C0Nrv9ADtUqsDi2sM0y6M41jWb5Bk+hOtMwhodBCXuCaCpw5uS2n60LsA="}"#.utf8)
    let plain = Data(#"{"version":1,"encrypted":false,"data":"eyJuYW1lIjoiRml4dHVyZSIsImxlZGdlciI6eyJiYXNlQ3VycmVuY3lDb2RlIjoiTVhOIiwiYWNjb3VudHMiOltdLCJjYXRlZ29yaWVzIjpbXSwidHJhbnNhY3Rpb25zIjpbXSwiYnVkZ2V0cyI6W119fQ=="}"#.utf8)
    let modern = try BackupArchive.preflight(encrypted, password: "fixture-ñ")
    let legacy = try BackupArchive.preflight(plain, password: nil)
    #expect(modern.isEncrypted)
    #expect(!legacy.isEncrypted)
    #expect(modern.ledger == legacy.ledger)
    #expect(legacy.name == "Fixture")
}

private func envelope(_ bytes: Data) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
}

@Test func rejectsModifiedHeadersAndDamagedData() throws {
    let ledger = try LedgerState(baseCurrencyCode: "USD")
    let secure = try BackupArchive.encode(name: "Private", ledger: ledger, password: "test")
    let original = try envelope(secure)
    func rewrite(_ field: String, _ value: Any) throws -> Data {
        var fields = original
        fields[field] = value
        return try JSONSerialization.data(withJSONObject: fields)
    }
    #expect(throws: BackupArchiveError.unsupportedVersion) {
        try BackupArchive.decode(rewrite("version", 99), password: "test")
    }
    #expect(throws: BackupArchiveError.malformed) {
        try BackupArchive.decode(rewrite("iterations", Int.max), password: "test")
    }
    #expect(throws: BackupArchiveError.malformed) {
        try BackupArchive.decode(rewrite("encrypted", false), password: nil)
    }
    let sealedText = try #require(original["data"] as? String)
    #expect(throws: BackupArchiveError.invalidPassword) {
        try BackupArchive.decode(rewrite("version", 1), password: "test")
    }
    var sealed = try #require(Data(base64Encoded: sealedText))
    sealed[sealed.count - 1] ^= 1
    #expect(throws: BackupArchiveError.invalidPassword) {
        try BackupArchive.decode(rewrite("data", sealed.base64EncodedString()), password: "test")
    }
    let second = try envelope(BackupArchive.encode(name: "Private", ledger: ledger, password: "test"))
    #expect(original["salt"] as? String != second["salt"] as? String)
    let secondSealedText = try #require(second["data"] as? String)
    let secondSealed = try #require(Data(base64Encoded: secondSealedText))
    #expect(sealed.prefix(12) != secondSealed.prefix(12))

    let plain = try BackupArchive.encode(name: "Private", ledger: ledger, password: nil)
    var damaged = try envelope(plain)
    damaged["data"] = Data("{}".utf8).base64EncodedString()
    #expect(throws: BackupArchiveError.malformed) {
        try BackupArchive.decode(JSONSerialization.data(withJSONObject: damaged), password: nil)
    }
    #expect(throws: BackupArchiveError.tooLarge) {
        try BackupArchive.decode(Data(count: BackupArchive.maximumBytes + 1), password: nil)
    }
}

@Test func encryptedExportContainsOnlyPublicHeaderAndOpaqueBytes() throws {
    var state = try LedgerState(baseCurrencyCode: "MXN")
    let cash = try LedgerAccount(name: "Cash", kind: .cash, currencyCode: "MXN")
    let food = LedgerCategory(name: "Groceries", kind: .expense)
    try state.addAccount(cash)
    try state.addCategory(food)
    try state.recordExpense(amount: Money(minorUnits: 1200, currencyCode: "MXN"), accountID: cash.id,
                            categoryID: food.id, occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
                            note: "sensitive receipt marker")
    try state.addBudget(.init(categoryID: food.id, cadence: .month, plannedMinorUnits: 8500))
    let bytes = try BackupArchive.encode(name: "Household", ledger: state, password: "backup secret")
    let fields = try envelope(bytes)
    #expect(Set(fields.keys) == ["version", "encrypted", "salt", "iterations", "data"])
    let combinedText = try #require(fields["data"] as? String)
    let combined = try #require(Data(base64Encoded: combinedText))
    for secret in ["sensitive receipt marker", "Household", "backup secret", cash.id.uuidString] {
        #expect(combined.range(of: Data(secret.utf8)) == nil)
    }
    #expect(try BackupArchive.decode(bytes, password: "backup secret").ledger == state)
}
#endif
