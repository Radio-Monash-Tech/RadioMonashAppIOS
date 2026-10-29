import SwiftUI
import UIKit

/// Brings `PanZoomImageView` into SwiftUI.
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    var onSingleTap: () -> Void = {}

    func makeUIView(context: Context) -> PanZoomImageView {
        let view = PanZoomImageView()
        view.image = image
        view.onSingleTap = onSingleTap
        return view
    }

    func updateUIView(_ view: PanZoomImageView, context: Context) {
        if view.image !== image { view.image = image }
        view.onSingleTap = onSingleTap
    }
}
