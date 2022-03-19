import CertificateSigningRequest
import Foundation
import Security

private let kPrivateKeyTag = "com.flipper.socket.private"
private let kPrivateKeyLabel = "com.flipper.socket Private Key"
private let kPublicKeyTag = "com.flipper.socket.public"
private let kPublicKeyLabel = "com.flipper.socket Public Key"

private let kCertificateLabel = "Flipper device certificate"

class FlipperCertificateManager {

    private static var csrURL: URL {
        FileManager.default.appSupportDir.appendingPathComponent("app.csr")
    }

    private static var deviceCrtURL: URL {
        FileManager.default.appSupportDir.appendingPathComponent("device.crt")
    }

    static func generateSigningRequest(bundleId: String) throws -> String {
        enum Error: Swift.Error {
            case failedToBuildCSRString
        }
        let algorithm = KeyAlgorithm.rsa(signatureType: .sha256)
        let keyType = algorithm.secKeyAttrType as String

        let csr = CertificateSigningRequest(
            commonName: bundleId,
            organizationName: "Flipper",
            organizationUnitName: nil,
            countryName: "US",
            stateOrProvinceName: "CA",
            localityName: "Menlo Park",
            keyAlgorithm: algorithm
        )

        let (privateKey, _) = try SecKey.generateKeyPair(
            keyType: keyType,
            size: 2048
        )

        let publicKeyData = try getPublicKeyData(keyType: keyType, tag: kPublicKeyTag)

        guard let csrString = csr.buildCSRAndReturnString(publicKeyData, privateKey: privateKey) else {
            throw Error.failedToBuildCSRString
        }

        try csrString.write(to: csrURL, atomically: true, encoding: .utf8)
        log("CSR written to \(csrURL.path)")

        return csrString
    }

    static func importDeviceCertificate() throws {
        enum Error: Swift.Error {
            case loadCRTFileFailed
            case secItemAddFailed(OSStatus)
        }
        guard let deviceCert = try SecCertificate.loadFromCrtFile(url: Self.deviceCrtURL) else {
            throw Error.loadCRTFileFailed
        }

        let addCertificateAttributes: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: deviceCert,
            kSecAttrLabel as String: kCertificateLabel
        ]

        let status = SecItemAdd(addCertificateAttributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw Error.secItemAddFailed(status)
        }
    }

    static func deviceCertificateRef() throws -> SecIdentity {
        enum DeviceCertificateRefError: Error {
            case noData
            case wrongType
        }
        let readQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecAttrLabel as String: kCertificateLabel
        ]

        var extractedData: AnyObject?
        SecItemCopyMatching(readQuery as CFDictionary, &extractedData)

        guard let cfIdentity = extractedData else {
            throw DeviceCertificateRefError.noData
        }
        guard CFGetTypeID(cfIdentity) == SecIdentityGetTypeID() else {
            throw DeviceCertificateRefError.wrongType
        }
        return cfIdentity as! SecIdentity
    }

    static func deleteKeys() {
        try? FileManager.default.removeItem(at: csrURL)
        try? FileManager.default.removeItem(at: deviceCrtURL)

        let deleteDeviceCertificateStatus = SecItemDelete([
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: kCertificateLabel
        ] as CFDictionary)

        log("deleteDeviceCertificateStatus", deleteDeviceCertificateStatus, deleteDeviceCertificateStatus == errSecSuccess)

        let deletePublicKeyStatus = SecItemDelete([
            kSecClass as String: kSecClassKey,
            kSecAttrLabel as String: kPublicKeyLabel
        ] as CFDictionary)

        log("deletePublicKeyStatus", deletePublicKeyStatus, deletePublicKeyStatus == errSecSuccess)

        let deletePrivateKeyStatus = SecItemDelete([
            kSecClass as String: kSecClassKey,
            kSecAttrLabel as String: kPrivateKeyLabel
        ] as CFDictionary)

        log("deletePrivateKeyStatus", deletePrivateKeyStatus, deletePrivateKeyStatus == errSecSuccess)
    }
}

private func getPublicKeyData(keyType: String, tag: String) throws -> Data {
    enum Error: Swift.Error {
        case secItemCopyMatching(OSStatus)
        case missingData
    }
    let query: [String: Any] = [
        String(kSecClass): kSecClassKey,
        String(kSecAttrKeyType): keyType,
        String(kSecAttrApplicationTag): tag,
        String(kSecReturnData): true
    ]

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard status == errSecSuccess else {
        throw Error.secItemCopyMatching(status)
    }
    guard let data = result as? Data else {
        throw Error.missingData
    }

    return data
}

private extension SecKey {

    static func generateKeyPair(
        keyType: String,
        size: UInt
    ) throws -> (privateKey:SecKey, publicKey:SecKey) {
        enum Error: Swift.Error {
            case secKeyGeneratePairFailed(OSStatus)
            case missingPublicKey
            case missingPrivateKey
        }

        let publicKeyAttrs: NSDictionary = [
            kSecAttrIsPermanent as String: true,
            kSecAttrLabel as String: kPublicKeyLabel,
            kSecAttrApplicationTag as String: kPublicKeyTag
        ]
        let privateKeyAttrs: NSDictionary = [
            kSecAttrIsPermanent as String: true,
            kSecAttrLabel as String: kPrivateKeyLabel,
            kSecAttrApplicationTag as String: kPrivateKeyTag
        ]
        let keyPairParameters: NSDictionary = [
            kSecAttrKeyType as String: keyType,
            kSecAttrKeySizeInBits as String: size,
            kSecPublicKeyAttrs as String: publicKeyAttrs,
            kSecPrivateKeyAttrs as String: privateKeyAttrs
        ]

        var publicKey: SecKey?
        var privateKey: SecKey?
        let status = SecKeyGeneratePair(keyPairParameters, &publicKey, &privateKey)

        guard status == errSecSuccess else {
            throw Error.secKeyGeneratePairFailed(status)
        }
        guard let publicKey = publicKey else {
            throw Error.missingPublicKey
        }
        guard let privateKey = privateKey else {
            throw Error.missingPrivateKey
        }
        return (privateKey, publicKey)
    }
}

private extension SecCertificate {

    static func loadFromCrtFile(url: URL) throws -> SecCertificate? {
        let certString = try String(contentsOf: url)
            .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "\n", with: "")

        let certData = Data(base64Encoded: certString.data(using: .utf8)!)!

        return SecCertificateCreateWithData(kCFAllocatorDefault, certData as CFData)
    }
}
