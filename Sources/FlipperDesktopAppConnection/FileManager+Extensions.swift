import Foundation

extension FileManager {
    var appSupportDir: URL {
        urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }
}
