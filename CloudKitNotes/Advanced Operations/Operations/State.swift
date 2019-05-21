import Foundation

internal enum State: Int, Comparable {
    static func < (lhs: State, rhs: State) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    static func == (lhs: State, rhs: State) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }

    /// The initial state of an `ANOperation`.
    case initialized

    /// The `ANOperation` is ready to begin evaluating conditions.
    case pending

    /// The `ANOperation` is evaluating conditions.
    case evaluatingConditions

    /**
     The `ANOperation`'s conditions have all been satisfied, and it is ready
     to execute.
     */
    case ready

    /// The `ANOperation` is executing.
    case executing

    /**
     Execution of the `ANOperation` has finished, but it has not yet notified
     the queue of this.
     */
    case finishing

    /// The `ANOperation` has finished executing.
    case finished

    func canTransitionToState(_ target: State, operationIsCancelled cancelled: Bool) -> Bool {
        switch (self, target) {
        case (.initialized, .pending):
            return true
        case (.pending, .evaluatingConditions):
            return true
        case (.pending, .finishing) where cancelled:
            return true
        case (.pending, .ready):
            return true
        case (.evaluatingConditions, .ready):
            return true
        case (.ready, .executing):
            return true
        case (.ready, .finishing):
            return true
        case (.executing, .finishing):
            return true
        case (.finishing, .finished):
            return true
        default:
            return false
        }
    }
}
