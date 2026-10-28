import Foundation

/// The Journalism filters, one per tag the Journalism director gives articles
/// on the Radio Monash website. Untagged articles only appear under All.
enum ArticleTopic: CaseIterable, Identifiable {
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
        // yo selin there is a typo here
        case .popCulture: "Pop Culutre"
        case .gigReviews: "Gig review"
        case .moviesAndTV: "Movies"
        case .newMusic: "New Music"
        case .radioMonash: "Radio Monash"
        }
    }
}
