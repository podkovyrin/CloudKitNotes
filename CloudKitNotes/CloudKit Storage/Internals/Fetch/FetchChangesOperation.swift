//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Andrew Podkovyrin. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import ANOperations
import CloudKit
import Foundation

class FetchChangesOperation: BaseCloudKitGroupOperation {
    private(set) var failed: Bool = true
    private(set) var zoneWasDeleted: Bool?
    private(set) var hasNewData = false

    var processChanges: ((_ changedRecords: [CKRecord], _ deletedRecordIDs: [CKRecord.ID]) -> Void)? {
        get { fetchZoneChangesOperation.processChanges }
        set { fetchZoneChangesOperation.processChanges = newValue }
    }

    private let zoneID: CKRecordZone.ID
    private let fetchDatabaseChangesOperation: FetchDatabaseChangesOperation
    private let fetchZoneChangesOperation: FetchZoneChangesOperation

    init(configuration: CloudKitOperationConfiguration, zoneID: CKRecordZone.ID) {
        self.zoneID = zoneID

        fetchDatabaseChangesOperation = FetchDatabaseChangesOperation(configuration: configuration, zoneID: zoneID)
        fetchZoneChangesOperation = FetchZoneChangesOperation(configuration: configuration, zoneID: zoneID)
        fetchZoneChangesOperation.addDependency(fetchDatabaseChangesOperation)

        super.init(configuration: configuration,
                   operations: [fetchDatabaseChangesOperation, fetchZoneChangesOperation])
    }

    override func cancel() {
        fetchDatabaseChangesOperation.cancel()
        fetchZoneChangesOperation.cancel()
        super.cancel()
    }

    override func operationDidFinish(_ operation: Operation, withErrors errors: [Error]) {
        guard !isCancelled else { return }

        if operation === fetchDatabaseChangesOperation {
            zoneWasDeleted = fetchDatabaseChangesOperation.zoneWasDeleted

            // if there was changes we need to allow `fetchZoneChangesOperation` to fetch them
            if let zoneWasChanged = fetchDatabaseChangesOperation.zoneWasChanged {
                fetchZoneChangesOperation.zoneHasChanges = zoneWasChanged
            }

            failed = !errors.isEmpty
        }
        else if operation === fetchZoneChangesOperation {
            hasNewData = fetchZoneChangesOperation.hasNewData

            failed = failed || !errors.isEmpty
        }
    }
}
