//
//  Copyright © 2015 Apple Inc. All Rights Reserved.
//  See LICENSE.txt for this sample’s licensing information
//
//  Modified by Andrew Podkovyrin, 2019
//

import Foundation

/**
 A simple condition that causes another condition to not enqueue its dependency.
 This is useful (for example) when you want to verify that you have access to
 the user's location, but you do not want to prompt them for permission if you
 do not already have it.
 */
struct SilentCondition<T: OperationCondition>: OperationCondition {
    let condition: T

    static var name: String {
        return "Silent<\(T.name)>"
    }

    static var isMutuallyExclusive: Bool {
        return T.isMutuallyExclusive
    }

    init(condition: T) {
        self.condition = condition
    }

    func dependency(for operation: ANOperation) -> Operation? {
        // Returning nil means we will never a dependency to be generated.
        return nil
    }

    func evaluate(for operation: ANOperation, completion: @escaping (OperationConditionResult) -> Void) {
        condition.evaluate(for: operation, completion: completion)
    }
}
