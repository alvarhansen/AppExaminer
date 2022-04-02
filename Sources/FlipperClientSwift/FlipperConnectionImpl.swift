import Foundation

class FlipperConnectionImpl: FlipperConnection {

    private let pluginIdentifier: String
    private let socketConnection: WebSocketConnection

    private struct Receiver {
        let responseType: Decodable.Type
        let callback: (Decodable, FlipperResponder) -> Void
    }

    private var receivers: [String: Receiver] = [:]
    private let encoder: JSONEncoder = JSONEncoder()

    init(
        pluginIdentifier: String,
        socketConnection: WebSocketConnection
    ) {
        self.pluginIdentifier = pluginIdentifier
        self.socketConnection = socketConnection
    }


    func send<T: Encodable>(_ method: String, withParams params: T) throws {
        try socketConnection.send(data: try encoder.encode(
            ExecuteRequest(
                params: ExecuteRequest.Params(
                    api: pluginIdentifier,
                    method: method,
                    params: params
                )
            )
        ))
    }

    func isMethodSupported(_ method: String) -> Bool {
        receivers.keys.contains(method)
    }

    func call(method: String, identifier: Int, params: (Decodable.Type) -> Decodable) {
        guard let receiver = receivers[method] else {
            // todo: report error
            return
        }
        let type = receiver.responseType
        let parameters = params(type.self)

        receivers[method]?.callback(
            parameters,
            ResponseConnection(identifier: identifier, socketConnection: socketConnection)
        )
    }

    func receive<T: Decodable>(method: String, callback: @escaping (T, FlipperResponder) -> Void) {
        receivers[method] = Receiver(
            responseType: T.self,
            callback: { response, responder in callback(response as! T, responder) }
        )
    }
}

struct ExecuteRequest<T: Encodable>: Encodable {

    struct Params<T: Encodable>: Encodable {
        let api: String
        let method: String
        let params: T
    }

    let method: String = "execute"
    let params: Params<T>
}

struct ResponseConnection: FlipperResponder {

    private struct SuccessMessage<T: Encodable>: Encodable {
        let success: T
        let id: Int
    }

    let identifier: Int
    let socketConnection: WebSocketConnection

    func success<T: Encodable>(response: T) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(SuccessMessage(success: response, id: identifier))
        try socketConnection.send(data: data)
    }

    func error<T: Encodable>(response: T) throws {
        fatalError()
    }

}
