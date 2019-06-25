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
import Reachability //
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
import UIKit

// swiftlint:disable file_length

protocol CloudKitStorageDelegate: AnyObject {
    func cloudKitStorage<T: LocalStorageObject>(_ cloudKitStorage: CloudKitStorage<T>,
                                                didFailedWithError error: CKError)
}

class CloudKitStorage<T: LocalStorageObject> {
    let subscriptionID: CKSubscription.ID = Constants.subscriptionID
    weak var delegate: CloudKitStorageDelegate?

    private let container = CKContainer.default()
    private let database: CKDatabase
    private let operationQueue = ANOperationQueue()
    private let recordType: String
    private let userDefaults: UserDefaults
    private let reachability: Reachability
    private let storage: LocalStorage
    private var isSetupInProgress: Bool = false
    private var isLongLivedOperationsProcessed: Bool = false
    private var isMonitoringNotifications: Bool = false

    private var zoneID: CKRecordZone.ID {
        return CKRecordZone.ID(zoneName: "\(recordType)-zone", ownerName: CKCurrentUserDefaultName)
    }

    init(userDefaults: UserDefaults, storage: LocalStorage) {
        self.userDefaults = userDefaults
        self.storage = storage

        // don't allow simultaneous operations to prevent collisions
        // for example, when user enables syncing we should create zone first and process subsequent saves after that
        operationQueue.maxConcurrentOperationCount = 1

        database = container.privateCloudDatabase
        recordType = T.cloudKitRecordType

        // Use CloudKit Web Service URL as host to check internet connection
        guard let reachability = Reachability(hostname: Constants.cloudKitHost) else {
            fatalError("Failed to initialized Reachability. Invalid host?")
        }
        self.reachability = reachability
    }

    // MARK: On / Off

    func startSync(userInitiated: Bool, completion: ((Error?) -> Void)? = nil) {
        assert(Thread.isMainThread, "Main thread is assumed here")

        assert(!isSetupInProgress, "Already setting up")

        if userInitiated {
            assert(completion != nil, "User initiated action should have completion set")
            // Make sure that we are starting from scratch: reset all flags and remove change tokens
            userDefaults.resetToDefaults()
        }

        startMonitoringNotifications()
        verifyAccountStatusAndStartSyncing(completion: completion)
    }

    func stopSyncAndDeleteAllData(completion: @escaping (Error?) -> Void) {
        assert(Thread.isMainThread, "Main thread is assumed here")

        cksLog("Shutting down CloudKit...")

        // Do not cancel any operations on the queue or reset any states until we make sure that operation succeded

        let operation = DeleteZoneOperation(configuration: operationConfiguration, zoneID: zoneID)
        operation.delegate = self

        operation.addCompletionObserver { [weak self] _, errors in
            guard let self = self else { return }

            if let error = errors.first {
                cksLog("Shutting down CloudKit... Failed: \(error)")
                completion(error)
            }
            else {
                self.stopMonitoringNotifications()
                self.terminateCloudKit()
                completion(nil)
            }
        }

        operationQueue.addOperation(operation)
    }

    // MARK: Fetch

