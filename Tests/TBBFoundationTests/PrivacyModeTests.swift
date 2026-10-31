import Testing
@testable import TBBFoundation

@Test func privacyModeMasksAmountsAndCanToggle() {
    var mode = PrivacyMode.revealed
    #expect(mode.displayAmount("$1,234.56") == "$1,234.56")

    mode.toggle()
    #expect(mode == .concealed)
    #expect(mode.displayAmount("$1,234.56") == "••••")
    #expect(PrivacyPresentation(mode: mode).accessibilitySummary == "Amounts hidden")
}

@Test func requiredLockStartsLockedAndLocksOnBackground() {
    let policy = AppLockPolicy(requiresLock: true)
    #expect(policy.reduce(state: .unlocked, event: .launched) == .locked)
    #expect(policy.reduce(state: .unlocked, event: .enteredBackground) == .locked)
    #expect(policy.reduce(state: .locked, event: .authenticationSucceeded) == .unlocked)
}

@Test func disabledLockNeverBlocksTheUser() {
    let policy = AppLockPolicy(requiresLock: false)
    #expect(policy.reduce(state: .unlocked, event: .enteredBackground) == .unlocked)
    #expect(policy.reduce(state: .locked, event: .launched) == .unlocked)
}
