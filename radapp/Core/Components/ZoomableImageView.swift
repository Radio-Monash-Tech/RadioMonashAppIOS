import SwiftUI
import UIKit

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
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
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

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    var onSingleTap: () -> Void = {}

    func makeUIView(context: Context) -> ZoomingScrollView {
        let view = ZoomingScrollView()
        view.image = image
        view.onSingleTap = onSingleTap
        return view
    }

    func updateUIView(_ view: ZoomingScrollView, context: Context) {
        if view.image !== image { view.image = image }
        view.onSingleTap = onSingleTap
    }
}

final class ZoomingScrollView: UIScrollView, UIScrollViewDelegate {
    var onSingleTap: () -> Void = {}

    var image: UIImage? {
        get { imageView.image }
        set {
            imageView.image = newValue
            setNeedsLayout()
        }
    }

    private let imageView = UIImageView()
    private var fittedSize: CGSize = .zero
    private let doubleTapZoomScale: CGFloat = 2.5

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 5
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .fast

        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = true
        imageView.accessibilityTraits = .image
        imageView.accessibilityLabel = "Image"
        addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTap.require(toFail: doubleTap)
        addGestureRecognizer(singleTap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = aspectFitSize()
        if abs(size.width - fittedSize.width) > 0.5 || abs(size.height - fittedSize.height) > 0.5 {
            fittedSize = size
            zoomScale = minimumZoomScale
            imageView.frame = CGRect(origin: .zero, size: size)
            contentSize = size
        }
        centerImage()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }

    private func aspectFitSize() -> CGSize {
        guard let imageSize = imageView.image?.size,
              imageSize.width > 0, imageSize.height > 0,
              bounds.width > 0, bounds.height > 0
        else { return .zero }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private func centerImage() {
        let x = max(0, (bounds.width - imageView.frame.width) / 2)
        let y = max(0, (bounds.height - imageView.frame.height) / 2)
        let inset = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
        if contentInset != inset { contentInset = inset }
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale {
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let size = CGSize(width: bounds.width / doubleTapZoomScale, height: bounds.height / doubleTapZoomScale)
            let rect = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                              width: size.width, height: size.height)
            zoom(to: rect, animated: true)
        }
    }

    @objc private func handleSingleTap() {
        onSingleTap()
    }
}
