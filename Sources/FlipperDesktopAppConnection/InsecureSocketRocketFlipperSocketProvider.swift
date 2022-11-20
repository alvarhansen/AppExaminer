import Foundation
import FlipperClientSwift
import SocketRocket

class InsecureSocketRocketFlipperSocketProvider: NSObject {

    private let parameters: FlipperSocketProviderConnectionParameters
    private weak var delegate: FlipperSocketProviderDelegate?
    private var socket: SRWebSocket?

    init(
        parameters: FlipperSocketProviderConnectionParameters,
        delegate: FlipperSocketProviderDelegate?
    ) {
        self.parameters = parameters
        self.delegate = delegate
    }
}

extension InsecureSocketRocketFlipperSocketProvider: SRWebSocketDelegate {

    func webSocket(_ webSocket: SRWebSocket, didReceiveMessageWith string: String) {
        guard let data = string.data(using: .utf8) else {
            fatalError("Unable to encode string to data.")
        }
        delegate?.newMessageReceived(data: data, sender: self)
    }

    func webSocketDidOpen(_ webSocket: SRWebSocket) {
        delegate?.socketDidOpen(sender: self)
    }

    func webSocket(_ webSocket: SRWebSocket, didFailWithError error: Error) {
        delegate?.socketDidFail(sender: self)
    }
}

extension InsecureSocketRocketFlipperSocketProvider: FlipperSocketProvider {

    func start() {
        var comps = URLComponents()
        comps.scheme = "ws"
        comps.port = 9089
        comps.host = parameters.hostAddress
        comps.queryItems = [
            .init(name: "os", value: parameters.systemName),
            .init(name: "device", value: parameters.deviceName),
            .init(name: "device_id", value: parameters.deviceIdentifier),
            .init(name: "app", value: parameters.bundleName),
            .init(name: "sdk_version", value: parameters.sdkVersion),
            .init(name: "medium", value: parameters.medium)
        ]

        let request = URLRequest(url: comps.url!.absoluteURL)

        socket = SRWebSocket(
            urlRequest: request,
            securityPolicy: .default()
        )
        socket?.delegate = self
        socket?.open()
    }

    func stop() {
        socket?.close()
    }

    func send(data: Data) throws {
        try socket?.send(data: data)
    }
}
