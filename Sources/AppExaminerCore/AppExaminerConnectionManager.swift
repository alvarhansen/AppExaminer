import Foundation

public protocol WebSocketConnection: AnyObject {
    func send(data: Data) throws
}

public protocol AppExaminerConnectionManager {
    func start(delegate: AppExaminerConnectionManagerDelegate)
}

public protocol AppExaminerConnectionManagerDelegate: AnyObject {
    func didReceiveMessage(data: Data, sender: WebSocketConnection)
}
