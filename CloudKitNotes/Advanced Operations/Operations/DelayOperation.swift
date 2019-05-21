//
//  Copyright (C) 2015 Apple Inc. All Rights Reserved.
//  See LICENSE.txt for this sample’s licensing information
//
//  Abstract:
//  This file shows how to make an operation that efficiently waits.
//

import Foundation

/**
 `DelayOperation` is an `ANOperation` that will simply wait for a given time
 interval, or until a specific `NSDate`.

 It is important to note that this operation does **not** use the `sleep()`
 function, since that is inefficient and blocks the thread on which it is called.
 Instead, this operation uses `dispatch_after` to know when the appropriate amount
 of time has passed.

 If the interval is negative, or the `NSDate` is in the past, then this operation
 immediately finishes.
 */
class DelayOperation: ANOperation {
    // MARK: Types

    private enum Delay {
        case interval(TimeInterval)
        case date(Date)
    }

    // MARK: Properties

    private let delay: Delay

    // MARK: Initialization

    init(interval: TimeInterval) {
        delay = .interval(interval)
        super.init()
    }

    init(until date: Date) {
        delay = .date(date)
        super.init()
    }

    override func execute() {
        let interval: TimeInterval

        // Figure out how long we should wait for.
        switch delay {
        case let .interval(theInterval):
            interval = theInterval
        case let .date(date):
            interval = date.timeIntervalSinceNow
        }

        guard interval > 0 else {
            finish()
            return
        }

        let when = DispatchTime.now() + interval
        DispatchQueue.global(qos: .init(qos: qualityOfService)).asyncAfter(deadline: when) { [weak self] in
            self?.finish()
        }
    }
}
