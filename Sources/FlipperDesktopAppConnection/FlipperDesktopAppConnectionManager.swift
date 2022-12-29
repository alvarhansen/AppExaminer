import Foundation
import AppExaminer
import class UIKit.UIDevice

typealias InsecureFlipperSocketProviderBuilder = (
    FlipperSocketProviderConnectionParameters,
    FlipperSocketProviderDelegate
) -> FlipperSocketProvider

typealias SecureFlipperSocketProviderBuilder = (
    FlipperSocketProviderConnectionParameters,
    FlipperSocketProviderDelegate,
    SecIdentity
) -> FlipperSocketProvider

protocol FlipperSocketProvider: WebSocketConnection {
    func start()
    func stop()
}

protocol FlipperSocketProviderDelegate: AnyObject {
    func socketDidOpen(sender: FlipperSocketProvider)
    func newMessageReceived(data: Data, sender: FlipperSocketProvider)
    func socketDidFail(sender: FlipperSocketProvider)
}

public class FlipperDesktopAppConnectionManager: AppExaminerConnectionManager {

    private weak var delegate: AppExaminerConnectionManagerDelegate?

    private let fileManager: FileManager
    private let insecureFlipperSocketProviderBuilder: InsecureFlipperSocketProviderBuilder
    private let secureFlipperSocketProviderBuilder: SecureFlipperSocketProviderBuilder

    private var insecureConnection: FlipperSocketProvider?

    private var secureConnection: FlipperSocketProvider?
    private var deviceIdentifier: String?
    private var secureConnectionRetryCount = 0

    private let decoder: JSONDecoder = JSONDecoder()

    private var hostAddress: String {
        ProcessInfo.processInfo.environment["FLIPPER_HOST_ADDRESS"] ?? "127.0.0.1"
    }

    public convenience init() {
        self.init(
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
        )
    }

    init(
        fileManager: FileManager = .default,
        insecureFlipperSocketProviderBuilder: @escaping InsecureFlipperSocketProviderBuilder,
        secureFlipperSocketProviderBuilder: @escaping SecureFlipperSocketProviderBuilder
    ) {
        self.fileManager = fileManager
        self.insecureFlipperSocketProviderBuilder = insecureFlipperSocketProviderBuilder
        self.secureFlipperSocketProviderBuilder = secureFlipperSocketProviderBuilder
    }

    public func start(
        delegate: AppExaminerConnectionManagerDelegate
    ) {
        FlipperCertificateManager.deleteKeys()

        self.delegate = delegate

        let insecureConnection = insecureFlipperSocketProviderBuilder(
            .main(
                hostAddress: hostAddress,
                deviceIdentifier: ""
            ),
            self
        )
        self.insecureConnection = insecureConnection
        insecureConnection.start()
    }

    func stop() {
        insecureConnection?.stop()
        secureConnection?.stop()
    }

    private func startSecureConnection(deviceIdentifier: String) {
        secureConnection?.stop()
        secureConnection = nil

        let secureConnection = secureFlipperSocketProviderBuilder(
            .main(
                hostAddress: hostAddress,
                deviceIdentifier: deviceIdentifier
            ),
            self,
            try! FlipperCertificateManager.deviceCertificateRef()
        )
        self.deviceIdentifier = deviceIdentifier
        self.secureConnection = secureConnection
        secureConnection.start()
    }

    private func sendCertificateRequest(connection: FlipperSocketProvider) throws {
        try fileManager.createDirectory(
            at: fileManager.appSupportDir,
            withIntermediateDirectories: true
        )

        struct SignCertificateRequest: Encodable {
            let method: String = "signCertificate"
            let csr: String
            let destination: String
            let medium: Int
        }

        let request = SignCertificateRequest(
            csr: try! FlipperCertificateManager.generateSigningRequest(
                bundleId: Bundle.main.bundleIdentifier!
            ),
            destination: "\(fileManager.appSupportDir.path)/",
            medium: 1
        )
        let encoder = JSONEncoder()
        let data = try! encoder.encode(request)
        log(#function, String(data: data, encoding: .utf8)!)
        try connection.send(data: data)
    }

    private func handleCertificateSigningResponse(data: Data) {
        log(#function, data)

        struct SignCertificateResponse: Decodable {
            let deviceId: String
        }

        insecureConnection?.stop()
        insecureConnection = nil
        do {
            let response = try self.decoder.decode(
                SignCertificateResponse.self,
                from: data
            )
            try FlipperCertificateManager.importDeviceCertificate()
            startSecureConnection(deviceIdentifier: response.deviceId)
        } catch {
            log("cert signing failed!")
        }
    }
}

extension FlipperDesktopAppConnectionManager: FlipperSocketProviderDelegate {
    func socketDidOpen(sender: FlipperSocketProvider) {
        if sender === insecureConnection {
            try? sendCertificateRequest(connection: sender)
        }
    }

    func newMessageReceived(data: Data, sender: FlipperSocketProvider) {
        if sender ===  insecureConnection {
            handleCertificateSigningResponse(data: data)
        } else if sender === secureConnection {
            delegate?.didReceiveMessage(data: data, sender: sender)
        }
    }

    func socketDidFail(sender: FlipperSocketProvider) {
        if sender === insecureConnection {
            //todo. Retry?
        } else if sender === secureConnection {
            if secureConnectionRetryCount < 3, let deviceId = deviceIdentifier {
                secureConnectionRetryCount += 1

                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.startSecureConnection(deviceIdentifier: deviceId)
                }
            }
        }
    }
}

private extension FlipperSocketProviderConnectionParameters {

    static func main(
        hostAddress: String,
        deviceIdentifier: String
    ) -> FlipperSocketProviderConnectionParameters {
        FlipperSocketProviderConnectionParameters(
            hostAddress: hostAddress,
            systemName: UIDevice.current.systemName,
            deviceName: UIDevice.current.name,
            deviceIdentifier: deviceIdentifier,
            bundleName: Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "No name"
        )
    }
}
