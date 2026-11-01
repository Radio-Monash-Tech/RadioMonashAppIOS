import SwiftUI
import UIKit

// bridge to connects panzoomableimageview to imageviewer
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    var onSingleTap: () -> Void = {}

    // called once when the view first appears
    func makeUIView(context: Context) -> PanZoomImageView {
        let view = PanZoomImageView()
        view.image = image
        view.onSingleTap = onSingleTap
        return view
    }

    // called on every swiftui redraw
    func updateUIView(_ view: PanZoomImageView, context: Context) {
        // only swap the image if it's a different one, otherwise the zoom resets
        if view.image !== image {
            view.image = image
        }
        view.onSingleTap = onSingleTap
    }
}
