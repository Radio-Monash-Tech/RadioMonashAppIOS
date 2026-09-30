import SwiftUI

/// One line of text that scrolls in a loop when it's too long to fit, like
/// the song title in Apple Music's player. Text that fits stays still.
struct MarqueeText: View {
    let text: String
    let font: Font
    var alignment: Alignment = .leading

    /// Space between the end of the text and its repeat.
    private let gap: CGFloat = 36
    /// Scroll speed in points per second.
    private let speed: CGFloat = 30
    /// Pause at the start of each loop so the beginning can be read.
    private let pause: TimeInterval = 2.5
    /// Room at each end where the text fades out. It sits just outside the
    /// line, so the first and last letters are never faded while still.
    private let edgeInset: CGFloat = 10

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var startDate = Date.now

    init(_ text: String, font: Font, alignment: Alignment = .leading) {
        self.text = text
        self.font = font
        self.alignment = alignment
    }

    private var scrolls: Bool {
        !reduceMotion && containerWidth > 0 && textWidth > containerWidth
    }

    var body: some View {
        // The hidden copy sets the line's height and takes the width on offer.
        label
            .lineLimit(1)
            .hidden()
            .frame(maxWidth: .infinity, alignment: alignment)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
            .overlay(alignment: scrolls ? .leading : alignment) {
                if scrolls {
                    TimelineView(.animation) { context in
                        HStack(spacing: gap) {
                            label
                            label
                        }
                        .fixedSize()
                        .padding(.leading, edgeInset)
                        .offset(x: offset(at: context.date))
                    }
                    .frame(width: containerWidth + edgeInset * 2, alignment: .leading)
                    .clipped()
                    .mask(fade)
                    .padding(.leading, -edgeInset)
                } else {
                    label.lineLimit(1)
                }
            }
            .background(alignment: .leading) {
                // Measures the full, untruncated width.
                label
                    .fixedSize()
                    .hidden()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { textWidth = $0 }
            }
            .onChange(of: text) { startDate = .now }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
    }

    private var label: some View {
        Text(text).font(font)
    }

    private func offset(at date: Date) -> CGFloat {
        let distance = textWidth + gap
        let loop = pause + distance / speed
        let elapsed = date.timeIntervalSince(startDate).truncatingRemainder(dividingBy: loop)
        guard elapsed > pause else { return 0 }
        return -CGFloat(elapsed - pause) * speed
    }

    private var fade: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: edgeInset)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: edgeInset)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        MarqueeText("Short title", font: .headline)
        MarqueeText("Lullaby (Life on Erid) [from \"Project Hail Mary\"] – Original Motion Picture Score",
                    font: .headline)
        MarqueeText("Centred when it fits", font: .title2.bold(), alignment: .center)
    }
    .frame(width: 260)
    .padding()
}
