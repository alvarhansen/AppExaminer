import Foundation
import class UIKit.UIDevice

public protocol WebSocketConnection: AnyObject {
    func send(data: Data) throws
}

public protocol FlipperConnectionManager {
    func start(delegate: FlipperConnectionManagerDelegate)
}

public protocol FlipperConnectionManagerDelegate: AnyObject {
    func didReceiveMessage(data: Data, sender: WebSocketConnection)
}
