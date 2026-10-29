import UIKit

/// Pinch, pan and double-tap zoom for one image. Based on Jonny Townend's
/// PanZoomImageView ("Creating a Zoomable Image View in Swift", Better
/// Programming, 2021): an image view the size of the scroll view, which
/// handles the zooming and panning itself.
final class PanZoomImageView: UIScrollView, UIScrollViewDelegate {
    var onSingleTap: () -> Void = {}

    var image: UIImage? {
        get { imageView.image }
        set {
            imageView.image = newValue
            setZoomScale(minimumZoomScale, animated: false)
        }
    }

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // Setup image view
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = true
        imageView.accessibilityTraits = .image
        imageView.accessibilityLabel = "Image"
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalTo: widthAnchor),
            imageView.heightAnchor.constraint(equalTo: heightAnchor),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        // Setup scroll view
        minimumZoomScale = 1
        maximumZoomScale = 3
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        // The viewer is full screen; safe-area insets would push the image off centre.
        contentInsetAdjustmentBehavior = .never
        delegate = self

        // Setup tap gestures: double tap zooms, single tap shows or hides the close button
        let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTapRecognizer)

        let singleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTapRecognizer.require(toFail: doubleTapRecognizer)
        addGestureRecognizer(singleTapRecognizer)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    @objc private func handleDoubleTap(_ sender: UITapGestureRecognizer) {
        if zoomScale == 1 {
            setZoomScale(2, animated: true)
        } else {
            setZoomScale(1, animated: true)
        }
    }

    @objc private func handleSingleTap() {
        onSingleTap()
    }
}
