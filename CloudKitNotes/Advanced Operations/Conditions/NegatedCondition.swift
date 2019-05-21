//
//  Copyright © 2015 Apple Inc. All Rights Reserved.
//  See LICENSE.txt for this sample’s licensing information
//
//  Modified by Andrew Podkovyrin, 2019
//

import Foundation

/**
 A simple condition that negates the evaluation of another condition.
 This is useful (for example) if you want to only execute an operation if the
 network is NOT reachable.
 */
struct NegatedCondition<T: OperationCondition>: OperationCondition {
    static var name: String {
        return "Not<\(T.name)>"
    }

    static var isMutuallyExclusive: Bool {
        return T.isMutuallyExclusive
    }

    let condition: T

    init(condition: T) {
        self.condition = condition
    }

    func dependency(for operation: ANOperation) -> Operation? {
        return condition.dependency(for: operation)
    }

    func evaluate(for operation: ANOperation, completion: @escaping (OperationConditionResult) -> Void) {
        condition.evaluate(for: operation) { result in
            switch result {
            case .success:
                // If the composed condition succeeded, then this one failed.
                let error = OperationError.negatedConditionFailed(notCondition: type(of: self.condition).name)
                completion(.failure(error))
            case .failure:
                // If the composed condition failed, then this one succeeded.
                completion(.success)
            }
        }
    }
}
