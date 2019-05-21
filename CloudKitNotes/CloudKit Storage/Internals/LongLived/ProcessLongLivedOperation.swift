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

enum ProcessLongLivedOperationError: Error {
    /// Fetched a long lived operation of unexpected type.
    /// This error should happen only during initial development of an app.
    case invalidOperationType
}

class ProcessLongLivedOperation: BaseCloudKitOperation {
    private(set) var succeeded: Bool = false

    private let container: CKContainer
    private let configuration: CloudKitOperationConfiguration
    private var retryCountByOperationID = [CKOperation.ID: Int]()

    override init(configuration: CloudKitOperationConfiguration, enableDefaultConditions: Bool = true) {
        container = configuration.container
        self.configuration = configuration

        super.init(configuration: configuration, enableDefaultConditions: enableDefaultConditions)

        // allow only 1 retry (because operation contains a lot of sub operations)
        retryCount = CloudKitErrorHandler.maxRetryCount - 1
    }

    override func execute() {
        fetchLongLivedOperations { [weak self] operations, errors, succeeded in
            guard let self = self else { return }

            if let operations = operations {
                for operation in operations {
                    let modifyOperation = ModifyRecordsOperation(configuration: self.configuration,
                                                                 restoredOperation: operation)
                    self.produceOperation(modifyOperation)
                }
            }

            self.succeeded = succeeded

            if let errors = errors {
                self.finish(errors)
            }
            else {
                self.finish()
            }
        }
    }

    // MARK: Private

    private func fetchLongLivedOperations(
        completion: @escaping ([CKModifyRecordsOperation]?, [Error]?, _ failed: Bool) -> Void
    ) {
        container.fetchAllLongLivedOperationIDs(completionHandler: { [weak self] operationIDs, error in
            guard let self = self, !self.isCancelled else { return }

            if let error = error {
                cksLog("Processing long lived operations... Failed: \(error)")

                let retrying = CloudKitErrorHandler.retryIfPossible(with: error,
                                                                    retryCount: self.retryCount) { [weak self] in
                    self?.fetchLongLivedOperations(completion: completion)
                }

                if retrying {
                    self.retryCount += 1
                }
                else {
                    completion(nil, [error], false)
                }
            }
            else {
                if let operationIDs = operationIDs {
                    let operationsGroup = DispatchGroup()

                    var operations = [CKModifyRecordsOperation]()
                    var errors = [Error]()

                    for operationID in operationIDs {
                        operationsGroup.enter()

                        self.retryCountByOperationID[operationID] = CloudKitErrorHandler.maxRetryCount - 1
                        self.fetchLongLivedOperation(withID: operationID, completion: { operation, error in
                            if let operation = operation {
                                operations.append(operation)
                            }

                            if let error = error {
                                errors.append(error)
                            }

                            operationsGroup.leave()
                        })
                    }

                    operationsGroup.notify(queue: DispatchQueue.global()) {
                        // Consider the whole operation succeeded if at least one operation was fetched
                        completion(operations.isEmpty ? nil : operations,
                                   errors.isEmpty ? nil : errors,
                                   !operations.isEmpty || errors.isEmpty)
                    }
                }
                else {
                    completion([], nil, true)
                }
            }
        })
    }

    private func fetchLongLivedOperation(withID operationID: CKOperation.ID,
                                         completion: @escaping (CKModifyRecordsOperation?, Error?) -> Void) {
        container.fetchLongLivedOperation(withID: operationID, completionHandler: { [weak self] operation, error in
            guard let self = self, !self.isCancelled else { return }

            if let error = error {
                cksLog("Processing long lived operation \(operationID) Failed: \(error)")

                guard let retryCount = self.retryCountByOperationID[operationID] else {
                    assert(false, "Initial retry count should be set before calling fetchLongLivedOperation()")
                    completion(nil, error)
                    return
                }

                let retrying = CloudKitErrorHandler.retryIfPossible(with: error,
                                                                    retryCount: retryCount) { [weak self] in
                    self?.fetchLongLivedOperation(withID: operationID, completion: completion)
                }

                if retrying {
                    self.retryCountByOperationID[operationID] = retryCount + 1
                }
                else {
                    completion(nil, error)
                }
            }
            else {
                assert(operation is CKModifyRecordsOperation, "Unhandled long lived operation class")
                if let operation = operation as? CKModifyRecordsOperation {
                    completion(operation, nil)
                }
                else {
                    completion(nil, ProcessLongLivedOperationError.invalidOperationType)
                }
            }
        })
    }
}
