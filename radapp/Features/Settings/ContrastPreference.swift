import SwiftUI
import UIKit

enum ContrastPreference {
    static let storageKey = "increaseContrast"
}

extension View {
    func increasedContrast(_ isOn: Bool) -> some View {
        background(WindowContrastOverride(isOn: isOn))
    }
}

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
            didSet { apply() }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        private func apply() {
            guard let window else { return }
            if isOn {
                window.traitOverrides.accessibilityContrast = .high
            } else {
                window.traitOverrides.remove(UITraitAccessibilityContrast.self)
            }
        }
    }
}
