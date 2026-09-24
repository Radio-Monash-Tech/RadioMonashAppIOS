import Foundation

extension URL {
    func squarespaceSized(_ width: Int) -> URL {
        guard host?.contains("squarespace-cdn.com") == true,
              var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        else { return self }
        components.queryItems = (components.queryItems ?? []).filter { $0.name != "format" }
            + [URLQueryItem(name: "format", value: "\(width)w")]
        return components.url ?? self
    }
}