    func fetchChanges(completion: @escaping (UIBackgroundFetchResult) -> Void) {
        cksLog("Fetching changes...")

        let operation = FetchChangesOperation(configuration: operationConfiguration, zoneID: zoneID)
        operation.delegate = self

        operation.processChanges = { [weak self] changedRecords, deletedRecordIDs in
            guard let self = self else { return }

            let localObjects = self.storage.allObjects()

            // Merge fetched changes with local objects
            // Outdated changes are ignored
            let changedObjects = changedRecords.map { T(record: $0) }.filter { object -> Bool in
                if let index = localObjects.firstIndex(where: { $0.identifier == object.identifier }) {
                    let localObject = localObjects[index]
                    // save object if localObject is older
                    if localObject.modified < object.modified {
                        return true
                    }
                }
                else {
                    // save new object
                    return true
                }

                return false
            }

            let deletedObjectIDs = deletedRecordIDs.map { $0.recordName }

            self.storage.processChangedObjects(changedObjects, deletetedObjectIDs: deletedObjectIDs)
        }

        operation.addCompletionObserver { [weak self] operation, errors in
            guard let self = self else { return }

            var fetchResult = UIBackgroundFetchResult.noData
            if let zoneWasDeleted = operation.zoneWasDeleted, zoneWasDeleted {
                // User disabled syncing on their other device or removed all iCloud data of the app via Settings.app
                self.terminateCloudKit()
                self.delegate?.cloudKitStorage(self, didFailedWithError: CKError(.userDeletedZone))
                fetchResult = .newData
            }

            if operation.hasNewData {
                fetchResult = .newData
            }

            if fetchResult == .noData && operation.failed {
                cksLog("Fetching changes... Failed: \(String(describing: errors.first))")
                fetchResult = .failed
            }

            completion(fetchResult)
        }

        operationQueue.addOperation(operation)
    }

    // MARK: - Private

