//
//  Copyright (C) 2015 Apple Inc. All Rights Reserved.
//  See LICENSE.txt for this sample’s licensing information
//
//  Abstract:
//  This file contains the foundational subclass of NSOperation.
//

import Foundation

// swiftlint:disable block_based_kvo file_length

/**
 The subclass of `NSOperation` from which all other operations should be derived.
 This class adds both Conditions and Observers, which allow the operation to define
 extended readiness requirements, as well as notify many interested parties
 about interesting operation state changes
 */
class ANOperation: Operation {
    private static var anoperationContext = 0

    /*
     The completionBlock property has unexpected behaviors such as executing twice and executing on unexpected threads.
     BlockObserver executes in an expected manner.
     */
    @available(*, deprecated, message: "use BlockObserver completions instead")
    override var completionBlock: (() -> Void)? {
        // swiftlint:disable unused_setter_value
        set {
            fatalError("The completionBlock property on NSOperation has unexpected behavior and is not supported")
        }
        get {
            return nil
        }
        // swiftlint:enable unused_setter_value
    }

    // use the KVO mechanism to indicate that changes to "state" affect other properties as well
    @objc
    class func keyPathsForValuesAffectingIsReady() -> Set<String> {
        return [KeyPaths.state]
    }

    @objc
    class func keyPathsForValuesAffectingIsExecuting() -> Set<String> {
        return [KeyPaths.state]
    }

    @objc
    class func keyPathsForValuesAffectingIsFinished() -> Set<String> {
        return [KeyPaths.state]
    }

    @objc
    class func keyPathsForValuesAffectingIsCancelled() -> Set<String> {
        return [KeyPaths.cancelledState]
    }

    override init() {
        super.init()
        addObserver(self, forKeyPath: KeyPaths.isReady, options: [], context: &ANOperation.anoperationContext)
    }

    deinit {
        self.removeObserver(self, forKeyPath: KeyPaths.isReady, context: &ANOperation.anoperationContext)
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard context == &ANOperation.anoperationContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        stateAccess.lock()
        defer { stateAccess.unlock() }
        guard super.isReady && !isCancelled && state == .pending else { return }
        evaluateConditions()
    }

    /**
     Indicates that the ANOperation can now begin to evaluate readiness conditions,
     if appropriate.
     */
    func didEnqueue() {
        stateAccess.lock()
        defer { stateAccess.unlock() }
        state = .pending
    }

    private let stateAccess = NSRecursiveLock()
    /// Private storage for the `state` property that will be KVO observed.
    private var _state = State.initialized
    private let stateQueue = DispatchQueue(label: "Operations.ANOperation.state")
    private var state: State {
        get {
            return stateQueue.sync {
                _state
            }
        }
        set {
            /*
             It's important to note that the KVO notifications are NOT called from inside
             the lock. If they were, the app would deadlock, because in the middle of
             calling the `didChangeValueForKey()` method, the observers try to access
             properties like "isReady" or "isFinished". Since those methods also
             acquire the lock, then we'd be stuck waiting on our own lock. It's the
             classic definition of deadlock.
             */
            willChangeValue(forKey: KeyPaths.state)
            stateQueue.sync {
                guard _state != .finished else { return }
                assert(_state.canTransitionToState(newValue, operationIsCancelled: isCancelled),
                       "Performing invalid state transition. from: \(_state) to: \(newValue)")
                _state = newValue
            }
            didChangeValue(forKey: KeyPaths.state)
        }
    }

    // Here is where we extend our definition of "readiness".
    override var isReady: Bool {
        stateAccess.lock()
        defer { stateAccess.unlock() }

        guard super.isReady else { return false }

        guard !isCancelled else { return true }

        switch state {
        case .initialized, .evaluatingConditions, .pending:
            return false
        case .ready, .executing, .finishing, .finished:
            return true
        }
    }

    var userInitiated: Bool {
        get {
            return qualityOfService == .userInitiated
        }
        set {
            stateAccess.lock()
            defer { stateAccess.unlock() }

            assert(state < .executing, "Cannot modify userInitiated after execution has begun.")
            qualityOfService = newValue ? .userInitiated : .default
        }
    }

    override var isExecuting: Bool {
        return state == .executing
    }

    override var isFinished: Bool {
        return state == .finished
    }

    // swiftlint:disable identifier_name
    private var __cancelled = false
    // swiftlint:enable identifier_name
    private let cancelledQueue = DispatchQueue(label: "Operations.ANOperation.cancelled")
    private var _cancelled: Bool {
        get {
            var currentState = false
            cancelledQueue.sync {
                currentState = __cancelled
            }
            return currentState
        }
        set {
            stateAccess.lock()
            defer { stateAccess.unlock() }

            guard _cancelled != newValue else { return }

            willChangeValue(forKey: KeyPaths.cancelledState)
            cancelledQueue.sync {
                __cancelled = newValue
            }

            if state == .initialized || state == .pending {
                state = .ready
            }

            didChangeValue(forKey: KeyPaths.cancelledState)

            if newValue {
                for observer in observers {
                    observer.operationDidCancel(self)
                }
            }
        }
    }

    override var isCancelled: Bool {
        return _cancelled
    }

