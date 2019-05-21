@testable import CloudKitNotes

import Foundation
import XCTest

// swiftlint:disable identifier_name file_length type_body_length nesting force_unwrapping implicitly_unwrapped_optional

struct TestCondition: OperationCondition {
    static let name = "TestCondition"
    static let isMutuallyExclusive = false
    var dependencyOperation: Foundation.Operation?

    var conditionBlock: () -> Bool = { true }

    func dependency(for operation: ANOperation) -> Operation? {
        return dependencyOperation
    }

    func evaluate(for operation: ANOperation, completion: @escaping (OperationConditionResult) -> Void) {
        if conditionBlock() {
            completion(.success)
        }
        else {
            completion(.failure(NSError(domain: "test-domain", code: 1, userInfo: [:]) as Error))
        }
    }
}

class TestObserver: OperationObserver {
    var errors: [Error]?

    var didStartBlock: (() -> Void)?
    var didEndBlock: (() -> Void)?
    var didCancelBlock: (() -> Void)?
    var didProduceBlock: (() -> Void)?

    func operationDidStart(_ operation: ANOperation) {
        if let didStartBlock = didStartBlock {
            didStartBlock()
        }
    }

    func operation(_ operation: ANOperation, didProduceOperation newOperation: Foundation.Operation) {
        if let didProduceBlock = didProduceBlock {
            didProduceBlock()
        }
    }

    func operationDidCancel(_ operation: ANOperation) {
        if let didCancelBlock = didCancelBlock {
            didCancelBlock()
        }
    }

    func operationDidFinish(_ operation: ANOperation, errors: [Error]) {
        self.errors = errors

        if let didEndBlock = didEndBlock {
            didEndBlock()
        }
    }
}

class PSOperationsTests: XCTestCase {
    func testAddingMultipleDeps() {
        let op = Foundation.Operation()

        let deps = [Foundation.Operation(), Foundation.Operation(), Foundation.Operation()]

        op.addDependencies(deps)

        XCTAssertEqual(deps.count, op.dependencies.count)
    }

