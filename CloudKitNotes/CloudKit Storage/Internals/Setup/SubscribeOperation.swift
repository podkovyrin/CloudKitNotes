//
//  SubscribeOperation.swift
//  CloudKitNotes
//
//  Created by Andrew Podkovyrin on 12/05/2019.
//  Copyright © 2019 AP. All rights reserved.
//

import CloudKit
import Foundation

class SubscribeOperation: BaseCloudKitOperation {
    private let userDefaults: UserDefaults
    private let subscriptionID: CKSubscription.ID
    private weak var operation: CKOperation?

    init(configuration: CloudKitOperationConfiguration, subscriptionID: CKSubscription.ID) {
        userDefaults = configuration.userDefaults
        self.subscriptionID = subscriptionID

        // conditions will be checked in the parent SetupCloudKitOperation
        super.init(configuration: configuration, enableDefaultConditions: false)
    }

    override func execute() {
        guard !userDefaults.subscribedToChanges else {
            finish()

            return
        }

        subscribeToChanges(subscriptionID) { [weak self] error in
            guard let self = self else { return }

            self.userDefaults.subscribedToChanges = error == nil
            self.finishWithError(error)
        }
    }

    override func cancel() {
        operation?.cancel()
        super.cancel()
    }

    // MARK: Private

    private func subscribeToChanges(_ subscriptionID: CKSubscription.ID, completion: @escaping (Error?) -> Void) {
        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription],
                                                       subscriptionIDsToDelete: [])

        operation.modifySubscriptionsCompletionBlock = { [weak self] _, _, error in
            guard let self = self, !self.isCancelled else { return }

            if let error = error {
                cksLog("Failed to subscribe to changes: \(error)")
            }

            let retrying = CloudKitErrorHandler.retryIfPossible(with: error,
                                                                retryCount: self.retryCount) { [weak self] in
                self?.subscribeToChanges(subscriptionID, completion: completion)
            }

            if retrying {
                self.retryCount += 1
            }
            else {
                completion(error)
            }
        }

        database.add(operation)
        self.operation = operation
    }
}
