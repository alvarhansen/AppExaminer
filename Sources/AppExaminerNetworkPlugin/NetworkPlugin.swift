import AppExaminer
import Foundation

public class NetworkPlugin: AppExaminerPlugin {

    struct MockResponsesResponse: Decodable {
        let routes: [String]
    }

    private var connection: AppExaminerConnection?

    public init() {
        startObservingNetwork()
    }

    public func didConnect(connection: AppExaminerConnection) {
        self.connection = connection
    }

    public func didDisconnect() {
        connection = nil
    }

    public func identifier() -> String {
        "Network"
    }

    public func runInBackground() -> Bool {
        return true
    }

    private func startObservingNetwork() {
        URLSessionSwizzle.shared.newTransactionRecorded = { id, date, urlRequest in
            self.sendNewRequestInfo(params: NewRequestParams(
                id: id.hashValue,
                timestamp: date.timeIntervalSince1970 * 1000,
                url: urlRequest.url?.absoluteString,
                method: urlRequest.httpMethod,
                headers: (urlRequest.allHTTPHeaderFields ?? [:]).map {
                    NewRequestParams.HeaderPair(key: $0.key, value: $0.value)
                },
                data: urlRequest.httpBody?.base64EncodedString()
            ))
        }
        URLSessionSwizzle.shared.transactionUpdated = { (id, date, response, data) in
            self.sendNewResponseInfo(params: NewResponseParams(
                id: id.hashValue,
                timestamp: date.timeIntervalSince1970 * 1000,
                status: response.statusCode,
                reason: HTTPURLResponse.localizedString(forStatusCode: response.statusCode),
                headers: response.allHeaderFields.compactMap { (key: AnyHashable, value: Any) in
                    guard let keyString = key as? String, let keyValue = value as? String else {
                        return nil
                    }
                    return .init(key: keyString, value: keyValue)
                },
                data: data?.base64EncodedString()
            ))
        }
    }

    private func sendNewRequestInfo(params: NewRequestParams) {
        do {
            try connection?.send("newRequest", withParams: params)
        } catch {
            NSLog("Error at \(#function): \(error)")
        }
    }

    private func sendNewResponseInfo(params: NewResponseParams) {
        do {
            try connection?.send("newResponse", withParams: params)
        } catch {
            NSLog("Error at \(#function): \(error)")
        }
    }
}


private struct NewRequestParams: Encodable {
    struct HeaderPair: Encodable {
        let key: String
        let value: String
    }
    let id: Int
    let timestamp: Double
    let url: String?
    let method: String?
    let headers: [HeaderPair]
    let data: String?
}

private struct NewResponseParams: Encodable {
    struct HeaderPair: Encodable {
        let key: String
        let value: String
    }
    let id: Int
    let timestamp: Double
    let status: Int
    let reason: String?
    let headers: [HeaderPair]
    let data: String?
}
