//
//  Copyright (C) 2015 Apple Inc. All Rights Reserved.
//  See LICENSE.txt for this sample’s licensing information
//
//  Abstract:
//  This file contains an NSOperationQueue subclass.
//

import Foundation

/**
 The delegate of an `OperationQueue` can respond to `ANOperation` lifecycle
 events by implementing these methods.

 In general, implementing `OperationQueueDelegate` is not necessary; you would
 want to use an `OperationObserver` instead. However, there are a couple of
 situations where using `OperationQueueDelegate` can lead to simpler code.
 For example, `GroupOperation` is the delegate of its own internal
 `OperationQueue` and uses it to manage dependencies.
 */
@objc protocol ANOperationQueueDelegate: AnyObject {
    @objc
    optional func operationQueue(_ operationQueue: OperationQueue,
                                 willAddOperation operation: Operation)
    @objc
    optional func operationQueue(_ operationQueue: OperationQueue,
                                 operationDidFinish operation: Operation,
                                 withErrors errors: [Error])
}

/**
 `OperationQueue` is an `NSOperationQueue` subclass that implements a large
 number of "extra features" related to the `ANOperation` class:

 - Notifying a delegate of all operation completion
 - Extracting generated dependencies from operation conditions
 - Setting up dependencies to enforce mutual exclusivity
 */
class ANOperationQueue: OperationQueue {
    weak var delegate: ANOperationQueueDelegate?

    override func addOperation(_ operation: Operation) {
        if let operation = operation as? ANOperation {
            // Set up a `BlockObserver` to invoke the `OperationQueueDelegate` method.
            let delegate = BlockObserver(
                startHandler: nil,
                produceHandler: { [weak self] in
                    self?.addOperation($1)
                },
                finishHandler: { [weak self] finishedOperation, errors in
                    if let self = self {
                        self.delegate?.operationQueue?(self, operationDidFinish: finishedOperation, withErrors: errors)
                    }
                }
            )
            operation.addObserver(delegate)

            // Extract any dependencies needed by this operation.
            let dependencies = operation.conditions.compactMap {
                $0.dependency(for: operation)
            }

            for dependency in dependencies {
                operation.addDependency(dependency)

                addOperation(dependency)
            }

            /*
             With condition dependencies added, we can now see if this needs
             dependencies to enforce mutual exclusivity.
             */
            let concurrencyCategories: [String] = operation.conditions.compactMap { condition in
                guard type(of: condition).isMutuallyExclusive else { return nil }

                return "\(type(of: condition))"
            }

            if !concurrencyCategories.isEmpty {
                // Set up the mutual exclusivity dependencies.
                let exclusivityController = ExclusivityController.sharedExclusivityController

                exclusivityController.addOperation(operation, categories: concurrencyCategories)

                operation.addObserver(BlockObserver { operation, _ in
                    exclusivityController.removeOperation(operation, categories: concurrencyCategories)
                })
            }
        }
        else {
            /*
             For regular `NSOperation`s, we'll manually call out to the queue's
             delegate we don't want to just capture "operation" because that
             would lead to the operation strongly referencing itself and that's
             the pure definition of a memory leak.
             */
            operation.addCompletionBlock { [weak self, weak operation] in
                guard let queue = self, let operation = operation else { return }
                queue.delegate?.operationQueue?(queue, operationDidFinish: operation, withErrors: [])
            }
        }

        delegate?.operationQueue?(self, willAddOperation: operation)
        super.addOperation(operation)

        /*
         Indicate to the operation that we've finished our extra work on it
         and it's now it a state where it can proceed with evaluating conditions,
         if appropriate.
         */
        if let operation = operation as? ANOperation {
            operation.didEnqueue()
        }
    }

    override func addOperations(_ operations: [Operation], waitUntilFinished wait: Bool) {
        /*
         The base implementation of this method does not call `addOperation()`,
         so we'll call it ourselves.
         */
        for operation in operations {
            addOperation(operation)
        }

        if wait {
            for operation in operations {
                operation.waitUntilFinished()
            }
        }
    }
}
