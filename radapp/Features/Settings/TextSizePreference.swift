import SwiftUI

// the app's own text size, up to 3 steps either side of the phone's
enum TextSizePreference {
    static let storageKey = "textSizeOffset"
    static let range = -3...3

    // "Match System", "Smaller (-2)" or "Larger (+1)"
    static func label(for steps: Int) -> String {
        switch steps {
        case 0:
            "Match System"
        case ..<0:
            "Smaller (\(steps))"
        default:
            "Larger (+\(steps))"
        }
    }
}

extension View {
    func textSizeOffset(_ steps: Int) -> some View {
        modifier(TextSizeOffset(steps: steps))
    }
}

// moves the phone's text size up or down by some steps
private struct TextSizeOffset: ViewModifier {
    let steps: Int
    @Environment(\.dynamicTypeSize) private var systemSize

    func body(content: Content) -> some View {
        content.dynamicTypeSize(systemSize.shifted(by: steps))
    }
}

private extension DynamicTypeSize {
    // the size some steps away, kept within the smallest and largest
    func shifted(by steps: Int) -> DynamicTypeSize {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else {
            return self
        }
        let shifted = index + steps
        let clamped = min(max(shifted, 0), all.count - 1)
        return all[clamped]
    }
}
