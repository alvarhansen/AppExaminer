import FlipperClientSwift
import Foundation

class NetworkPlugin: FlipperPlugin {

    struct MockResponsesResponse: Decodable {
        let routes: [String]
    }

    private var connection: FlipperConnection?
    private var urlSessionSwizzle: URLSessionSwizzle?

    func didConnect(connection: FlipperConnection) {
        self.connection = connection
        print(#fileID, #function)
//        connection.receive(method: "mockResponses") { (params: MockResponsesResponse, responder) in
//            print("DID RECEIVE", params)
//        }

        startObservingNetwork()
    }

    func didDisconnect() {
        print(#fileID, #function)
        connection = nil
    }

    func identifier() -> String {
        "Network"
    }

    func runInBackground() -> Bool {
        return true
    }

    private func startObservingNetwork() {
        guard urlSessionSwizzle == nil else { return }
        print(#fileID, #function)
        urlSessionSwizzle = URLSessionSwizzle(
            newTransactionRecorded: { id, date, mutableURLRequest in
                self.sendNewRequestInfo(params: NewRequestParams(
                    id: id.hashValue,
                    timestamp: date.timeIntervalSince1970 * 1000,
                    url: mutableURLRequest.url?.absoluteString,
                    method: mutableURLRequest.httpMethod,
                    headers: (mutableURLRequest.allHTTPHeaderFields ?? [:]).map {
                        NewRequestParams.HeaderPair(key: $0.key, value: $0.value)
                    },
                    data: mutableURLRequest.httpBody?.base64EncodedString()
                ))
            },
            transactionUpdated: { (id, date, response, data) in
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
        )


//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            let id = UUID().hashValue
//            self.sendNewRequestInfo(params: NewRequestParams(
//                id: id,
//                timestamp: Date().timeIntervalSince1970 * 1000,
//                url: "https://raw.githubusercontent.com/facebook/litho/master/docs/static/logo.png",
//                method: "GET",
//                headers: [.init(key: "foo", value: "bar")],
//                data: nil
//            ))
//
//
//            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//                self.sendNewResponseInfo(params: NewResponseParams(
//                    id: id,
//                    timestamp: Date().timeIntervalSince1970 * 1000,
//                    status: 200,
//                    reason: nil,
//                    headers: [],
//                    data: "hello world".data(using: .utf8)?.base64EncodedString()
//                ))
//            }
//        }
    }

    private func sendNewRequestInfo(params: NewRequestParams) {
        do {
            try connection?.send("newRequest", withParams: params)
        } catch {
            fatalError("\(error)")
        }
    }

    private func sendNewResponseInfo(params: NewResponseParams) {
        do {
            try connection?.send("newResponse", withParams: params)
        } catch {
            fatalError("\(error)")
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
    let method: String
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
