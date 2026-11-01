import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font
    var alignment: Alignment = .leading

    // space b/ end of the text
    private let gap: CGFloat = 36
    // scroll speed in points per second.
    private let speed: CGFloat = 30
    // pause at the start of each loop so the beginning can be read.
    private let pause: TimeInterval = 2.5
    // room at each end where the text fades out. It sits just outside the
    private let edgeInset: CGFloat = 10

    // never scroll when the user turned on reduce motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // full width of the text and the width available
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    // when the current scroll loop began
    @State private var startDate = Date.now

    // lets callers write MarqueeText("song") without the text label
    init(_ text: String, font: Font, alignment: Alignment = .leading) {
        self.text = text
        self.font = font
        self.alignment = alignment
    }

    // only scroll when the text is too wide to fit
    private var scrolls: Bool {
        !reduceMotion && containerWidth > 0 && textWidth > containerWidth
    }

    var body: some View {
        // The hidden copy sets the line's height and takes the width on offer.
        label
            .lineLimit(1)
            .hidden()
            .frame(maxWidth: .infinity, alignment: alignment)
            // measure the width available
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.width
            } action: { width in
                containerWidth = width
            }
            .overlay(alignment: scrolls ? .leading : alignment) {
                if scrolls {
                    // redraws every frame
                    TimelineView(.animation) { context in
                        // two copies so the loop looks endless
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
                    // move the fade just outside the line
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
                    .onGeometryChange(for: CGFloat.self) { geometry in
                        geometry.size.width
                    } action: { width in
                        textWidth = width
                    }
            }
            // restart the loop when the song changes
            .onChange(of: text) {
                startDate = .now
            }
            // voiceover reads the text once, not every copy
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
    }

    // the text with its font, reused in every copy
    private var label: some View {
        Text(text).font(font)
    }

    // how far left the text has moved at this moment
    private func offset(at date: Date) -> CGFloat {
        let distance = textWidth + gap
        let loop = pause + distance / speed
        // seconds into the current loop
        let elapsed = date.timeIntervalSince(startDate).truncatingRemainder(dividingBy: loop)
        // still in the pause at the start
        guard elapsed > pause else {
            return 0
        }
        return -CGFloat(elapsed - pause) * speed
    }

    // fades the text out at both edges
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

// short, long and centred examples
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
