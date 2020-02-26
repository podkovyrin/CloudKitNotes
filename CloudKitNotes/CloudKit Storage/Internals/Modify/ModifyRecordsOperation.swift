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

class ModifyRecordsOperation: BaseCloudKitOperation {
    private let recordsToSave: [CKRecord]?
    private let recordIDsToDelete: [CKRecord.ID]?
    private let restoredOperation: CKModifyRecordsOperation?
    private weak var operation: CKOperation?

    init(configuration: CloudKitOperationConfiguration,
         recordsToSave: [CKRecord],
         recordIDsToDelete: [CKRecord.ID]) {
        self.recordsToSave = recordsToSave
        self.recordIDsToDelete = recordIDsToDelete
        restoredOperation = nil

        super.init(configuration: configuration)
    }

    init(configuration: CloudKitOperationConfiguration, restoredOperation: CKModifyRecordsOperation) {
        self.restoredOperation = restoredOperation
        recordsToSave = nil
        recordIDsToDelete = nil

        super.init(configuration: configuration)
    }

    override func execute() {
        assert(restoredOperation != nil || recordsToSave != nil || recordIDsToDelete != nil, "Inconsistent state")

        let completion: (Error?) -> Void = { [weak self] error in
            guard let self = self else { return }

            self.finishWithError(error)
        }

        if let restoredOperation = restoredOperation {
            modifyRecords(operation: restoredOperation, completion: completion)
        }
        else {
            modifyRecords(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete, completion: completion)
        }
    }

    override func cancel() {
        operation?.cancel()
        super.cancel()
    }

    // MARK: Private

    private func modifyRecords(recordsToSave: [CKRecord]?,
                               recordIDsToDelete: [CKRecord.ID]?,
                               completion: @escaping (Error?) -> Void) {
        cksLog("""
        < Sending \(recordsToSave?.count ?? 0) records to save, \(recordIDsToDelete?.count ?? 0) records to delete
        """)

        let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave,
                                                 recordIDsToDelete: recordIDsToDelete)

        // Long lived operations will continue running even if your process exits.
        // If your process remains alive for the lifetime of the long lived operation
        // its behavior is the same as a regular operation.
        //
        // Important notice:
        // There is a small gap of time until a long lived operation get persited by system
        // after adding CKModifyRecordsOperation to the queue.
        // Let's neglect this scenario as it requires an additional level of cache to maintain.
        // Anyway, there is `longLivedOperationWasPersistedBlock` to eliminate this possibility
        let configuration = CKOperation.Configuration()
        configuration.isLongLived = true
        operation.configuration = configuration

        // Modify record happens when user changes the corresponding object
        // that means we don't care much about what's currently stored in CloudKit
        operation.savePolicy = .changedKeys

        modifyRecords(operation: operation, completion: completion)
    }

    private func modifyRecords(operation: CKModifyRecordsOperation,
                               completion: @escaping (Error?) -> Void) {
        operation.modifyRecordsCompletionBlock = { [weak self, weak operation] _, _, error in
            guard let self = self, let operation = operation, !self.isCancelled else { return }

            guard let error = error else {
                cksLog("Finished saving records")
                completion(nil)

                return
            }

            cksLog("Error modifying records: \(error)")

            // If your app receives CKError.Code.limitExceeded,
            // it must split the operation in half and try both requests again.
            if let error = error as? CKError {
                // partialFailure might happen if:
                // - merging failed (when default `savePolicy` is used)
                // - there is no zone
                // - probably some other cases - investigation is needed
                // Both cases are almoust impossible in current configuration as we use `changedKeys` policy and
                // zone is enforced to exist when CloudKitStorage is enabled.
                // If user disabled iCloud Syncing (by deleting the zone) it's fine to fail save operation
                assert(error.code != .partialFailure,
                       "Investigate the problem with \(String(describing: error.partialErrorsByItemID))")

                if error.code == .limitExceeded {
                    cksLog("Splitting the Modify Records Operation input...")

                    let splittedRecordsToSave = operation.recordsToSave?.splitInHalf() ?? ([], [])
                    let splittedRecordIDsToDelete = operation.recordIDsToDelete?.splitInHalf() ?? ([], [])

                    self.modifyRecords(recordsToSave: splittedRecordsToSave.0,
                                       recordIDsToDelete: splittedRecordIDsToDelete.0,
                                       completion: completion)

                    self.modifyRecords(recordsToSave: splittedRecordsToSave.1,
                                       recordIDsToDelete: splittedRecordIDsToDelete.1,
                                       completion: completion)
                }
            }

            let retrying = CloudKitErrorHandler.retryIfPossible(with: error,
                                                                retryCount: self.retryCount) { [weak self] in
                self?.modifyRecords(recordsToSave: operation.recordsToSave,
                                    recordIDsToDelete: operation.recordIDsToDelete,
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

private extension Array {
    /// Splits Array into two halves.
    /// If elements count is odd `secondHalf` will have `count / 2 + 1` elements
    /// - Returns: Tuple with two halves
    func splitInHalf() -> (firstHalf: [Element], secondHalf: [Element]) {
        let midpoint = count / 2
        let firstHalf = self[..<midpoint]
        let secondHalf = self[midpoint...]

        return (Array(firstHalf), Array(secondHalf))
    }
}
