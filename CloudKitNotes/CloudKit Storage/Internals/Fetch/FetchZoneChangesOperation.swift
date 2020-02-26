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

// swiftlint:disable function_body_length

/// Supports fetching changes from single zone
/// To enable multiple zone fetching store change token per each zone instead of `previousZoneChangeToken`
class FetchZoneChangesOperation: BaseCloudKitOperation {
    var zoneHasChanges = false
    private(set) var hasNewData = false

    var processChanges: ((_ changedRecords: [CKRecord], _ deletedRecordIDs: [CKRecord.ID]) -> Void)?

    private let zoneID: CKRecordZone.ID
    private let userDefaults: UserDefaults
    private weak var operation: CKOperation?

    init(configuration: CloudKitOperationConfiguration, zoneID: CKRecordZone.ID) {
        userDefaults = configuration.userDefaults
        self.zoneID = zoneID

        // conditions will be checked in the parent FetchChangesOperation
        super.init(configuration: configuration, enableDefaultConditions: false)
    }

    override func execute() {
        guard zoneHasChanges else {
            finish()

            return
        }

        fetchZoneChanges(zoneID: zoneID) { [weak self] error in
            guard let self = self else { return }

            self.finishWithError(error)
        }
    }

    override func cancel() {
        operation?.cancel()
        super.cancel()
    }

    // MARK: Private

    private func fetchZoneChanges(zoneID: CKRecordZone.ID, completion: @escaping (Error?) -> Void) {
        var isChangeTokenExpired = false
        var changedRecords = [CKRecord]()
        var deletedRecordIDs = [CKRecord.ID]()

        let changeToken = userDefaults.previousZoneChangeToken

        let operation: CKFetchRecordZoneChangesOperation
        if #available(iOS 12.0, *) {
            let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            options.previousServerChangeToken = changeToken
            let configurations = [zoneID: options]
            operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID],
                                                          configurationsByRecordZoneID: configurations)
        }
        else {
            let options = CKFetchRecordZoneChangesOperation.ZoneOptions()
            options.previousServerChangeToken = changeToken
            let configurations = [zoneID: options]
            operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID],
                                                          optionsByRecordZoneID: configurations)
        }

        operation.recordChangedBlock = { record in
            changedRecords.append(record)
        }

        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            deletedRecordIDs.append(recordID)
        }

        operation.recordZoneFetchCompletionBlock = { [weak self] _, changeToken, _, _, error in
            guard let self = self, !self.isCancelled else { return }

            if let error = error as? CKError, error.code == .changeTokenExpired {
                isChangeTokenExpired = true

                cksLog("Failed to fetch zone changes: \(error)")
                return
            }

            self.userDefaults.previousZoneChangeToken = changeToken

            cksLog("> Received \(changedRecords.count) records to save, \(deletedRecordIDs.count) records to delete")

            // the record changes here are valid
            // even if there is a subsequent `operationError` in `fetchRecordZoneChangesCompletionBlock`
            self.hasNewData = self.hasNewData || !changedRecords.isEmpty || !deletedRecordIDs.isEmpty

            assert(self.processChanges != nil, "`processChanges` should be set otherwise operation is meaningless")
            if let processChanges = self.processChanges {
                DispatchQueue.main.async {
                    processChanges(changedRecords, deletedRecordIDs)
                }
            }
        }

        operation.fetchRecordZoneChangesCompletionBlock = { [weak self] error in
            guard let self = self, !self.isCancelled else { return }

            if let error = error {
                cksLog("Failed to fetch zone changes: \(error)")
            }

            if isChangeTokenExpired {
                cksLog("Invalidating zone token...")
                self.userDefaults.previousZoneChangeToken = nil
                self.fetchZoneChanges(zoneID: zoneID, completion: completion)
            }
            else {
                let retrying = CloudKitErrorHandler.retryIfPossible(with: error,
                                                                    retryCount: self.retryCount) { [weak self] in
                    self?.fetchZoneChanges(zoneID: zoneID, completion: completion)
                }

                if retrying {
                    self.retryCount += 1
                }
                else {
                    completion(error)
                }
            }
        }

        database.add(operation)
        self.operation = operation
    }
}
