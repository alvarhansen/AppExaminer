import Foundation

final class URLSessionSwizzle {

    static let shared = URLSessionSwizzle()

    var newTransactionRecorded: ((UUID, Date, URLRequest) -> Void)?
    var transactionUpdated: ((UUID, Date, HTTPURLResponse, Data?) -> Void)?

    fileprivate let recordQueue = DispatchQueue(label: "Swizzled URLSession recorder")

    private init() {
        swizzleTaskResume()
        swizzleDataTaskCreation()
    }

    private func swizzleTaskResume() {
        let majorVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        let urlsSessionTaskClass: AnyClass
        if (majorVersion < 9 || majorVersion >= 14) {
            urlsSessionTaskClass = URLSessionTask.self
        } else {
            urlsSessionTaskClass = NSClassFromString("__NSCFURLSessionTask")!
        }
        swizzleSelector(
            urlsSessionTaskClass,
            #selector(URLSessionTask.resume),
            #selector(URLSessionTask.urlsSessionTaskSwizzledResume)
        )
    }

    private func swizzleDataTaskCreation() {
        typealias URLRequestDataTask = (URLSession)
            -> (URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void)
            -> URLSessionDataTask

        swizzleSelector(
            URLSession.self,
            #selector(URLSession.dataTask(with:completionHandler:) as URLRequestDataTask),
            #selector(URLSession.dataTaskSwizzled(with:completionHandler:))
        )

        typealias URLDataTask = (URLSession)
            -> (URL, @escaping (Data?, URLResponse?, Error?) -> Void)
            -> URLSessionDataTask

        swizzleSelector(
            URLSession.self,
            #selector(URLSession.dataTask(with:completionHandler:) as URLDataTask),
            #selector(URLSession.dataTaskSwizzled2(with:completionHandler:))
        )
    }
}

private class ValueBox {
    let value: Any

    init(value: Any) {
        self.value = value
    }
}

private extension URLSessionTask {

    private static var uuidKey: UInt8 = 1

    var ___uuid: UUID? {
        get {
            guard let value = objc_getAssociatedObject(self, &Self.uuidKey) else {
                return nil
            }

            return ((value as! ValueBox).value as! UUID)
        }
        set {
            if let value = newValue {
                let box = ValueBox(value: value)
                objc_setAssociatedObject(self, &Self.uuidKey, box, .OBJC_ASSOCIATION_RETAIN)
            } else {
                objc_setAssociatedObject(self, &Self.uuidKey, nil, .OBJC_ASSOCIATION_RETAIN)
            }
        }
    }
}

private extension URLSessionTask {
    @objc func urlsSessionTaskSwizzledResume() {
        URLSessionSwizzle.shared.recordQueue.async {
            if self.___uuid == nil {
                let uuid = UUID()
                self.___uuid = uuid
                URLSessionSwizzle.shared.newTransactionRecorded?(uuid, Date(), self.currentRequest!)
            }
        }

        self.urlsSessionTaskSwizzledResume()
    }
}
private extension URLSession {

    @objc func dataTaskSwizzled(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        weak var taskRef: URLSessionDataTask?
        let task = self.dataTaskSwizzled(with: request) { data, response, error in
            Self.reportCompletion(task: taskRef, data: data, response: response, error: error)
        }
        taskRef = task
        return task
    }

    @objc func dataTaskSwizzled2(
        with url: URL,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        weak var taskRef: URLSessionDataTask?
        let task = self.dataTaskSwizzled2(with: url) { data, response, error in
            Self.reportCompletion(task: taskRef, data: data, response: response, error: error)
        }
        taskRef = task
        return task
    }

    private static func reportCompletion(task: URLSessionDataTask?, data: Data?, response: URLResponse?, error: Error?) {
        guard let uuid = task?.___uuid else {
            NSLog("Error, missing task uuid")
            return
        }
        guard let response = response as? HTTPURLResponse else {
            return
        }

        URLSessionSwizzle.shared.recordQueue.async {
            URLSessionSwizzle.shared.transactionUpdated?(uuid, Date(), response, data)
        }
    }
}

private func swizzleSelector(
    _ forClass: AnyClass,
    _ originalSelector: Selector,
    _ swizzledSelector: Selector
) {
    if let originalMethod = class_getInstanceMethod(forClass, originalSelector),
        let swizzledMethod = class_getInstanceMethod(forClass, swizzledSelector) {
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}
