import SwiftUI
import UIKit

// show full image from an article
struct ImageViewer: View {

    // use by the journalism article screen when user tap a photo
    let url: URL

    // close what is showing
    @Environment(\.dismiss) private var dismiss

    // the sharp 2500px image once downloaded
    @State private var fullImage: UIImage?
    @State private var loadFailed = false
    // close button and status bar visible
    @State private var showsControls = true

    // sharp image if loaded, otherwise the cached 1000px one
    private var image: UIImage? {
        fullImage ?? ArtworkCache.shared.image(for: url.squarespaceSized(1000))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image {
                // single tap shows or hides the close button
                ZoomableImageView(image: image) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showsControls.toggle()
                    }
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
        // close button in the top right
        .overlay(alignment: .topTrailing) {
            if showsControls {
                Button {
                    dismiss()
                } label: {
                    // icon only, voiceover still reads "Close"
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
        // hide the clock and home bar with the controls
        .statusBarHidden(!showsControls)
        .persistentSystemOverlays(showsControls ? .automatic : .hidden)
        .preferredColorScheme(.dark)
        // try the sharp image, fall back to the 1000px one
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

// glass button on ios 26, frosted circle before that
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

// home-made frosted circle button for older ios
private struct MaterialCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // apple's minimum tap target
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: Circle())
            // the whole circle is tappable
            .contentShape(Circle())
            // dim while pressed
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
