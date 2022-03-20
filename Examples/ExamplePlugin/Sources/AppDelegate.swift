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

        FlipperClient.shared.addPlugin(ExamplePlugin())
        FlipperClient.shared.start()

        return true
    }

}
