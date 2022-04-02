import Foundation

public protocol FlipperResponder {
    func success<T: Encodable>(response: T) throws
    func error<T: Encodable>(response: T) throws
}

public protocol FlipperConnection {

    func isMethodSupported(_ method: String) -> Bool

//    func send<T: Encodable>(_ method: String, withParams params: T)

    func call(method: String, identifier: Int, params: (Decodable.Type) -> Decodable)

    func receive<T: Decodable>(method: String, callback: @escaping (T, FlipperResponder) -> Void)
}
