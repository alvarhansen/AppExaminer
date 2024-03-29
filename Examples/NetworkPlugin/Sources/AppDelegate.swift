import AppExaminerCore
import AppExaminerNetworkPlugin
import AppExaminerWebSocketServerConnection
import FlipperDesktopAppConnection
import UIKit

@UIApplicationMain
class ApplicationMain: UIResponder, UIApplicationDelegate {
    private lazy var _window = UIWindow()

    var appExaminerClient: AppExaminerClient?

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        _window.rootViewController = UINavigationController(
            rootViewController: UIViewController()
        )

        appExaminerClient = AppExaminerClient(connectionManager: AppExaminerWebSocketServerConnectionManager())
//        appExaminerClient = AppExaminerClient(connectionManager: FlipperDesktopAppConnectionManager())
        appExaminerClient?.addPlugin(NetworkPlugin())
        appExaminerClient?.start()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.performPOSTRequest()
        }

        return true
    }


    private func performPOSTRequest() {
        NSLog("\(#function)")

        var postRequest = URLRequest(
            url: URL(string: "https://jsonplaceholder.typicode.com/posts/")!
        )
        postRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        postRequest.addValue("application/json", forHTTPHeaderField: "Accept")

        postRequest.httpMethod = "POST"

        let dataTask = URLSession.shared.dataTask(with: postRequest) { (data, response, error) in
            if let error = error {
                NSLog("Received error in POST API Error:\(error.localizedDescription)")
                return
            }

            guard let _ = data else {
                NSLog("Received no data in POST API")
                return
            }

            NSLog("Received response from POST API")
        }
        dataTask.resume()
    }
}
