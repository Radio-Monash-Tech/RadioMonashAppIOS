import SwiftUI

struct AccessibilitySettingsView: View {
    @AppStorage(ContrastPreference.storageKey) private var increaseContrast = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $increaseContrast) {
                    Text("Increase Contrast")
                    Text("Darker text, stronger colours and solid backgrounds")
                }
            } header: {
                Text("Display")
            } footer: {
                if !increaseContrast && contrast == .increased {
                    Text("Already on because Increase Contrast is turned on in iOS Settings.")
                }
            }
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { AccessibilitySettingsView() }
}
