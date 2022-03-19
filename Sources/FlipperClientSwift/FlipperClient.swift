import Foundation

public class FlipperClient {

    public static let shared: FlipperClient = FlipperClient(flipperConnectionManager: FlipperConnectionManager(
        insecureFlipperSocketProviderBuilder: { params, delegate in
            InsecureSocketRocketFlipperSocketProvider(
                parameters: params,
                delegate: delegate
            )
        },
        secureFlipperSocketProviderBuilder: { params, delegate, deviceCertificate in
            SecureSocketRocketFlipperSocketProvider(
                parameters: params,
                deviceCertificate: deviceCertificate,
                delegate: delegate
            )
        }
    ))

    private let flipperConnectionManager: FlipperConnectionManager
    private var plugins: [FlipperPlugin] = []
    private var pluginConnection: [String: FlipperConnection] = [:]

    private let decoder: JSONDecoder = JSONDecoder()
    private let encoder: JSONEncoder = JSONEncoder()

    init(
        flipperConnectionManager: FlipperConnectionManager
    ) {
        self.flipperConnectionManager = flipperConnectionManager
    }

    public func addPlugin(_ plugin: FlipperPlugin) {
        plugins.append(plugin)
    }

    public func start() {
        FlipperCertificateManager.deleteKeys()

        self._start()
    }

    func _start() {
        flipperConnectionManager.start(delegate: self)
    }

    private func handleMessage(data: Data, connection: WebSocketConnection) {
        let parsedMessage = try! decoder.decode(
            MessageResponse.self,
            from: data
        )
        log(#function, data, parsedMessage)

        switch parsedMessage.method {
        case .getPlugins(let identifier):
            broadcastPluginList(responseIdentifier: identifier, connection: connection)
        case .getBackgroundPlugins(let identifier):
            broadcastBackgroundPluginList(responseIdentifier: identifier, connection: connection)
        case .`init`(let params):
            initialisePlugin(identifier: params.plugin, connection: connection)
        case .deinit(let params):
            deinitialisePlugin(identifier: params.plugin)
        case .execute(let identifier, let params):
            executePlugin(identifier: identifier, params: params, data: data)
        }
    }

    private func broadcastPluginList(
        responseIdentifier: Int,
        connection: WebSocketConnection
    ) {
        try! connection.send(data: try! encoder.encode(
            SuccessMessage(
                success: ["plugins": plugins.map { $0.identifier() }],
                id: responseIdentifier
            )
        ))
    }
    private func broadcastBackgroundPluginList(
        responseIdentifier: Int,
        connection: WebSocketConnection
    ) {
        try! connection.send(data: try! encoder.encode(
            SuccessMessage(
                success: [
                    "plugins": plugins
                        .filter { $0.runInBackground() }
                        .map { $0.identifier() }
                ],
                id: responseIdentifier
            )
        ))
    }

    private func initialisePlugin(
        identifier: String,
        connection: WebSocketConnection
    ) {
        plugins
            .filter { $0.identifier() == identifier }
            .forEach { plugin in
                let connection = FlipperConnectionImpl(
                    pluginIdentifier: identifier,
                    socketConnection: connection
                )
                pluginConnection[identifier] = connection
                plugin.didConnect(connection: connection)
            }
    }

    private func deinitialisePlugin(identifier: String) {
        plugins
            .filter { $0.identifier() == identifier }
            .forEach { plugin in
                pluginConnection[identifier] = nil
                plugin.didDisconnect()
            }
    }

    private func executePlugin(
        identifier: Int,
        params: MessageResponse.Method.ExecuteParams,
        data: Data
    ) {
        pluginConnection[params.api]?.call(
            method: params.method,
            identifier: identifier,
            params: { typeInfo -> Decodable in
                let decoder = JSONDecoder()
                decoder.userInfo[.pluginParametersType] = typeInfo

                let execResponseWithParams = try! decoder.decode(
                    ExecMessageResponse.self,
                    from: data
                )

                return execResponseWithParams.params.params.value
            }
        )
    }
}

extension FlipperClient: FlipperConnectionManagerDelegate {
    func didReceiveMessage(data: Data, sender: WebSocketConnection) {
        handleMessage(data: data, connection: sender)
    }
}

private struct ExecMessageResponse: Decodable {

    struct ExecuteParams: Decodable {

        struct PluginParams: Decodable {

            let value: Decodable

            init(from decoder: Decoder) throws {
                enum Error: Swift.Error {
                    case missingDynamicType
                }
                guard let dynamicType = decoder.userInfo[.pluginParametersType] as? Decodable.Type else {
                    throw Error.missingDynamicType
                }
                value = try dynamicType.init(from: decoder)
            }
        }

        let params: PluginParams
    }

    let params: ExecuteParams
}

private struct MessageResponse: Decodable {

    enum Method {

        struct InitParams: Decodable {
            let plugin: String
        }

        struct DeinitParams: Decodable {
            let plugin: String
        }

        struct ExecuteParams: Decodable {
            let api: String
            let method: String
        }

        case `init`(InitParams)
        case `deinit`(DeinitParams)
        case getPlugins(Int)
        case getBackgroundPlugins(Int)
        case execute(Int, ExecuteParams)
    }

    let method: Method

    init(from decoder: Decoder) throws {
        struct _MessageResponse: Decodable {
            enum Method: String, Decodable {
                case `init`
                case `deinit`
                case getPlugins
                case getBackgroundPlugins
                case execute
            }
            let id: Int?
            let method: Method
        }
        let response = try _MessageResponse(from: decoder)

        enum ParamsCodingKey: String, CodingKey {
            case params, id
        }
        let container = try decoder.container(keyedBy: ParamsCodingKey.self)

        switch response.method {
        case .`init`:
            self.method = .`init`(
                try container.decode(Method.InitParams.self, forKey: ParamsCodingKey.params)
            )
        case .`deinit`:
            self.method = .`deinit`(
                try container.decode(Method.DeinitParams.self, forKey: ParamsCodingKey.params)
            )
        case .getPlugins:
            self.method = .getPlugins(
                try container.decode(Int.self, forKey: ParamsCodingKey.id)
            )
        case .getBackgroundPlugins:
            self.method = .getBackgroundPlugins(
                try container.decode(Int.self, forKey: ParamsCodingKey.id)
            )
        case .execute:
            self.method = .execute(
                try container.decode(Int.self, forKey: ParamsCodingKey.id),
                try container.decode(Method.ExecuteParams.self, forKey: ParamsCodingKey.params)
            )
        }
    }
}

private struct SuccessMessage<T: Encodable>: Encodable {
    let success: T
    let id: Int
}

private struct SignCertificateRequest: Encodable {
    let method: String = "signCertificate"
    let csr: String
    let destination: String
    let medium: Int
}

private extension CodingUserInfoKey {
    static var pluginParametersType = CodingUserInfoKey(rawValue: "decoderDynamicType")!
}

