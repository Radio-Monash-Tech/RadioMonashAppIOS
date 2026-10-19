import SwiftUI

struct HeartBurstOverlay: View {
    let trigger: Int
    @State private var hearts: [Heart] = []

    private struct Heart: Identifiable {
        let id = UUID()
        var x: CGFloat
        var size: CGFloat
        var rotation: Double
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(hearts) { heart in
                    FloatingHeart(size: heart.size, rotation: heart.rotation)
                        .position(x: heart.x, y: geo.size.height - 60)
                }
            }
            .onChange(of: trigger) { _, _ in burst(width: geo.size.width) }
        }
        .allowsHitTesting(false)
    }

    private func burst(width: CGFloat) {
        guard width > 1 else { return }
        for i in 0..<12 {
            let heart = Heart(
                x: .random(in: 24...max(25, width - 24)),
                size: .random(in: 16...26),
                rotation: .random(in: -15...15)
            )
            hearts.append(heart)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1 + Double(i) * 0.02) {
                hearts.removeAll { $0.id == heart.id }
            }
        }
    }
}

private struct FloatingHeart: View {
    let size: CGFloat
    let rotation: Double
    @State private var animate = false

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size))
            .foregroundStyle(PlayerPalette.error)
            .rotationEffect(.degrees(rotation))
            .offset(y: animate ? -420 : 0)
            .opacity(animate ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1)) { animate = true }
            }
    }
}
