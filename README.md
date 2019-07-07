

# CloudKitNotes

Real-world CloudKit usage example.

This app shows how to backup a simple object to CloudKit and handle all possible errors. CloudKitNotes started as a playground for testing CloudKit backup functionality for my upcoming app.  The idea behind is a dead-simple: allow the user to backup list of their private `Note`s which is Swift struct:

```swift
struct Note {
    var id: String 
    var text: String
    var modified: Date
}
```

This example covers the following aspects of CloudKit:
- Seamless synchronization process
- Private CloudKit database usage
- Silent push notifications to consume as less traffic as possible
- Keeping data up to date regardless of disabled or undelivered push notifications
- Handling all possible errors that might happen during synchronization (with minimal user interaction)
- Allows user to enable or disable backup at any time
- Respects user's privacy by deleting all data from iCloud when they want to disable backup

Out of scope of this example project:
- Public and shared database usage
- Relationships between `CKRecord`s
- Assets
- Queries

Unfortunately, it's almost impossible to write unit tests around CloudKit functionality so this app was tested manually by [several people](#special-thanks).

## Requirements

- Apple Developer Account
- [CocoaPods](https://cocoapods.org)
- Xcode ≥ 10.2 (Swift 5.0 is used)

## Running

To run the project, clone the repo, and run `pod install` from the root directory first.
Update Bundle ID to any new unique Bundle ID and let Xcode fix the signing issues.

## How it works

CloudKitNotes heavily uses [Advanced NSOperations](https://developer.apple.com/videos/play/wwdc2015/226/) technique as recommended in the ["CloudKit Tips and Tricks"](https://developer.apple.com/videos/play/wwdc2015/715/) WWDC session. It uses its own fork of [PSOperations](https://github.com/pluralsight/PSOperations) – [ANOperations](https://github.com/podkovyrin/CloudKitNotes/tree/master/CloudKitNotes/Advanced%20Operations).

### Starting CloudKit

From the user perspective backup should be enabled manually or on demand. We ask the user whether their wants to enable iCloud backup after adding the first note.

Very first start of CloudKit syncing:
<p align="center">
<img src="https://github.com/podkovyrin/CloudKitNotes/blob/master/assets/ck_first_start.png?raw=true" alt="First CloudKit Start Diagram">
</p>

All other subsequent starts of CloudKit syncing:
<p align="center">
<img src="https://github.com/podkovyrin/CloudKitNotes/blob/master/assets/ck_regular_start.png?raw=true" alt="Regular CloudKit Start Diagram">
</p>

### Architecture

CloudKitNotes encapsulates `CKOperation`s into its own high level operations.
<p align="center">
<img src="https://github.com/podkovyrin/CloudKitNotes/blob/master/assets/ck_classes.png?raw=true" alt="CloudKitNotes Class Diagram">
</p>

## [CKError](https://developer.apple.com/documentation/cloudkit/ckerror) breakdown

This is a basic classification of different CKError codes. 

| Code | Raw Code | User Action Needed | Can I handle it? | Can retry? | Should happen only during development |
|--------------------------------|:--------:|:-:|:---:|:---:|:-------------------------------------:|
| internalError | 1 | ❌ | ❌ | ❌ |  |
| partialFailure | 2 | ❌ | ✅ | ❌ |  |
| networkUnavailable | 3 | ❌ | ✅ | ✅ |  |
| networkFailure | 4 | ❌ | ✅ | ✅ |  |
| badContainer | 5 | ❌ | ❌ | ❌ | ✅ |
| serviceUnavailable | 6 | ❌ | ✅ | ✅ |  |
| requestRateLimited | 7 | ❌ | ✅ | ✅ |  |
| missingEntitlement | 8 | ❌ | ❌ | ❌ | ✅ |
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

\* ⚠️ == It depends (It is up to your app how to handle those errors)

Basically, you are able (*must*) handle most of errors however with some of them nothing you can do about it.  Just keep in mind that every CloudKit request might return any error and your code should be prepared to fail for an *unknown* reason.

While handling retriable operations your app should implement a backoff timer or retry count logic so that it doesn't attempt the same operation repeatedly.

That's how CloudKitNotes handles global errors: [CloudKitErrorHandler.swift](https://github.com/podkovyrin/CloudKitNotes/blob/master/CloudKitNotes/CloudKit%20Storage/Internals/CloudKitErrorHandler.swift)

## Special thanks

Special thanks to [@k06a](https://github.com/k06a) and others who helped to manually test this app.

## Author

Andrew Podkovyrin, podkovyrin@gmail.com

## Contribution

Feel free to open [new issue](https://github.com/podkovyrin/CloudKitNotes/issues/new) or send a pull request.

## License

CloudNotes is available under the MIT license. See the LICENSE file for more info.
