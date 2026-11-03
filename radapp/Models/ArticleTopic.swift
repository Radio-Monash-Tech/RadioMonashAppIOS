import Foundation

// the journalism filters, one per tag on the website
enum ArticleTopic: CaseIterable, Identifiable, Codable {
    case analysis, popCulture, gigReviews, moviesAndTV, newMusic, radioMonash

    var id: Self {
        self
    }

    var label: String {
        switch self {
        case .analysis:
            "Analysis"
        case .popCulture:
            "Pop Culture"
        case .gigReviews:
            "Gig Reviews"
        case .moviesAndTV:
            "Movies & TV Shows"
        case .newMusic:
            "New Music"
        case .radioMonash:
            "What's Happening at Radio Monash"
        }
    }

    // the tag exactly as it's spelled on the website
    var siteTag: String {
        switch self {
        case .analysis:
            "Analysis"
        // need to tell selin to fix this in the squarespace
        case .popCulture:
            "Pop Culutre"
        case .gigReviews:
            "Gig review"
        case .moviesAndTV:
            "Movies"
        case .newMusic:
            "New Music"
        case .radioMonash:
            "Radio Monash"
        }
    }

    // the first filter whose tag the article has, nil if none
    // init sets up a new instance
    init?(tags: [String]) {
        let tags = Set(tags.map { tag in
            tag.lowercased()
        })
        let match = Self.allCases.first { topic in
            tags.contains(topic.siteTag.lowercased())
        }
        // guard exits early if the check fails
        guard let match else {
            return nil
        }
        self = match
    }
}
