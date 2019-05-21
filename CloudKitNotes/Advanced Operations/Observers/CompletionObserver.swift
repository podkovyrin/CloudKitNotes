//
//  CompletionObserver.swift
//  CloudKitNotes
//
//  Created by Andrew Podkovyrin on 16/05/2019.
//  Copyright © 2019 AP. All rights reserved.
//

import Foundation

class CompletionObserver: OperationObserver {
    private let completion: (ANOperation, [Error]) -> Void

    init(_ completion: @escaping (ANOperation, [Error]) -> Void) {
        self.completion = completion
    }

    // MARK: OperationObserver

    func operationDidStart(_ operation: ANOperation) {}

    func operationDidCancel(_ operation: ANOperation) {}

    func operation(_ operation: ANOperation, didProduceOperation newOperation: Operation) {}

    func operationDidFinish(_ operation: ANOperation, errors: [Error]) {
        DispatchQueue.main.async {
            self.completion(operation, errors)
        }
    }
}
