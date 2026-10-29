import SwiftUI
import UIKit

/// A full-screen photo from an article: pinch or double-tap to zoom, tap to
/// show or hide the close button. Shows the cached copy straight away, then
/// swaps in a sharper one.
struct ImageViewer: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var fullImage: UIImage?
    @State private var loadFailed = false
    @State private var showsControls = true

    private var image: UIImage? {
        fullImage ?? ArtworkCache.shared.image(for: url.squarespaceSized(1000))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image {
                ZoomableImageView(image: image) {
                    withAnimation(.easeInOut(duration: 0.2)) { showsControls.toggle() }
                }
                .ignoresSafeArea()
            } else if loadFailed {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .overlay(alignment: .topTrailing) {
            if showsControls {
                Button { dismiss() } label: {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                        .font(.body.weight(.semibold))
                        .padding(6)
                }
                .modifier(CloseButtonStyle())
                .padding(.trailing, 16)
                .transition(.opacity)
            }
        }
        .statusBarHidden(!showsControls)
        .persistentSystemOverlays(showsControls ? .automatic : .hidden)
        .preferredColorScheme(.dark)
        .task {
            if let loaded = await ArtworkCache.shared.load(url.squarespaceSized(2500)) {
                fullImage = loaded
            } else if image == nil {
                fullImage = await ArtworkCache.shared.load(url.squarespaceSized(1000))
                loadFailed = fullImage == nil
            }
        }
    }
}

private struct CloseButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        } else {
            content.buttonStyle(MaterialCircleButtonStyle())
        }
    }
}

private struct MaterialCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: Circle())
            .contentShape(Circle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
