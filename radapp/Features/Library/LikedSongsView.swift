import SwiftUI

struct LikedSongsView: View {
    var body: some View {
        ContentUnavailableView(
            "No Liked Songs",
            systemImage: "heart",
            description: Text("Tap the heart on the Live player and the track will be saved here.")
        )
        .navigationTitle("Liked Songs")
    }
}
