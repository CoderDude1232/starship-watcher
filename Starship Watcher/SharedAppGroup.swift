import Foundation

enum SharedAppGroup {
    static let identifier = "group.com.morgandaly.Starship-Watcher"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static func cacheURL(fileName: String) -> URL {
        if let containerURL {
            return containerURL.appending(path: fileName)
        }
        return URL.documentsDirectory.appending(path: fileName)
    }
}
