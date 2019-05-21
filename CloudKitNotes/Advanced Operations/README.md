# ANOperations

Fork of [PSOperations](https://github.com/pluralsight/PSOperations) framework that extends NSOperation/NSOperationQueue classes.
Based on code provided in the [Advanced NSOperations](https://developer.apple.com/videos/wwdc/2015/?id=226) session of WWDC 2015.

## Differences from the upstream

- Swift 5 compatible
- Refactored to be closer to original Apple's implementation
- `NSError` replaced with `Error`
- Revised `OperationError`
- `Capability` abstraction refactored back to condition
- Added convenient `CompletionObserver`
- Fixed `CloudContainerCondition`

## License

ANOperations is available under the Apache 2.0 license. See LICENSE_PSOperations.txt and LICENSE_Apple.txt files for more info.
