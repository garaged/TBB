import Testing
@testable import TBBFoundation

@Test func cloudKitConfigurationUsesTheTBBContainerAndTeam() {
    #expect(CloudKitConfiguration.containerIdentifier == "iCloud.org.garaged.TBB")
    #expect(CloudKitConfiguration.developerTeamIdentifier == "T3CCJTUTJ5")
}
