import SwiftUI
import UIKit

// the app's own increase contrast switch
enum ContrastPreference {
    static let storageKey = "increaseContrast"
}

extension View {
    // turns on high contrast for the whole window
    func increasedContrast(_ isOn: Bool) -> some View {
        background(WindowContrastOverride(isOn: isOn))
    }
}

// an invisible uikit view that reaches the window to change its contrast
private struct WindowContrastOverride: UIViewRepresentable {
    let isOn: Bool

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        view.isOn = isOn
    }

    final class ProbeView: UIView {
        var isOn = false {
            didSet {
                apply()
            }
        }

        // the window is only known once the view is on screen
        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        private func apply() {
            guard let window else {
                return
            }
            if isOn {
                window.traitOverrides.accessibilityContrast = .high
            } else {
                // back to whatever ios settings say
                window.traitOverrides.remove(UITraitAccessibilityContrast.self)
            }
        }
    }
}
