import FlipperClientSwift

class ExamplePlugin: FlipperPlugin {

    struct DisplayMessageResponse: Decodable {
        let message: String
    }

    func didConnect(connection: FlipperConnection) {
        print(#fileID, #function)
        connection.receive(method: "displayMessage") { (params: DisplayMessageResponse, responder) in
            print("DID RECEIVE", params)

            try! responder.success(response: [
                "greeting": "Hello from app! I received params: \(params)"
            ])
        }
    }

    func didDisconnect() {
        print(#fileID, #function)
    }

    func identifier() -> String {
        "Example"
    }
}

