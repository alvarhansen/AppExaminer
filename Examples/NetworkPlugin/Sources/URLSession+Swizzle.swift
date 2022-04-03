//
//  URLSession+Swizzle.swift
//  NetworkPluginApp
//
//  Created by Alvar Hansen on 02.04.2022.
//

import Foundation
import FLEX

class URLSessionSwizzle {

    let newTransactionRecorded: ((String, Date, NSMutableURLRequest) -> Void)
    let transactionUpdated: ((String, Date, HTTPURLResponse, Data?) -> Void)

    init(
        newTransactionRecorded: @escaping ((String, Date, NSMutableURLRequest) -> Void),
        transactionUpdated: @escaping ((String, Date, HTTPURLResponse, Data?) -> Void)
    ) {
        self.newTransactionRecorded = newTransactionRecorded
        self.transactionUpdated = transactionUpdated

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewTransactionRecordedNotification(sender:)),
            name: .init("kFLEXNetworkRecorderNewTransactionNotification"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTransactionUpdatedNotification(sender:)),
            name: .init("kFLEXNetworkRecorderTransactionUpdatedNotification"),
            object: nil
        )

        FLEX.FLEXManager.shared.isNetworkDebuggingEnabled = true
    }

    @objc func handleNewTransactionRecordedNotification(sender: Notification) {
        guard let transaction = sender.userInfo?["transaction"] as? NSObject,
            let requestID = transaction.value(forKey: "requestID") as? String,
            let startTime = transaction.value(forKey: "startTime") as? Date,
            let request = transaction.value(forKey: "request") as? NSMutableURLRequest
        else {
            return
        }
//        NSLog("\(#function) \(sender), \(requestID)")

        newTransactionRecorded(requestID, startTime, request)
    }

    @objc func handleTransactionUpdatedNotification(sender: Notification) {
        guard let transaction = sender.userInfo?["transaction"] as? NSObject,
            let requestID = transaction.value(forKey: "requestID") as? String,
            let startTime = transaction.value(forKey: "startTime") as? Date,
            let duration = transaction.value(forKey: "duration") as? TimeInterval,
            let response = transaction.value(forKey: "response") as? HTTPURLResponse
        else {
            return
        }
        let cachedRequestBody = transaction.value(forKey: "cachedRequestBody") as? Data
//        NSLog("\(#function) \(requestID)")

        transactionUpdated(requestID, startTime.addingTimeInterval(duration), response, cachedRequestBody)
    }
}
