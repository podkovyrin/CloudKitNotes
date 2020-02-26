//
//  CreateZoneOperation.swift
//  CloudKitNotes
//
//  Created by Andrew Podkovyrin on 11/05/2019.
//  Copyright © 2019 AP. All rights reserved.
//

import CloudKit
import Foundation

class CreateZoneOperation: ModifyZonesOperation {
    private(set) var shouldSyncLocalData: Bool?

    private let userDefaults: UserDefaults

    init(configuration: CloudKitOperationConfiguration, zoneID: CKRecordZone.ID) {
        userDefaults = configuration.userDefaults

        // conditions will be checked in the parent SetupCloudKitOperation
        super.init(configuration: configuration,
                   zoneIDToSave: zoneID,
                   zoneIDToDelete: nil,
                   enableDefaultConditions: false)
    }

    override var shouldExecuteOperation: Bool {
        !userDefaults.createdCustomZone
    }

    override func finished(_ errors: [Error]) {
        if userDefaults.createdCustomZone {
            shouldSyncLocalData = false
        }
        else {
            let success = errors.isEmpty
            userDefaults.createdCustomZone = success

            if success {
                shouldSyncLocalData = true
            }
        }
    }
}
