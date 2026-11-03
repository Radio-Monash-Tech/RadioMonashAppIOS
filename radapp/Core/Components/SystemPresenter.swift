import SafariServices
import UIKit

// shows uikit screens (safari, share sheet, alerts) from anywhere
enum SystemPresenter {
    // Song pages and the like, kept in the app. Links to other services'
    static func openInApp(_ url: URL) {
        present(SFSafariViewController(url: url))
    }

    // the menu closes and takes the link with it before the sheet can open.
    static func share(_ items: Any...) {
        let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
        present(sheet)
    }

    // a simple popup with one OK button
    static func alert(title: String, message: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert)
    }

    // presents from whatever is on top of the screen right now
    private static func present(_ controller: UIViewController) {
        // window scenes only
        let scenes = UIApplication.shared.connectedScenes.compactMap { scene in
            scene as? UIWindowScene
        }
        // the scene the user is looking at, otherwise any scene
        let scene = scenes.first { scene in
            scene.activationState == .foregroundActive
        } ?? scenes.first
        guard var top = scene?.keyWindow?.rootViewController else {
            return
        }
        // climb up to the topmost controller that isn't closing
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        top.present(controller, animated: true)
    }
}
