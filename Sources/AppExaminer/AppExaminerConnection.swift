import Foundation

public protocol AppExaminerResponder {
    func success<T: Encodable>(response: T) throws
    func error<T: Encodable>(response: T) throws
}

public protocol AppExaminerConnection {

    func isMethodSupported(_ method: String) -> Bool

    func send<T: Encodable>(_ method: String, withParams params: T) throws

    func call(method: String, identifier: Int, params: (Decodable.Type) -> Decodable)

    func receive<T: Decodable>(method: String, callback: @escaping (T, AppExaminerResponder) -> Void)
}
