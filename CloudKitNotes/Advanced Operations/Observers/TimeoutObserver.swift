//
//  Copyright (C) 2015 Apple Inc. All Rights Reserved.
//  See LICENSE.txt for this sample’s licensing information
//
//  Abstract:
//  This file shows how to implement the OperationObserver protocol.
//

import Foundation

/**
 `TimeoutObserver` is a way to make an `ANOperation` automatically time out and
 cancel after a specified time interval.
 */
class TimeoutObserver: OperationObserver {
    // MARK: Properties

    private let timeout: TimeInterval

    // MARK: Initialization

    init(timeout: TimeInterval) {
        self.timeout = timeout
    }

    // MARK: OperationObserver

    func operationDidStart(_ operation: ANOperation) {
        // When the operation starts, queue up a block to cause it to time out.
        let when = DispatchTime.now() + timeout

        DispatchQueue.global(qos: .init(qos: operation.qualityOfService)).asyncAfter(deadline: when) {
            /*
             Cancel the operation if it hasn't finished and hasn't already
             been cancelled.
             */
            if !operation.isFinished && !operation.isCancelled {
                let error = OperationError.timedOut(timeout: self.timeout)
                operation.cancelWithError(error)
            }
        }
    }

    func operationDidCancel(_ operation: ANOperation) {
        // No op.
    }

    func operation(_ operation: ANOperation, didProduceOperation newOperation: Operation) {
        // No op.
    }

    func operationDidFinish(_ operation: ANOperation, errors: [Error]) {
        // No op.
    }
}
