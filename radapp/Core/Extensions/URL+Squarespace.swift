import Foundation

extension URL {
    // asks squarespace for the image,
    func squarespaceSized(_ width: Int) -> URL {
        // only change squarespace image links
        guard host?.contains("squarespace-cdn.com") == true,
              var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        else {
            return self
        }

        // keep the other query items but drop any old format
        let otherItems = (components.queryItems ?? []).filter { item in
            item.name != "format"
        }
        components.queryItems = otherItems + [URLQueryItem(name: "format", value: "\(width)w")]

        // put the url back together, or keep the original if that fails
        return components.url ?? self
    }
}
