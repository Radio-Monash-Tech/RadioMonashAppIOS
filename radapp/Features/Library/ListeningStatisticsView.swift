import SwiftUI

struct ListeningStatisticsView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Listening Yet", systemImage: "chart.bar")
        } description: {
            Text("Your listening time and top shows will appear here once you've tuned in.")
        } actions: {
            Text("Statistics are calculated and stored only on this device.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Listening Statistics")
    }
}
