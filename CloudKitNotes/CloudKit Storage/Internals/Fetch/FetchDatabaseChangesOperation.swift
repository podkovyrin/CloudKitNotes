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

/// Handles only single zone
class FetchDatabaseChangesOperation: BaseCloudKitOperation {
    private(set) var zoneWasDeleted: Bool?
    private(set) var zoneWasChanged: Bool?
    private weak var operation: CKOperation?

    private let zoneID: CKRecordZone.ID
    private let userDefaults: UserDefaults

    init(configuration: CloudKitOperationConfiguration, zoneID: CKRecordZone.ID) {
        userDefaults = configuration.userDefaults
        self.zoneID = zoneID

        // conditions will be checked in the parent FetchChangesOperation
        super.init(configuration: configuration, enableDefaultConditions: false)
    }

    override func execute() {
        fetchDatabaseChanges { [weak self] zoneWasDeleted, changedZoneIDs, error in
            guard let self = self else { return }

            self.zoneWasDeleted = zoneWasDeleted
            self.zoneWasChanged = !changedZoneIDs.isEmpty
            self.finishWithError(error)
        }
    }

    override func cancel() {
        operation?.cancel()
        super.cancel()
    }

    // MARK: Private

    private func fetchDatabaseChanges(completion: @escaping (
        _ zoneWasDeleted: Bool?,
        _ changedZoneIDs: [CKRecordZone.ID],
        _ error: Error?
    ) -> Void) {
        var changedZoneIDs = [CKRecordZone.ID]()
        var zoneWasDeleted = false

        let changeToken = userDefaults.previousDatabaseChangeToken
        let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: changeToken)

        operation.recordZoneWithIDChangedBlock = { [weak self] zoneID in
            guard let self = self, !self.isCancelled else { return }

            assert(zoneID == self.zoneID, "FetchDatabaseChangesOperation supports only single zone")

            // don't fail in Release if you added more zones later
            if zoneID == self.zoneID {
                changedZoneIDs.append(zoneID)
            }
        }

        operation.recordZoneWithIDWasDeletedBlock = { [weak self] zoneID in
            guard let self = self, !self.isCancelled else { return }

            assert(zoneID == self.zoneID, "FetchDatabaseChangesOperation supports only single zone")

            // don't fail in Release if you added more zones later
            if zoneID == self.zoneID {
                zoneWasDeleted = true
            }
        }

        operation.changeTokenUpdatedBlock = { [weak self] token in
            guard let self = self, !self.isCancelled else { return }

            self.userDefaults.previousDatabaseChangeToken = token
        }

        operation.fetchDatabaseChangesCompletionBlock = { [weak self] _, _, error in
            guard let self = self, !self.isCancelled else { return }

            if let error = error {
                cksLog("Failed to fetch database changes: \(error)")

                if let error = error as? CKError, error.code == .changeTokenExpired {
                    cksLog("Invalidating database token...")

                    self.userDefaults.previousDatabaseChangeToken = nil
                    self.fetchDatabaseChanges(completion: completion)

                    return
                }
            }

            let retrying = CloudKitErrorHandler.retryIfPossible(with: error,
                                                                retryCount: self.retryCount) { [weak self] in
                self?.fetchDatabaseChanges(completion: completion)
            }

            if retrying {
                self.retryCount += 1
            }
            else {
                completion(zoneWasDeleted, changedZoneIDs, error)
            }
        }

        database.add(operation)
        self.operation = operation
    }
}
