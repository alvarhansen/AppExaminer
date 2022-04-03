import FlipperClientSwift
import UIKit

@UIApplicationMain
class ApplicationMain: UIResponder, UIApplicationDelegate {
    private lazy var _window = UIWindow()

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        _window.rootViewController = UINavigationController(
            rootViewController: UIViewController()
        )

        FlipperClient.shared.addPlugin(NetworkPlugin())
        FlipperClient.shared.start()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.performPOSTRequest()
        }

        return true
    }


    private func performPOSTRequest() {
        NSLog("\(#function)")

        var postRequest = URLRequest(
            url: URL(string: "https://demo9512366.mockable.io/FlipperPost")!
        )
        postRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        postRequest.addValue("application/json", forHTTPHeaderField: "Accept")

        let dict = ["app" : "Flipper", "remarks": "Its Awesome"]
        postRequest.httpBody = try! JSONSerialization.data(withJSONObject: dict, options: [])
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
