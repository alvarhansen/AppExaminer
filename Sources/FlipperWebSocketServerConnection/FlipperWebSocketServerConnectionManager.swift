import Foundation
import FlipperClientSwift
import Network

@available(iOS 13.0, *)
public class FlipperWebSocketServerConnectionManager: FlipperConnectionManager {
    private let server = NetworkServer()
    private let queue = DispatchQueue(label: "NetworkServer")
    private weak var delegate: FlipperConnectionManagerDelegate?

    public init() {}

    public func start(delegate: FlipperConnectionManagerDelegate) {
        self.delegate = delegate

        server.delegate = self
        try! server.start(queue: queue)
    }
}

@available(iOS 13.0, *)
extension FlipperWebSocketServerConnectionManager: NetworkServerDelegate {

    func serverBecameReady() { print(#function) }

    func connectionOpened(id: Int) {
        print(#function)
    }

    func connectionReceivedData(id: Int, data: Data) {
        print(#function, id, data.count, String(data: data, encoding: .ascii))
        delegate?.didReceiveMessage(
            data: data,
            sender: FlipperConnectionToNetworkServerForwarder(
                server: server,
                queue: queue,
                connectionID: id
            )
        )
    }
}

@available(iOS 13.0, *)
private class FlipperConnectionToNetworkServerForwarder: WebSocketConnection {

    private let server: NetworkServer
    private let queue: DispatchQueue
    private let connectionID: Int

    init(server: NetworkServer, queue: DispatchQueue, connectionID: Int) {
        self.server = server
        self.queue = queue
        self.connectionID = connectionID
    }
    func send(data: Data) throws {
        queue.async {
            self.server.sendData(to: self.connectionID, data: data)
        }
    }
}
