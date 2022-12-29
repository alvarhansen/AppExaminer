
public protocol AppExaminerPlugin {

    func identifier() -> String

    func didConnect(connection: AppExaminerConnection)

    func didDisconnect()

    func runInBackground() -> Bool
}

public extension AppExaminerPlugin {
    func runInBackground() -> Bool {
        return false
    }
}
