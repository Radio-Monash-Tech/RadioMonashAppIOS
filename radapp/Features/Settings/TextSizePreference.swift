import Foundation

enum TTextSizePreference {
    static let storageKey = "textSuzeOffset"
    static let range = -3...3
    
    static func label(for steps: Int) -> String {
        switch steps {
        case 0: "Match System"
        case ..<0: "Smaller (\(steps)"
        default: "Larger (+\(steps))"
        }
    }
}

extension View {
    func textSizeOffset(_ offset: Int) -> some View {
        modifier(TextSizeOffset(offset: offset))
    }
}

private struct TextSizeOffset: ViewModifier {
    let steps: Int
    @Environment(\.dynamicTypeSize) private var systemSize
    
    func body(content: Content) -> some View {
        content.dynamicTypeSize(systemSize.shifted(by: steps))
    }
}

private extension DynamicTypeSize {
    func shifted(by steps: Int) -> DynamicTypeSize {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else { return self }
        return all[min(max(index + steps, 0), all.count - 1)]
    }
}
