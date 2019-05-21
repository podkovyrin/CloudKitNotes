//
//  SetupCloudKitOperation.swift
//  CloudKitNotes
//
//  Created by Andrew Podkovyrin on 12/05/2019.
//  Copyright © 2019 AP. All rights reserved.
//

import CloudKit
import Foundation

class SetupCloudKitOperation: BaseCloudKitGroupOperation {
    private(set) var error: Error?
    private(set) var shouldSyncLocalData: Bool?

    private let createZoneOperation: CreateZoneOperation
    private let subscribeOperation: SubscribeOperation

    init(configuration: CloudKitOperationConfiguration,
         zoneID: CKRecordZone.ID,
         subscriptionID: CKSubscription.ID) {
        createZoneOperation = CreateZoneOperation(configuration: configuration, zoneID: zoneID)
        subscribeOperation = SubscribeOperation(configuration: configuration, subscriptionID: subscriptionID)

        super.init(configuration: configuration, operations: [createZoneOperation, subscribeOperation])
    }

    override func cancel() {
        createZoneOperation.cancel()
        subscribeOperation.cancel()
        super.cancel()
    }

    override func operationDidFinish(_ operation: Operation, withErrors errors: [Error]) {
        guard !isCancelled else { return }

        // Fail only if CreateZoneOperation fails
        // It's fine if SubscribeOperation fails it will be re-run on the next launch
        if operation === createZoneOperation {
            error = errors.first
            shouldSyncLocalData = createZoneOperation.shouldSyncLocalData
        }
    }
}
