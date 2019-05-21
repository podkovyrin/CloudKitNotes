//
//  Copyright (C) 2015 Apple Inc. All Rights Reserved.
//  See LICENSE.txt for this sample’s licensing information
//
//  Abstract:
//  This file shows how operations can be composed together to form new operations.
//

import Foundation

/**
 A subclass of `ANOperation` that executes zero or more operations as part of its
 own execution. This class of operation is very useful for abstracting several
 smaller operations into a larger operation. As an example, the `GetEarthquakesOperation`
 is composed of both a `DownloadEarthquakesOperation` and a `ParseEarthquakesOperation`.

 Additionally, `GroupOperation`s are useful if you establish a chain of dependencies,
 but part of the chain may "loop". For example, if you have an operation that
 requires the user to be authenticated, you may consider putting the "login"
 operation inside a group operation. That way, the "login" operation may produce
 subsequent operations (still within the outer `GroupOperation`) that will all
 be executed before the rest of the operations in the initial chain of operations.
 */
class GroupOperation: ANOperation {
    private let internalQueue = ANOperationQueue()
    private let startingOperation = BlockOperation(block: {})
    private let finishingOperation = BlockOperation(block: {})

    private var _aggregatedErrors: [Error] = []
    private let aggregateQueue = DispatchQueue(label: "Operations.GroupOperations.aggregateErrors")
    private var aggregatedErrors: [Error] {
        get {
            var errors: [Error] = []
            aggregateQueue.sync {
                errors = _aggregatedErrors
            }
            return errors
        }
        set {
            aggregateQueue.sync {
                self._aggregatedErrors = newValue
            }
        }
    }

    convenience init(operations: Operation...) {
        self.init(operations: operations)
    }

    init(operations: [Operation]) {
        super.init()

        internalQueue.isSuspended = true
        internalQueue.delegate = self
        internalQueue.addOperation(startingOperation)

        for operation in operations {
            internalQueue.addOperation(operation)
        }
    }

    override func cancel() {
        internalQueue.cancelAllOperations()
        internalQueue.isSuspended = false
        super.cancel()
    }

    override func execute() {
        internalQueue.isSuspended = false
        internalQueue.addOperation(finishingOperation)
    }

    func addOperation(_ operation: Operation) {
        internalQueue.addOperation(operation)
    }

    /**
     Note that some part of execution has produced an error.
     Errors aggregated through this method will be included in the final array
     of errors reported to observers and to the `finished(_:)` method.
     */
    final func aggregateError(_ error: Error) {
        aggregatedErrors.append(error)
    }

    func operationDidFinish(_ operation: Operation, withErrors errors: [Error]) {
        // For use by subclassers.
    }
}

extension GroupOperation: ANOperationQueueDelegate {
    final func operationQueue(_ operationQueue: OperationQueue,
                              willAddOperation operation: Operation) {
        assert(!finishingOperation.isFinished && !finishingOperation.isExecuting,
               "cannot add new operations to a group after the group has completed")

        /*
         Some operation in this group has produced a new operation to execute.
         We want to allow that operation to execute before the group completes,
         so we'll make the finishing operation dependent on this newly-produced operation.
         */
        if operation !== finishingOperation {
            finishingOperation.addDependency(operation)
        }

        /*
         All operations should be dependent on the "startingOperation".
         This way, we can guarantee that the conditions for other operations
         will not evaluate until just before the operation is about to run.
         Otherwise, the conditions could be evaluated at any time, even
         before the internal operation queue is unsuspended.
         */
        if operation !== startingOperation {
            operation.addDependency(startingOperation)
        }
    }

    final func operationQueue(_ operationQueue: OperationQueue,
                              operationDidFinish operation: Operation,
                              withErrors errors: [Error]) {
        aggregatedErrors.append(contentsOf: errors)

        if operation === finishingOperation {
            internalQueue.isSuspended = true
            finish(aggregatedErrors)
        }
        else if operation !== startingOperation {
            operationDidFinish(operation, withErrors: errors)
        }
    }
}
