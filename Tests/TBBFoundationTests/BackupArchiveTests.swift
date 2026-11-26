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
#endif
