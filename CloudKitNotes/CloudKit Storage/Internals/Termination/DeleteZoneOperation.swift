//
//  DeleteZoneOperation.swift
//  CloudKitNotes
//
//  Created by Andrew Podkovyrin on 13/05/2019.
//  Copyright © 2019 AP. All rights reserved.
//

import CloudKit
import Foundation

class DeleteZoneOperation: ModifyZonesOperation {
    init(configuration: CloudKitOperationConfiguration, zoneID: CKRecordZone.ID) {
        super.init(configuration: configuration,
                   zoneIDToSave: nil,
                   zoneIDToDelete: zoneID,
                   enableDefaultConditions: true)
    }
}
