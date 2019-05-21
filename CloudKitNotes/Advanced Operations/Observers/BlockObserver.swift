//
//  Copyright (C) 2015 Apple Inc. All Rights Reserved.
//  See LICENSE.txt for this sample’s licensing information
//
//  Abstract:
//  This file shows how to implement the OperationObserver protocol.
//

import Foundation

/**
 The `BlockObserver` is a way to attach arbitrary blocks to significant events
 in an `ANOperation`'s lifecycle.
 */
class BlockObserver: OperationObserver {
    // MARK: Properties

    private let startHandler: ((ANOperation) -> Void)?
    private let cancelHandler: ((ANOperation) -> Void)?
    private let produceHandler: ((ANOperation, Operation) -> Void)?
    private let finishHandler: ((ANOperation, [Error]) -> Void)?

    init(startHandler: ((ANOperation) -> Void)? = nil,
         cancelHandler: ((ANOperation) -> Void)? = nil,
         produceHandler: ((ANOperation, Operation) -> Void)? = nil,
         finishHandler: ((ANOperation, [Error]) -> Void)? = nil) {
        self.startHandler = startHandler
        self.cancelHandler = cancelHandler
        self.produceHandler = produceHandler
        self.finishHandler = finishHandler
    }

    // MARK: OperationObserver

    func operationDidStart(_ operation: ANOperation) {
        startHandler?(operation)
    }

    func operationDidCancel(_ operation: ANOperation) {
        cancelHandler?(operation)
    }

    func operation(_ operation: ANOperation, didProduceOperation newOperation: Operation) {
        produceHandler?(operation, newOperation)
    }

    func operationDidFinish(_ operation: ANOperation, errors: [Error]) {
        finishHandler?(operation, errors)
    }
}