    private func evaluateConditions() {
        stateAccess.lock()
        defer { stateAccess.unlock() }

        assert(state == .pending && !isCancelled, "evaluateConditions() was called out-of-order")

        guard !conditions.isEmpty else {
            state = .ready
            return
        }

        state = .evaluatingConditions

        OperationConditionEvaluator.evaluate(conditions, operation: self) { failures in
            self.stateAccess.lock()
            defer { self.stateAccess.unlock() }

            if !failures.isEmpty {
                self.cancelWithErrors(failures)
            }

            self.state = .ready
        }
    }

    // MARK: Observers and Conditions

    private(set) var conditions: [OperationCondition] = []

    func addCondition(_ condition: OperationCondition) {
        assert(state < .evaluatingConditions, "Cannot modify conditions after execution has begun.")
        conditions.append(condition)
    }

    private(set) var observers: [OperationObserver] = []

    func addObserver(_ observer: OperationObserver) {
        assert(state < .executing, "Cannot modify observers after execution has begun.")
        observers.append(observer)
    }

    override func addDependency(_ operation: Operation) {
        assert(state <= .executing, "Dependencies cannot be modified after execution has begun.")
        super.addDependency(operation)
    }

    // MARK: Execution and Cancellation

    final override func main() {
        stateAccess.lock()

        assert(state == .ready, "This operation must be performed on an operation queue.")

        if internalErrors.isEmpty && !isCancelled {
            state = .executing
            stateAccess.unlock()

            for observer in observers {
                observer.operationDidStart(self)
            }

            execute()
        }
        else {
            finish()
            stateAccess.unlock()
        }
    }

    /**
     `execute()` is the entry point of execution for all `ANOperation` subclasses.
     If you subclass `ANOperation` and wish to customize its execution, you would
     do so by overriding the `execute()` method.

     At some point, your `ANOperation` subclass must call one of the "finish"
     methods defined below; this is how you indicate that your operation has
     finished its execution, and that operations dependent on yours can re-evaluate
     their readiness state.
     */
    func execute() {
        print("\(type(of: self)) must override `execute()`.")

        finish()
    }

    private let errorQueue = DispatchQueue(label: "Operations.ANOperation.internalErrors")
    private var _internalErrors: [Error] = []
    private var internalErrors: [Error] {
        get {
            return errorQueue.sync {
                _internalErrors
            }
        }
        set {
            errorQueue.sync {
                _internalErrors = newValue
            }
        }
    }

    var errors: [Error] {
        return internalErrors
    }

    override func cancel() {
        stateAccess.lock()
        defer { stateAccess.unlock() }
        guard !isFinished else { return }

        _cancelled = true

        if state > .ready {
            finish()
        }
    }

    func cancelWithErrors(_ errors: [Error]) {
        internalErrors += errors
        cancel()
    }

    func cancelWithError(_ error: Error) {
        cancelWithErrors([error])
    }

    final func produceOperation(_ operation: Operation) {
        for observer in observers {
            observer.operation(self, didProduceOperation: operation)
        }
    }

    // MARK: Finishing

    /**
     Most operations may finish with a single error, if they have one at all.
     This is a convenience method to simplify calling the actual `finish()`
     method. This is also useful if you wish to finish with an error provided
     by the system frameworks. As an example, see `DownloadEarthquakesOperation`
     for how an error from an `NSURLSession` is passed along via the
     `finishWithError()` method.
     */
    final func finishWithError(_ error: Error?) {
        if let error = error {
            finish([error])
        }
        else {
            finish()
        }
    }

    /**
     A private property to ensure we only notify the observers once that the
     operation has finished.
     */
    private var hasFinishedAlready = false

    final func finish(_ errors: [Error] = []) {
        stateAccess.lock()
        defer { stateAccess.unlock() }
        guard !hasFinishedAlready else { return }

        hasFinishedAlready = true
        state = .finishing

        internalErrors += errors

        finished(internalErrors)

        for observer in observers {
            observer.operationDidFinish(self, errors: internalErrors)
        }

        state = .finished
    }

    /**
     Subclasses may override `finished(_:)` if they wish to react to the operation
     finishing with errors. For example, the `LoadModelOperation` implements
     this method to potentially inform the user about an error when trying to
     bring up the Core Data stack.
     */
    func finished(_ errors: [Error]) {}

    // swiftlint:disable unavailable_function
    override func waitUntilFinished() {
        /*
         Waiting on operations is almost NEVER the right thing to do. It is
         usually superior to use proper locking constructs, such as `dispatch_semaphore_t`
         or `dispatch_group_notify`, or even `NSLocking` objects. Many developers
         use waiting when they should instead be chaining discrete operations
         together using dependencies.

         To reinforce this idea, invoking `waitUntilFinished()` will crash your
         app, as incentive for you to find a more appropriate way to express
         the behavior you're wishing to create.
         */
        fatalError("Waiting on operations is an anti-pattern.")
    }

    // swiftlint:enable unavailable_function
}

private extension ANOperation {
    enum KeyPaths {
        static let state = "state"
        static let cancelledState = "cancelledState"
        static let isReady = "isReady"
    }
}
