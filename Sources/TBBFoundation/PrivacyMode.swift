import Foundation

public enum PrivacyMode: String, Codable, Sendable, Equatable {
    case revealed
    case concealed

    public mutating func toggle() {
        self = self == .revealed ? .concealed : .revealed
    }

    public func displayAmount(_ revealedAmount: String) -> String {
        switch self {
        case .revealed: revealedAmount
        case .concealed: "••••"
        }
    }
}

public struct PrivacyPresentation: Sendable, Equatable {
    public let mode: PrivacyMode

    public init(mode: PrivacyMode) {
        self.mode = mode
    }

    public func amount(_ value: String) -> String {
        mode.displayAmount(value)
    }

    public var accessibilitySummary: String {
        mode == .revealed ? "Amounts shown" : "Amounts hidden"
    }
}
