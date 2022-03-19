
public protocol FlipperPlugin {

    func identifier() -> String

    func didConnect(connection: FlipperConnection)

    func didDisconnect()

    func runInBackground() -> Bool
}

public extension FlipperPlugin {
    func runInBackground() -> Bool {
        return false
    }
}
