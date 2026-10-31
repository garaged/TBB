import Foundation

public enum AppLockState: Sendable, Equatable {
    case unlocked
    case locked
}

public enum AppLifecycleEvent: Sendable, Equatable {
    case launched
    case enteredBackground
    case becameActive
    case authenticationSucceeded
    case authenticationFailed
}

public struct AppLockPolicy: Sendable, Equatable {
    public var requiresLock: Bool
    public var lockWhenBackgrounded: Bool

    public init(requiresLock: Bool = false, lockWhenBackgrounded: Bool = true) {
        self.requiresLock = requiresLock
        self.lockWhenBackgrounded = lockWhenBackgrounded
    }

    public func reduce(state: AppLockState, event: AppLifecycleEvent) -> AppLockState {
        guard requiresLock else { return .unlocked }

        switch event {
        case .launched, .authenticationFailed:
            return .locked
        case .enteredBackground:
            return lockWhenBackgrounded ? .locked : state
        case .becameActive:
            return state
        case .authenticationSucceeded:
            return .unlocked
        }
    }
}

public protocol LocalAuthenticationClient: Sendable {
    func authenticate(reason: String) async throws
}
