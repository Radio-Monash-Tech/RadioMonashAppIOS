import UIKit

// uikit scroll view that pinches, pans and double-tap zooms one image
final class PanZoomImageView: UIScrollView, UIScrollViewDelegate {
    // MARK: - Image and taps

    // called on a single tap
    var onSingleTap: () -> Void = {}

    // get an image and allow user to set the zoom length
    var image: UIImage? {
        get {
            imageView.image
        }
        set {
            imageView.image = newValue
            setZoomScale(minimumZoomScale, animated: false)
        }
    }

    // display the image
    private let imageView = UIImageView()

    // MARK: - Setup

    // created in code
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    // swift force every subclass to load Storyboad or XIB file
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    // shared setup for both inits
    private func commonInit() {
        // setup image view
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = true
        imageView.accessibilityTraits = .image

        // support for accessibility
        imageView.accessibilityLabel = "Image"

        // put image into scroll view
        addSubview(imageView)
        // same size as the scroll view and centred
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalTo: widthAnchor),
            imageView.heightAnchor.constraint(equalTo: heightAnchor),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        // setup scroll view
        minimumZoomScale = 1
        maximumZoomScale = 3
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false

        // the viewer is full screen, safe-area insets would push the image off centre.
        contentInsetAdjustmentBehavior = .never
        // without this, zooming doesn't work
        delegate = self

        // setup tap gestures: double tap zooms, single tap shows or hides the close button
        let doubleTapRecognizer = UITapGestureRecognizer(target:
                                                            self,
                                                         action:
                                                            #selector(handleDoubleTap(_:)
                                                                     )
        )
        doubleTapRecognizer.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTapRecognizer)

        let singleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        // wait to make sure it isn't a double tap
        singleTapRecognizer.require(toFail: doubleTapRecognizer)
        addGestureRecognizer(singleTapRecognizer)
    }

    // MARK: - Zooming and taps

    // tells the scroll view which view to zoom
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    // toggle between 1x and 2x
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
