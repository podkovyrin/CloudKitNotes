
# CloudKitNotes


## Requirements

- Apple Developer Account
- [CocoaPods](https://cocoapods.org)
- Xcode 10.2

## Running

To run the project, clone the repo, and run `pod install` from the root directory first.
Update Bundle ID (TF.CloudNotes) to any new unique Bundle ID and let Xcode fix the signing issues.

## [CKError](https://developer.apple.com/documentation/cloudkit/ckerror) description

| Code | Raw Code | User Action Needed | Can I handle it? | Can retry? | Should happen only during development |
|--------------------------------|:--------:|:------------------:|:----------------:|:----------:|:-------------------------------------:|
| internalError | 1 | ❌ | ❌ | ❌ |  |
| partialFailure | 2 | ❌ | ✅ | ❌ |  |
| networkUnavailable | 3 | ❌ | ✅ | ✅ |  |
| networkFailure | 4 | ❌ | ✅ | ✅ |  |
| badContainer | 5 | ❌ | ❌ | ❌ | ✅ |
| serviceUnavailable | 6 | ❌ | ✅ | ✅ |  |
| requestRateLimited | 7 | ❌ | ✅ | ✅ |  |
| missingEntitlement | 8 | ❌ | ✅ | ❌ | ✅ |
| notAuthenticated | 9 | ✅ | ❌ | ❌ |  |
| permissionFailure | 10 | ✅ | ❌ | ❌ |  |
| unknownItem | 11 | ❌ | ❌ | ❌ |  |
| invalidArguments | 12 | ❌ | ✅ | ❌ |  |
| resultsTruncated | 13 | ❌ | ✅ | ❌ |  |
| serverRecordChanged | 14 | ❌ | ✅ | ❌ |  |
| serverRejectedRequest | 15 | ❌ | ⚠️ | ⚠️ |  |
| assetFileNotFound | 16 | ❌ | ✅ | ⚠️ |  |
| assetFileModified | 17 | ❌ | ⚠️ | ❌ |  |
| incompatibleVersion | 18 | ✅ | ❌ | ❌ |  |
| constraintViolation | 19 | ❌ | ⚠️ | ❌ |  |
| operationCancelled | 20 | ❌ | ✅ | ✅ |  |
| changeTokenExpired | 21 | ❌ | ✅ | ❌ |  |
| batchRequestFailed | 22 | ❌ | ✅ | ❌ |  |
| zoneBusy | 23 | ❌ | ✅ | ✅ |  |
| badDatabase | 24 | ❌ | ✅ | ❌ |  |
| quotaExceeded | 25 | ⚠️ | ⚠️ | ❌ |  |
| zoneNotFound | 26 | ❌ | ✅ | ❌ |  |
| limitExceeded | 27 | ❌ | ✅ | ✅ |  |
| userDeletedZone | 28 | ✅ | ⚠️ | ❌ |  |
| tooManyParticipants | 29 | ❌ | ✅ | ❌ |  |
| alreadyShared | 30 | ❌ | ⚠️ | ❌ |  |
| referenceViolation | 31 | ❌ | ⚠️ | ❌ |  |
| managedAccountRestricted | 32 | ⚠️ | ❌ | ❌ |  |
| participantMayNeedVerification | 33 | ✅ | ✅ | ❌ |  |
| serverResponseLost | 34 | ❌ | ✅ | ✅ |  |
| assetNotAvailable | 35 | ❌ | ✅ | ✅ |  |

\* ⚠️ == It depends

Basically, you are able / must handle most of errors however for some of them nothing you can do about it.  Just keep in mind that every CloudKit request might return any error and your code should be prepared to fail for an *unknown* reason.

While handling retriable operations your app should implement a backoff timer or retry count logic so that it doesn't attempt the same operation repeatedly.

That's how CloudKitNotes handles global errors: [CloudKitErrorHandler.swift](https://github.com/podkovyrin/CloudKitNotes/blob/master/CloudKitNotes/CloudKit%20Storage/Internals/CloudKitErrorHandler.swift)

## Author

Andrew Podkovyrin, podkovyrin@gmail.com

## License

CloudNotes is available under the MIT license. See the LICENSE file for more info.
