//
//  Copyright © 2015 Apple Inc. All Rights Reserved.
//  See LICENSE.txt for this sample’s licensing information
//
//  Modified by Andrew Podkovyrin, 2019
//

import Foundation

// MARK: - Conditions

/**
 A protocol for defining conditions that must be satisfied in order for an
 operation to begin execution.
 */
protocol OperationCondition {
    /**
     The name of the condition. This is used in userInfo dictionaries of `.ConditionFailed`
     errors as the value of the `OperationConditionKey` key.
     */
    static var name: String { get }

    /**
     Specifies whether multiple instances of the conditionalized operation may
     be executing simultaneously.
     */
    static var isMutuallyExclusive: Bool { get }

    /**
     Some conditions may have the ability to satisfy the condition if another
     operation is executed first. Use this method to return an operation that
     (for example) asks for permission to perform the operation

     - parameter operation: The `Operation` to which the Condition has been added.
     - returns: An `NSOperation`, if a dependency should be automatically added. Otherwise, `nil`.
     - note: Only a single operation may be returned as a dependency. If you
     find that you need to return multiple operations, then you should be
     expressing that as multiple conditions. Alternatively, you could return
     a single `GroupOperation` that executes multiple operations internally.
     */
    func dependency(for operation: ANOperation) -> Operation?

    /// Evaluate the condition, to see if it has been satisfied or not.
    func evaluate(for operation: ANOperation, completion: @escaping (OperationConditionResult) -> Void)
}

/**
 An enum to indicate whether an `OperationCondition` was satisfied, or if it
 failed with an error.
 */
enum OperationConditionResult {
    case success
    case failure(Error)
}

private extension OperationConditionResult {
    var error: Error? {
        if case let .failure(error) = self {
            return error
        }
        return nil
    }
}

// MARK: Evaluate Conditions

struct OperationConditionEvaluator {
    static func evaluate(_ conditions: [OperationCondition],
                         operation: ANOperation,
                         completion: @escaping ([Error]) -> Void) {
        // Check conditions.
        let conditionGroup = DispatchGroup()

        var results = [OperationConditionResult?](repeating: nil, count: conditions.count)
        // Ask each condition to evaluate and store its result in the "results" array.
        for (index, condition) in conditions.enumerated() {
            conditionGroup.enter()
            condition.evaluate(for: operation) { result in
                results[index] = result
                conditionGroup.leave()
            }
        }

        // After all the conditions have evaluated, this block will execute.
        conditionGroup.notify(queue: DispatchQueue.global()) {
            // Aggregate the errors that occurred, in order.
            let failures = results.compactMap { $0?.error }

            assert(!operation.isCancelled || !failures.isEmpty,
                   "If condition causes operation to be cancelled it should return error")
            // /*
            //  If any of the conditions caused this operation to be cancelled,
            //  check for that.
            //  */
            // if operation.isCancelled {
            //     failures.append(OperationError(code: .conditionFailed))
            // }

            completion(failures)
        }
    }
}
