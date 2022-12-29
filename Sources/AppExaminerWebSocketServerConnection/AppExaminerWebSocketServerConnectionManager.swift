import Foundation
import AppExaminer
import Network

@available(iOS 13.0, *)
public class AppExaminerWebSocketServerConnectionManager: AppExaminerConnectionManager {
    private let server = NetworkServer()
    private let queue = DispatchQueue(label: "NetworkServer")
    private weak var delegate: AppExaminerConnectionManagerDelegate?

    public init() {}

    public func start(delegate: AppExaminerConnectionManagerDelegate) {
        self.delegate = delegate

        server.delegate = self
        try! server.start(queue: queue)
    }
}

@available(iOS 13.0, *)
extension AppExaminerWebSocketServerConnectionManager: NetworkServerDelegate {

    func serverBecameReady() { print(#function) }

    func connectionOpened(id: Int) {
        print(#function)
    }

    func connectionReceivedData(id: Int, data: Data) {
        print(#function, id, data.count, String(data: data, encoding: .ascii))
        delegate?.didReceiveMessage(
            data: data,
            sender: WebSocketConnectionToNetworkServerForwarder(
                server: server,
                queue: queue,
                connectionID: id
            )
        )
    }
}

@available(iOS 13.0, *)
private class WebSocketConnectionToNetworkServerForwarder: WebSocketConnection {

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
