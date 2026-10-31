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
