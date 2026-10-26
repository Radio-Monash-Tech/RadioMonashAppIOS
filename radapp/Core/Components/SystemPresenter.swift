import SafariServices
import UIKit

// Presents UIKit's own modal screens (in-app Safari, alerts) from the top-most
// view controller. Wrapping them in a SwiftUI `.sheet` breaks after the first
// use: they dismiss themselves when done, which SwiftUI doesn't notice, so it
// ignores every later request to present.
enum SystemPresenter {
    // Song pages and the like, kept in the app. Links to other services'
    // universal links (open.spotify.com, ...) still open their apps.
    static func openInApp(_ url: URL) {
        present(SFSafariViewController(url: url))
    }

    static func alert(title: String, message: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert)
    }

    private static func present(_ controller: UIViewController) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard var top = scene?.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        top.present(controller, animated: true)
    }
}
