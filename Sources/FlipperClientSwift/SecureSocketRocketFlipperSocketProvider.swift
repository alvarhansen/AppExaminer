import Foundation
import SocketRocket

class SecureSocketRocketFlipperSocketProvider: NSObject {

    private let parameters: FlipperSocketProviderConnectionParameters
    private let deviceCertificate: SecIdentity
    private weak var delegate: FlipperSocketProviderDelegate?
    private var socket: SRWebSocket?

    init(
        parameters: FlipperSocketProviderConnectionParameters,
        deviceCertificate: SecIdentity,
        delegate: FlipperSocketProviderDelegate?
    ) {
        self.parameters = parameters
        self.deviceCertificate = deviceCertificate
        self.delegate = delegate
    }
}

extension SecureSocketRocketFlipperSocketProvider: SRWebSocketDelegate {

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

extension SecureSocketRocketFlipperSocketProvider: FlipperSocketProvider {

    func start() {
        var comps = URLComponents()
        comps.scheme = "wss"
        comps.port = 9088
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

        let securityPolicy = SecIdentitySecurityPolicy()
        securityPolicy.deviceCertificate = deviceCertificate

        socket = SRWebSocket(
            urlRequest: request,
            securityPolicy: securityPolicy
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

private class SecIdentitySecurityPolicy: SRSecurityPolicy {

    var deviceCertificate: SecIdentity!

    override func updateSecurityOptions(in stream: Stream) {
        log(Self.self, #function, stream)
        if let outputStream = stream as? OutputStream {
            outputStream.setProperty(
                [
                    kCFStreamSSLValidatesCertificateChain: false,
                    kCFStreamSSLLevel: kCFStreamSocketSecurityLevelNegotiatedSSL,
                    kCFStreamPropertySocketSecurityLevel: kCFStreamSocketSecurityLevelNegotiatedSSL,
                    kCFStreamSSLIsServer: false,
                    kCFStreamSSLCertificates: [
                        deviceCertificate as Any
                    ]
                ],
                forKey: kCFStreamPropertySSLSettings as Stream.PropertyKey
            )
        }
    }
}