    /// Verifies if there is active iCloud account and starts syncing.
    private func verifyAccountStatusAndStartSyncing(completion: ((Error?) -> Void)?) {
        cksLog("Verifying iCloud account...")

        container.verify { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    cksLog("Verifying iCloud account... Failed: \(error)")

                    // Without iCloud account we can not guarantee saving changes
                    // (as we're not caching them when account is disabled)
                    // Reset state flags and change tokens to re-save all changes when account will be enabled
                    self.userDefaults.resetToDefaults()
                    self.terminateCloudKit()

                    // If it's user-initiated action, report error to completion handler
                    if let completion = completion {
                        self.stopMonitoringNotifications()
                        completion(error)
                    }
                    else {
                        self.delegate?.cloudKitStorage(self, didFailedWithError: CKError(.notAuthenticated))
                    }
                }
                else {
                    self.setupCloudKit(completion: completion)
                }
            }
        }
    }

    private func setupCloudKit(completion: ((Error?) -> Void)?) {
        assert(Thread.isMainThread, "Main thread is assumed here")

        guard !isSetupInProgress else {
            return
        }
        isSetupInProgress = true

        cksLog("Setting up CloudKit...")

        // start monitoring and collecting changes of local storage
        storage.changesObserver = self

        let operation = SetupCloudKitOperation(configuration: operationConfiguration,
                                               zoneID: zoneID,
                                               subscriptionID: subscriptionID)
        operation.delegate = self

        operation.addCompletionObserver { [weak self] operation, errors in
            guard let self = self else { return }

            self.isSetupInProgress = false

            if let error = errors.first {
                cksLog("Setting up CloudKit... Failed: \(error)")
                // In case of user-initiated setup disable syncing if we were not able to create zone, notify user
                if let completion = completion {
                    self.terminateCloudKit()
                    completion(error)
                }
                else {
                    assert(false, "Here should not be any error or very first setup is not initiated by the user")
                }
            }
            else {
                assert(operation.shouldSyncLocalData != nil,
                       "If there is no error we should able to get shouldSyncAllData value")

                // Fetch changes before saving to prevent CloudKit sending them back to the client
                self.fetchChanges(completion: { _ in })

                self.processLongLivedOperations()

                // We are saving all changes when zone was newly created
                guard let shouldSyncLocalData = operation.shouldSyncLocalData else { return }

                if shouldSyncLocalData {
                    let allObjects = self.storage.allObjects()
                    self.save(objectsToSave: allObjects, objectsToDelete: [])
                }

                completion?(nil)
            }
        }

        operationQueue.addOperation(operation)
    }

    private func processLongLivedOperations() {
        // A long lived operations should be processed once per app start
        guard !isLongLivedOperationsProcessed else {
            return
        }

        cksLog("Processing long lived operations...")

        let operation = ProcessLongLivedOperation(configuration: operationConfiguration)
        operation.delegate = self

        operation.addCompletionObserver { [weak self] operation, errors in
            guard let self = self else { return }

            if let error = errors.first {
                cksLog("Processing long lived operations... Failed: \(error)")
                // Do not set isLongLivedOperationsProcessed flag, fetch them next time
                return
            }

            self.isLongLivedOperationsProcessed = operation.succeeded
        }

        operationQueue.addOperation(operation)
    }

    private func save(objectsToSave: [LocalStorageObject], objectsToDelete: [LocalStorageObject]) {
        if objectsToSave.isEmpty && objectsToDelete.isEmpty {
            return
        }

        cksLog("Saving local objects...")

        let recordsToSave = objectsToSave.map { $0.recordInZoneID(zoneID) }
        let recordIDsToDelete = objectsToDelete.map { $0.recordIDInZoneID(zoneID) }

        let operation = ModifyRecordsOperation(configuration: operationConfiguration,
                                               recordsToSave: recordsToSave,
                                               recordIDsToDelete: recordIDsToDelete)
        operation.delegate = self
        operationQueue.addOperation(operation)
    }

    // Stops observing changes from LocalStorage and cancels all operations
    private func terminateCloudKit() {
        cksLog("Terminating CloudKit sync...")
        isSetupInProgress = false
        storage.changesObserver = nil
        operationQueue.cancelAllOperations()
    }

    private var operationConfiguration: CloudKitOperationConfiguration {
        return CloudKitOperationConfiguration(container: container,
                                              database: database,
                                              userDefaults: userDefaults)
    }

    // MARK: Notifications

    /// Subscribe to Reachability, iCloud account changed and App Will Enter Foreground notifications.
    private func startMonitoringNotifications() {
        assert(Thread.isMainThread, "Main thread is assumed here")

        guard !isMonitoringNotifications else {
            return
        }
        isMonitoringNotifications = true

        let notificationCenter = NotificationCenter.default

        notificationCenter.addObserver(self,
                                       selector: #selector(reachabilityDidChange(_:)),
                                       name: .reachabilityChanged,
                                       object: reachability)
        do {
            try reachability.startNotifier()
        }
        catch {
            cksLog("Could not start reachability notifier")
        }

        notificationCenter.addObserver(self,
                                       selector: #selector(accountDidChange(_:)),
                                       name: .CKAccountChanged,
                                       object: nil)

        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillEnterForeground(_:)),
                                       name: UIApplication.willEnterForegroundNotification,
                                       object: nil)
    }

    private func stopMonitoringNotifications() {
        assert(Thread.isMainThread, "Main thread is assumed here")

        guard isMonitoringNotifications else {
            return
        }
        isMonitoringNotifications = false

        reachability.stopNotifier()

        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self)
    }

    @objc
    private func reachabilityDidChange(_ notification: Notification) {
        assert(Thread.isMainThread, "Main thread is assumed here")

        if reachability.connection != .none {
            cksLog("(i) Internet connection is available")
            verifyAccountStatusAndStartSyncing(completion: nil)
        }
    }

    @objc
    private func accountDidChange(_ notification: Notification) {
        cksLog("(i) iCloud account changed")
        verifyAccountStatusAndStartSyncing(completion: nil)
    }

    @objc
    private func applicationWillEnterForeground(_ notification: Notification) {
        cksLog("(i) Application will enter foreground")
        verifyAccountStatusAndStartSyncing(completion: nil)
    }
}

// MARK: CloudKitOperationDelegate

extension CloudKitStorage: CloudKitOperationDelegate {
    func operationRequiresUserAction(_ operation: Operation, error: CKError) {
        DispatchQueue.main.async {
            self.delegate?.cloudKitStorage(self, didFailedWithError: error)
        }
    }
}

// MARK: Local Changes Observer

extension CloudKitStorage: LocalStorageChangesObserver {
    func storageDidModify(objectsToSave: [LocalStorageObject], objectsToDelete: [LocalStorageObject]) {
        save(objectsToSave: objectsToSave, objectsToDelete: objectsToDelete)
    }
}

// MARK: - Private

private enum Constants {
    static let subscriptionID = "private-database-changes"
    static let cloudKitHost = "https://api.apple-cloudkit.com"
}
