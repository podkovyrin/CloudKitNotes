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

import CloudKit
import Foundation

class ModifyZonesOperation: BaseCloudKitOperation {
    /// Used by subclasses to check if zone operation needs to be executed
    var shouldExecuteOperation: Bool { true }

    private let zoneIDToSave: CKRecordZone.ID?
    private let zoneIDToDelete: CKRecordZone.ID?
    private weak var operation: CKOperation?

    init(configuration: CloudKitOperationConfiguration,
         zoneIDToSave: CKRecordZone.ID?,
         zoneIDToDelete: CKRecordZone.ID?,
         enableDefaultConditions: Bool = true) {
        self.zoneIDToSave = zoneIDToSave
        self.zoneIDToDelete = zoneIDToDelete

        super.init(configuration: configuration, enableDefaultConditions: enableDefaultConditions)
    }

    override func execute() {
        guard shouldExecuteOperation else {
            finish()

            return
        }

        modifyZones(zoneIDToSave: zoneIDToSave, zoneIDToDelete: zoneIDToDelete) { [weak self] error in
            guard let self = self else { return }
            self.finishWithError(error)
        }
    }

    override func cancel() {
        operation?.cancel()
        super.cancel()
    }

    // MARK: Private

    private func modifyZones(zoneIDToSave: CKRecordZone.ID?,
                             zoneIDToDelete: CKRecordZone.ID?,
                             completion: @escaping (Error?) -> Void) {
        var zonesToSave: [CKRecordZone]?
        if let zoneIDToSave = zoneIDToSave {
            zonesToSave = [CKRecordZone(zoneID: zoneIDToSave)]
        }
        var zoneIDsToDelete: [CKRecordZone.ID]?
        if let zoneIDToDelete = zoneIDToDelete {
            zoneIDsToDelete = [zoneIDToDelete]
        }
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: zonesToSave,
                                                     recordZoneIDsToDelete: zoneIDsToDelete)

        // As creating/deleting zone is basically turning CloudKit syncing on or off,
        // we'd like to show user the result of their action
        // Setting qualityOfService to userInitiated allows us to fail without internal retries
        // to show a result to the user asap
        let configuration = CKOperation.Configuration()
        configuration.qualityOfService = .userInitiated
        operation.configuration = configuration

        operation.modifyRecordZonesCompletionBlock = { [weak self] _, _, error in
            guard let self = self, !self.isCancelled else { return }

            if let error = error {
                cksLog("Failed to modify zones: \(error)")
            }

            let retrying = CloudKitErrorHandler.retryIfPossible(with: error,
                                                                retryCount: self.retryCount) { [weak self] in
                self?.modifyZones(zoneIDToSave: zoneIDToSave,
                                  zoneIDToDelete: zoneIDToDelete,
                                  completion: completion)
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
