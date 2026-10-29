import Foundation

/// The Journalism filters, one per tag the Journalism director gives articles
/// on the Radio Monash website. Untagged articles only appear under All.
enum ArticleTopic: CaseIterable, Identifiable, Codable {
    case analysis, popCulture, gigReviews, moviesAndTV, newMusic, radioMonash

    var id: Self { self }

    var label: String {
        switch self {
        case .analysis: "Analysis"
        case .popCulture: "Pop Culture"
        case .gigReviews: "Gig Reviews"
        case .moviesAndTV: "Movies & TV Shows"
        case .newMusic: "New Music"
        case .radioMonash: "What's Happening at Radio Monash"
        }
    }

    // The tag exactly as it's spelled on the website, which Squarespace
    var siteTag: String {
        switch self {
        case .analysis: "Analysis"
        // need to tell selin to fix this in the squarespace
        case .popCulture: "Pop Culutre"
        case .gigReviews: "Gig review"
        case .moviesAndTV: "Movies"
        case .newMusic: "New Music"
        case .radioMonash: "Radio Monash"
        }
    }

    /// The first filter whose tag the article carries.
    init?(tags: [String]) {
        let tags = Set(tags.map { $0.lowercased() })
        guard let match = Self.allCases.first(where: { tags.contains($0.siteTag.lowercased()) }) else { return nil }
        self = match
    }
}