    func testStandardOperation() {
        let expectation = self.expectation(description: "block")

        let opQueue = ANOperationQueue()

        let op = Foundation.BlockOperation { () -> Void in
            expectation.fulfill()
        }

        opQueue.addOperation(op)

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    func testBlockOperation_noConditions_noDependencies() {
        let expectation = self.expectation(description: "block")

        let opQueue = ANOperationQueue()

        let op = ANBlockOperation {
            expectation.fulfill()
        }

        opQueue.addOperation(op)

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    func testOperation_withPassingCondition_noDependencies() {
        let expectation = self.expectation(description: "block")

        let opQueue = ANOperationQueue()

        let op = ANBlockOperation {
            expectation.fulfill()
        }

        op.addCondition(TestCondition())

        opQueue.addOperation(op)

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    func testOperation_withFailingCondition_noDependencies() {
        let opQueue = ANOperationQueue()

        let op = ANBlockOperation {
            XCTFail("Should not have run the block operation")
        }

        keyValueObservingExpectation(for: op, keyPath: "isCancelled") { op, _ in
            if let op = op as? Foundation.Operation {
                return op.isCancelled
            }

            return false
        }

        XCTAssertFalse(op.isCancelled, "Should not yet have cancelled the operation")

        var condition = TestCondition()

        condition.conditionBlock = {
            false
        }

        let exp = expectation(description: "observer")

        let observer = TestObserver()

        observer.didEndBlock = {
            XCTAssertEqual(observer.errors?.count, 1)
            exp.fulfill()
        }

        op.addCondition(condition)
        op.addObserver(observer)
        opQueue.addOperation(op)

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    func testOperation_withPassingCondition_andConditionDependency_noDependencies() {
        let expectation = self.expectation(description: "block")
        let expectation2 = self.expectation(description: "block2")

        var fulfilledExpectations = [XCTestExpectation]()

        let opQueue = ANOperationQueue()

        let op = ANBlockOperation {
            expectation.fulfill()
            fulfilledExpectations.append(expectation)
        }

        var testCondition = TestCondition()
        testCondition.dependencyOperation = ANBlockOperation {
            expectation2.fulfill()
            fulfilledExpectations.append(expectation2)
        }

        op.addCondition(testCondition)

        opQueue.addOperation(op)

        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertEqual(fulfilledExpectations, [expectation2, expectation], "Expectations fulfilled out of order")
        }
    }

    func testOperation_noCondition_hasDependency() {
        let anExpectation = expectation(description: "block")
        let expectationDependency = expectation(description: "block2")

        var fulfilledExpectations = [XCTestExpectation]()

        let opQueue = ANOperationQueue()

        let op = ANBlockOperation {
            anExpectation.fulfill()
            fulfilledExpectations.append(anExpectation)
        }

        let opDependency = ANBlockOperation {
            expectationDependency.fulfill()
            fulfilledExpectations.append(expectationDependency)
        }

        op.addDependency(opDependency)

        opQueue.addOperation(op)
        opQueue.addOperation(opDependency)

        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertEqual(fulfilledExpectations,
                           [expectationDependency,
                            anExpectation],
                           "Expectations fulfilled out of order")
        }
    }

    func testGroupOperation() {
        let exp1 = expectation(description: "block1")
        let exp2 = expectation(description: "block2")

        let op1 = Foundation.BlockOperation {
            exp1.fulfill()
        }

        let op2 = Foundation.BlockOperation {
            exp2.fulfill()
        }

        let groupOp = GroupOperation(operations: op1, op2)

        keyValueObservingExpectation(for: groupOp, keyPath: "isFinished") { op, _ in
            if let op = op as? Foundation.Operation {
                return op.isFinished
            }

            return false
        }

        let opQ = ANOperationQueue()

        opQ.addOperation(groupOp)

        waitForExpectations(timeout: 5.0, handler: nil)
    }

    func testGroupOperation_cancelBeforeExecuting() {
        let exp1 = expectation(description: "block1")
        let exp2 = expectation(description: "block2")

        let op1 = Foundation.BlockOperation {
            XCTFail("should not execute -- cancelled")
        }

        op1.completionBlock = {
            exp1.fulfill()
        }

        let op2 = Foundation.BlockOperation {
            XCTFail("should not execute -- cancelled")
        }

        op2.completionBlock = {
            exp2.fulfill()
        }

        let groupOp = GroupOperation(operations: op1, op2)

        keyValueObservingExpectation(for: groupOp, keyPath: "isFinished") { op, _ in
            if let op = op as? Foundation.Operation {
                return op.isFinished
            }

            return false
        }

        let opQ = ANOperationQueue()

        opQ.isSuspended = true
        opQ.addOperation(groupOp)
        groupOp.cancel()
        opQ.isSuspended = false

        waitForExpectations(timeout: 5.0, handler: nil)
    }

    func testDelayOperation() {
        let delay: TimeInterval = 0.1

        let then = Date()
        let op = DelayOperation(interval: delay)

        keyValueObservingExpectation(for: op, keyPath: "isFinished") { op, _ in
            if let op = op as? Foundation.Operation {
                return op.isFinished
            }

            return false
        }

        ANOperationQueue().addOperation(op)

        waitForExpectations(timeout: delay + 1) { _ in
            let now = Date()
            let diff = now.timeIntervalSince(then)
            XCTAssertTrue(diff >= delay, "Didn't delay long enough")
        }
    }

    func testDelayOperation_With0() {
        let delay: TimeInterval = 0.0

        let then = Date()
        let op = DelayOperation(interval: delay)

        var done = false
        let lock = NSLock()

        keyValueObservingExpectation(for: op, keyPath: "isFinished") { op, _ in
            lock.lock()
            if let op = op as? Foundation.Operation, !done {
                done = op.isFinished
                lock.unlock()
                return op.isFinished
            }

            lock.unlock()

            return false
        }

        ANOperationQueue().addOperation(op)

        waitForExpectations(timeout: delay + 1) { _ in
            let now = Date()
            let diff = now.timeIntervalSince(then)
            XCTAssertTrue(diff >= delay, "Didn't delay long enough")
        }
    }

    func testDelayOperation_WithDate() {
        let delay: TimeInterval = 1
        let date = Date().addingTimeInterval(delay)
        let op = DelayOperation(until: date)

        let then = Date()
        keyValueObservingExpectation(for: op, keyPath: "isFinished") { op, _ in
            if let op = op as? Foundation.Operation {
                return op.isFinished
            }

            return false
        }

        ANOperationQueue().addOperation(op)

        waitForExpectations(timeout: delay + 1) { _ in
            let now = Date()
            let diff = now.timeIntervalSince(then)
            XCTAssertTrue(diff >= delay, "Didn't delay long enough")
        }
    }

    func testMutualExclusion() {
        enum Test {}
        typealias TestMutualExclusion = MutuallyExclusive<Test>
        let cond = MutuallyExclusive<TestMutualExclusion>()

        var running = false

        let exp = expectation(description: "op2")

        let op = ANBlockOperation {
            running = true
            exp.fulfill()
        }
        op.addCondition(cond)

        let opQ = ANOperationQueue()
        opQ.maxConcurrentOperationCount = 2

        let delayOp = DelayOperation(interval: 0.1)

        delayOp.addCondition(cond)

        keyValueObservingExpectation(for: delayOp, keyPath: "isFinished") { op, _ in
            XCTAssertFalse(running, "op should not yet have started execution")

            if let op = op as? Foundation.Operation {
                return op.isFinished
            }

            return true
        }

        opQ.addOperation(delayOp)
        opQ.addOperation(op)

        waitForExpectations(timeout: 0.9, handler: nil)
    }

    func testConditionObserversCalled() {
        let startExp = expectation(description: "startExp")
        let cancelExp = expectation(description: "cancelExp")
        let finishExp = expectation(description: "finishExp")
        let produceExp = expectation(description: "produceExp")

        var op: ANBlockOperation!
        op = ANBlockOperation {
            op.produceOperation(ANBlockOperation(mainQueueBlock: {}))
            op.cancel()
        }
        op.addObserver(BlockObserver(
            startHandler: { _ in
                startExp.fulfill()
            },
            cancelHandler: { _ in
                cancelExp.fulfill()
            },
            produceHandler: { _, _ in
                produceExp.fulfill()
            },
            finishHandler: { _, _ in
                finishExp.fulfill()
            }
        ))

        let q = ANOperationQueue()
        q.addOperation(op)

        waitForExpectations(timeout: 5.0, handler: nil)
    }

    func testSilentCondition_failure() {
        var testCondition = TestCondition()

        testCondition.dependencyOperation = ANBlockOperation {
            XCTFail("should not run")
        }

        let exp = expectation(description: "")

        testCondition.conditionBlock = {
            exp.fulfill()
            return false
        }

        let silentCondition = SilentCondition(condition: testCondition)

        let opQ = ANOperationQueue()

        let operation = ANBlockOperation {
            XCTFail("should not run")
        }

        operation.addCondition(silentCondition)

        keyValueObservingExpectation(for: operation, keyPath: "isCancelled") { op, _ in
            if let op = op as? Foundation.Operation {
                return op.isCancelled
            }

            return false
        }

        opQ.addOperation(operation)

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    func testNegateCondition_failure() {
        let operation = ANBlockOperation {
            XCTFail("shouldn't run")
        }

        var testCondition = TestCondition()
        testCondition.conditionBlock = { true }

        let negateCondition = NegatedCondition(condition: testCondition)

        operation.addCondition(negateCondition)

        keyValueObservingExpectation(for: operation, keyPath: "isCancelled") { op, _ in
            if let op = op as? Foundation.Operation {
                return op.isCancelled
            }

            return false
        }

        let opQ = ANOperationQueue()

        opQ.addOperation(operation)

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    func testNegateCondition_success() {
        let exp = expectation(description: "")

        let operation = ANBlockOperation {
            exp.fulfill()
        }

        var testCondition = TestCondition()
        testCondition.conditionBlock = { false }

        let negateCondition = NegatedCondition(condition: testCondition)

        operation.addCondition(negateCondition)

        let opQ = ANOperationQueue()

        opQ.addOperation(operation)

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    func testNoCancelledDepsCondition_aDepCancels() {
        let dependencyOperation = ANBlockOperation {}
        let operation = ANBlockOperation {
            XCTFail("shouldn't run")
        }

        let noCancelledCondition = NoCancelledDependencies()
        operation.addCondition(noCancelledCondition)

        operation.addDependency(dependencyOperation)

        keyValueObservingExpectation(for: dependencyOperation, keyPath: "isCancelled") { op, _ in
            if let op = op as? Foundation.Operation {
                return op.isCancelled
            }

            return false
        }

        keyValueObservingExpectation(for: operation, keyPath: "isCancelled") { op, _ in
            if let op = op as? Foundation.Operation {
                return op.isCancelled
            }

            return false
        }

        let opQ = ANOperationQueue()

        keyValueObservingExpectation(for: opQ, keyPath: "operationCount") { opQ, _ in
            if let opQ = opQ as? Foundation.OperationQueue {
                return opQ.operationCount == 0
            }

            return false
        }

        opQ.addOperation(operation)
        opQ.addOperation(dependencyOperation)
        dependencyOperation.cancel()

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    func testOperationRunsEvenIfDepCancels() {
        let dependencyOperation = ANBlockOperation {}

        let exp = expectation(description: "")

        let operation = ANBlockOperation {
            exp.fulfill()
        }

        operation.addDependency(dependencyOperation)

        keyValueObservingExpectation(for: dependencyOperation, keyPath: "isCancelled") { op, _ in
            if let op = op as? Foundation.Operation {
                return op.isCancelled
            }

            return false
        }

        let opQ = ANOperationQueue()

        opQ.addOperation(operation)
        opQ.addOperation(dependencyOperation)
        dependencyOperation.cancel()

        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testCancelledOperationLeavesQueue() {
        let operation = ANBlockOperation {}
        let operation2 = Foundation.BlockOperation {}

        keyValueObservingExpectation(for: operation, keyPath: "isCancelled") { op, _ in
            if let op = op as? Foundation.Operation {
                return op.isCancelled
            }

            return false
        }

        let opQ = ANOperationQueue()
        opQ.maxConcurrentOperationCount = 1
        opQ.isSuspended = true

        keyValueObservingExpectation(for: opQ, keyPath: "operationCount", expectedValue: 0)

        opQ.addOperation(operation)
        opQ.addOperation(operation2)
        operation.cancel()

        opQ.isSuspended = false

        waitForExpectations(timeout: 2.0, handler: nil)
    }

//    This test exhibits odd behavior that needs to be investigated at some point.
//    It seems to be related to setting the maxConcurrentOperationCount to 1 so
//    I don't believe it is critical
//    func testCancelledOperationLeavesQueue() {
//
//        let operation = ANBlockOperation { }
//
//        let exp = expectation(description: "")
//
//        let operation2 = ANBlockOperation {
//            exp.fulfill()
//        }
//
//        keyValueObservingExpectation(for: operation, keyPath: "isCancelled") {
//            (op, changes) -> Bool in
//
//            if let op = op as? Foundation.Operation {
//                return op.isCancelled
//            }
//
//            return false
//        }
//
//
//        let opQ = ANOperationQueue()
//        opQ.maxConcurrentOperationCount = 1
//
//        opQ.addOperation(operation)
//        opQ.addOperation(operation2)
//        operation.cancel()
//
//        waitForExpectations(timeout: 1, handler: nil)
//    }

    func testCancelOperation_cancelBeforeStart() {
        let operation = ANBlockOperation {
            XCTFail("This should not run")
        }

        keyValueObservingExpectation(for: operation, keyPath: "isFinished") { op, _ -> Bool in
            if let op = op as? Foundation.Operation {
                return op.isFinished
            }

            return false
        }

        let opQ = ANOperationQueue()
        opQ.isSuspended = true
        opQ.addOperation(operation)
        operation.cancel()
        opQ.isSuspended = false

        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertTrue(operation.isCancelled, "")
            XCTAssertTrue(operation.isFinished, "")
        }
    }

    func testCancelOperation_cancelAfterStart() {
        let exp = expectation(description: "")

        var operation: ANBlockOperation?
        operation = ANBlockOperation {
            operation?.cancel()
            exp.fulfill()
        }

        let opQ = ANOperationQueue()

        opQ.addOperation(operation!)

        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertEqual(opQ.operationCount, 0, "")
        }
    }

    func testBlockObserver() {
        let opQ = ANOperationQueue()

        var op: ANBlockOperation!
        op = ANBlockOperation {
            let producedOperation = ANBlockOperation {}
            op.produceOperation(producedOperation)
        }

        let exp1 = expectation(description: "1")
        let exp2 = expectation(description: "2")
        let exp3 = expectation(description: "3")

        let blockObserver = BlockObserver(
            startHandler: { _ in
                exp1.fulfill()
            },
            produceHandler: { _, _ in
                exp2.fulfill()
            },
            finishHandler: { _, _ in
                exp3.fulfill()
            }
        )

        op.addObserver(blockObserver)

        opQ.addOperation(op)

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    func testTimeoutObserver() {
        let delayOperation = DelayOperation(interval: 1)
        let timeoutObserver = TimeoutObserver(timeout: 0.1)

        delayOperation.addObserver(timeoutObserver)

        let opQ = ANOperationQueue()

        keyValueObservingExpectation(for: delayOperation, keyPath: "isCancelled") { op, _ in
            if let op = op as? Foundation.Operation {
                return op.isCancelled
            }

            return false
        }

        opQ.addOperation(delayOperation)

        waitForExpectations(timeout: 0.9, handler: nil)
    }

    func testNoCancelledDepsCondition_aDepCancels_inGroupOperation() {
        var dependencyOperation: ANBlockOperation!
        dependencyOperation = ANBlockOperation {
            dependencyOperation.cancel()
        }

        let operation = ANBlockOperation {
            XCTFail("shouldn't run")
        }

        let noCancelledCondition = NoCancelledDependencies()
        operation.addCondition(noCancelledCondition)
        operation.addDependency(dependencyOperation)

        let groupOp = GroupOperation(operations: [dependencyOperation, operation])

        keyValueObservingExpectation(for: dependencyOperation!, keyPath: "isCancelled") { op, _ in
            if let op = op as? Foundation.Operation {
                return op.isCancelled
            }

            return false
        }

        keyValueObservingExpectation(for: operation, keyPath: "isCancelled") { op, _ in
            if let op = op as? Foundation.Operation {
                return op.isCancelled
            }

            return false
        }

        keyValueObservingExpectation(for: groupOp, keyPath: "isFinished") { op, _ in
            if let op = op as? Foundation.Operation {
                return op.isFinished
            }

            return false
        }

        let opQ = ANOperationQueue()
        opQ.addOperation(groupOp)

        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertEqual(opQ.operationCount, 0, "")
        }
    }

    func testOperationCompletionBlock() {
        let executingExpectation = expectation(description: "block")
        let completionExpectation = expectation(description: "completion")

        let opQueue = ANOperationQueue()

        let op = Foundation.BlockOperation { () -> Void in
            executingExpectation.fulfill()
        }

        op.completionBlock = {
            completionExpectation.fulfill()
        }

        opQueue.addOperation(op)

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    func testBlockOperationCanBeCancelledWhileExecuting() {
        let exp = expectation(description: "")

        var blockOperation: ANBlockOperation!
        blockOperation = ANBlockOperation {
            XCTAssertFalse(blockOperation.isFinished)
            blockOperation.cancel()
            exp.fulfill()
        }

        let q = ANOperationQueue()
        q.addOperation(blockOperation)

        keyValueObservingExpectation(for: blockOperation!, keyPath: "isCancelled") { op, _ in
            guard let op = op as? Foundation.Operation else { return false }
            return op.isCancelled
        }

        waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testDelayOperationIsCancellableAndNotFinishedTillDelayTime() {
        let exp = expectation(description: "")

        let delayOp = DelayOperation(interval: 2)
        let blockOp = ANBlockOperation {
            XCTAssertFalse(delayOp.isFinished)
            delayOp.cancel()
            exp.fulfill()
        }

        let q = ANOperationQueue()

        q.addOperation(delayOp)
        q.addOperation(blockOp)

        keyValueObservingExpectation(for: delayOp, keyPath: "isCancelled") { op, _ in
            guard let op = op as? Foundation.Operation else { return false }

            return op.isCancelled
        }

        waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testConcurrentOpsWithBlockingOp() {
        let exp = expectation(description: "")

        let delayOp = DelayOperation(interval: 4)
        let blockOp = ANBlockOperation {
            exp.fulfill()
        }

        let timeout = TimeoutObserver(timeout: 2)
        blockOp.addObserver(timeout)

        let q = ANOperationQueue()

        q.addOperation(delayOp)
        q.addOperation(blockOp)

        keyValueObservingExpectation(for: q, keyPath: "operationCount") { opQ, _ in
            if let opQ = opQ as? Foundation.OperationQueue, opQ.operationCount == 1 {
                if let op = opQ.operations.first, op is DelayOperation {
                    return true
                }
            }

            return false
        }

        waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testMoveFromPendingToFinishingByWayOfCancelAfterEnteringQueue() {
        let op = ANOperation()
        let delay = DelayOperation(interval: 0.1)
        op.addDependency(delay)

        let q = ANOperationQueue()

        q.addOperation(op)
        q.addOperation(delay)
        op.cancel()

        keyValueObservingExpectation(for: q, keyPath: "operationCount") { opQ, _ in
            if let opQ = opQ as? Foundation.OperationQueue, opQ.operationCount == 0 {
                return true
            }

            return false
        }

        waitForExpectations(timeout: 0.5, handler: nil)
    }

    /* I'm not sure what this test is testing and the Foundation waitUntilFinished is being fickle
     func testOperationQueueWaitUntilFinished() {
         let opQ = ANOperationQueue()

         class WaitOp : Foundation.Operation {

             var waitCalled = false

             override func waitUntilFinished() {
                 waitCalled = true
                 super.waitUntilFinished()
             }
         }

         let op = WaitOp()

         opQ.addOperations([op], waitUntilFinished: true)

         XCTAssertEqual(0, opQ.operationCount)
         XCTAssertTrue(op.waitCalled)
     }
     */

    /*
     In 9.1 (at least) we found that occasionaly OperationQueue would get stuck on an operation
     The operation would be ready, not finished, not cancelled, and have no dependencies. The queue
     would have no other operations, but the op still would not execute. We determined a few problems
     that could cause this issue to occur. This test was used to invoke the problem repeatedly. While we've
     seen the opCount surpass 100,000 easily we figured 25_000 operations executing one right after the other was
     a sufficient test and is still probably beyond typical use cases. We wish it could be more concrete, but it is not.
     */
    func testOperationQueueNotGettingStuck() {
        var opCount = 0
        var requiredToPassCount = 5000
        let q = ANOperationQueue()

        let exp = expectation(description: "requiredToPassCount")

        func go() {
            if opCount >= requiredToPassCount {
                exp.fulfill()
                return
            }

            let blockOp = ANBlockOperation { finishBlock in
                finishBlock()
                go()
            }

            // because of a change in evaluateConditions, this issue would only happen
            // if the op had a condition. NoCancelledDependcies is an easy condition to
            // use for this test.
            let noc = NoCancelledDependencies()
            blockOp.addCondition(noc)

            opCount += 1

            q.addOperation(blockOp)
        }

        go()

        waitForExpectations(timeout: 15) { _ in
            // if opCount != requiredToPassCount, the queue is frozen
            XCTAssertEqual(opCount, requiredToPassCount)
        }
    }

    func testOperationDidStartWhenSetMaxConcurrencyCountOnTheQueue() {
        let opQueue = ANOperationQueue()
        opQueue.maxConcurrentOperationCount = 1

        let exp1 = expectation(description: "1")
        let exp2 = expectation(description: "2")
        let exp3 = expectation(description: "3")

        let op1 = ANBlockOperation {
            exp1.fulfill()
        }
        let op2 = ANBlockOperation {
            exp2.fulfill()
        }
        let op3 = ANBlockOperation {
            exp3.fulfill()
        }

        opQueue.addOperation(op1)
        opQueue.addOperation(op2)
        opQueue.addOperation(op3)

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    func testOperationFinishedWithErrors() {
        let opQ = ANOperationQueue()

        class ErrorOp: ANOperation {
            let sema = DispatchSemaphore(value: 0)

            override func execute() {
                finishWithError(NSError(domain: "test-domain", code: 1, userInfo: nil) as Error)
            }

            override func finished(_ errors: [Error]) {
                sema.signal()
            }

            override func waitUntilFinished() {
                _ = sema.wait(timeout: DispatchTime.distantFuture)
            }
        }

        let op = ErrorOp()

        opQ.addOperations([op], waitUntilFinished: true)

        XCTAssert(op.errors.count == 1)
        XCTAssertEqual((op.errors.first! as NSError).code, 1)
    }

    func testOperationCancelledWithErrors() {
        let opQ = ANOperationQueue()

        class ErrorOp: ANOperation {
            let sema = DispatchSemaphore(value: 0)

            override func execute() {
                cancelWithError(NSError(domain: "test-domain", code: 1, userInfo: nil))
            }

            override func finished(_ errors: [Error]) {
                sema.signal()
            }

            override func waitUntilFinished() {
                _ = sema.wait(timeout: DispatchTime.distantFuture)
            }
        }

        let op = ErrorOp()

        opQ.addOperations([op], waitUntilFinished: true)

        XCTAssert(op.errors.count == 1)
        XCTAssertEqual((op.errors.first! as NSError).code, 1)
    }
}
