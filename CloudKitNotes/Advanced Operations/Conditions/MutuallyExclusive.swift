//
//  Copyright © 2015 Apple Inc. All Rights Reserved.
//  See LICENSE.txt for this sample’s licensing information
//
//  Modified by Andrew Podkovyrin, 2019
//

import Foundation

/// A generic condition for describing kinds of operations that may not execute concurrently.
struct MutuallyExclusive<T>: OperationCondition {
    static var name: String {
        return "MutuallyExclusive<\(T.self)>"
    }

    static var isMutuallyExclusive: Bool {
        return true
    }

    init() {}

    func dependency(for operation: ANOperation) -> Operation? {
        return nil
    }

    func evaluate(for operation: ANOperation, completion: @escaping (OperationConditionResult) -> Void) {
        completion(.success)
    }
}

enum Alert {}

typealias AlertPresentation = MutuallyExclusive<Alert>
