import Foundation
import Network

protocol NetworkServerDelegate: AnyObject {
    func serverBecameReady()
    func connectionOpened(id: Int)
    func connectionReceivedData(id: Int, data: Data)
}

@available(iOS 13.0, *)
class NetworkServer: NetworkConnectionDelegate {
    weak var delegate: NetworkServerDelegate?
    let listener: NWListener

    private var serverQueue: DispatchQueue?

    private var connectionsByID: [Int: NetworkConnection] = [:]

    init() {
        let parameters = NWParameters(tls: nil)
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = true
//        parameters.acceptLocalOnly = true

        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true

        parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        self.listener = try! NWListener(using: parameters, on: 12345)
    }

    func start(queue: DispatchQueue) throws {
        serverQueue = queue

        listener.stateUpdateHandler = listenerStateDidChange(to:)
        listener.newConnectionHandler = listenerNewConnectionAccepted(connection:)
        listener.start(queue: queue)
    }

    func sendData(to id: Int, data: Data) {
        self.connectionsByID[id]?.send(data: data)
    }

    func listenerStateDidChange(to newState: NWListener.State) {
        print(#function, newState)
        switch newState {
        case .setup:
            break
        case .waiting:
            break
        case .ready:
            delegate?.serverBecameReady()
        case .failed(let error):
            print("server did fail, error: \(error)")
            stop()
        case .cancelled:
            break
        default:
            break
        }
    }

    private func listenerNewConnectionAccepted(connection: NWConnection) {
        let connection = NetworkConnection(
            connection: connection,
            delegate: self
        )
        connectionsByID[connection.id] = connection
        connection.start(queue: serverQueue!)

        print("Server accepted connection \(connection.id)")
    }

    private func stop() {
        listener.stateUpdateHandler = nil
        listener.newConnectionHandler = nil
        listener.cancel()
        closeAllConnections()
    }

    private func closeAllConnections() {
        for connection in connectionsByID.values {
            connection.close()
        }
        connectionsByID.removeAll()
    }

    // MARK: NetworkConnectionDelegate
    func connectionOpened(connection: NetworkConnection) {
        print(Self.self, #function)
        delegate?.connectionOpened(id: connection.id)
    }

    func connectionClosed(connection: NetworkConnection) {
        print(Self.self, #function, connection)
        connectionsByID.removeValue(forKey: connection.id)
    }

    func connectionError(connection: NetworkConnection, error: Error) {
        print(Self.self, #function, connection, error)
    }

    func connectionReceivedData(connection: NetworkConnection, data: Data) {
        delegate?.connectionReceivedData(id: connection.id, data: data)
    }
}

@available(iOS 13.0, *)
protocol NetworkConnectionDelegate: AnyObject {
    func connectionOpened(connection: NetworkConnection)
    func connectionClosed(connection: NetworkConnection)
    func connectionError(connection: NetworkConnection, error: Error)
    func connectionReceivedData(connection: NetworkConnection, data: Data)
}

@available(iOS 13.0, *)
class NetworkConnection {

    let id: Int

    private let nwConnection: NWConnection
    private weak var delegate: NetworkConnectionDelegate?
    private var queue: DispatchQueue?

    init(connection: NWConnection, delegate: NetworkConnectionDelegate?) {
        self.nwConnection = connection
        self.delegate = delegate
        self.id = UUID().hashValue
    }

    func start(queue: DispatchQueue) {
        self.queue = queue
        nwConnection.stateUpdateHandler = connectionStateDidChange(to:)
        receiveMessage()
        nwConnection.start(queue: queue)
    }

    func close() {
        nwConnection.stateUpdateHandler = nil
        nwConnection.cancel()
        delegate?.connectionClosed(connection: self)
    }

    func send(data: Data) {
        print("Send \(data.count) bytes")

        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(
            identifier: "context",
            metadata: [metadata]
        )

        nwConnection.send(
            content: data,
            contentContext: context,
            completion: .contentProcessed { error in
                if let error {
                    self.delegate?.connectionError(connection: self, error: error)
                }
            }
        )
    }

    private func connectionStateDidChange(to state: NWConnection.State) {
        switch state {
            case .setup:
                break
            case .waiting(let error):
                delegate?.connectionError(connection: self, error: error)
            case .preparing:
                break
            case .ready:
                delegate?.connectionOpened(connection: self)
            case .failed(let error):
                delegate?.connectionError(connection: self, error: error)
            case .cancelled:
                break
            default:
                break
        }
    }

    private func receiveMessage() {
        nwConnection.receiveMessage { completeContent, contentContext, isComplete, error in
            if let completeContent {
                self.delegate?.connectionReceivedData(connection: self, data: completeContent)
            }
            if let error {
                self.delegate?.connectionError(connection: self, error: error)
            } else {
                self.receiveMessage()
            }
        }
    }
}
