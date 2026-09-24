import SwiftUI

struct ArtworkImage: View {
    let url: URL?

    var body: some View {
        GeometryReader { geo in
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    ZStack {
                        Color(.tertiarySystemFill)
                        Text("RM")
                            .font(.system(size: min(geo.size.width, geo.size.height) * 0.3, weight: .heavy))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }
}
