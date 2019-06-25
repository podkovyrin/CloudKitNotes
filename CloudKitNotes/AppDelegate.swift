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
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    let userDefaults = UserDefaults.standard
    // swiftlint:disable implicitly_unwrapped_optional
    private(set) var storage: Storage!
    private(set) var cloudKitStorage: CloudKitStorage<Note>!
    // swiftlint:enable implicitly_unwrapped_optional

    static var shared = {
        // swiftlint:disable force_cast
        UIApplication.shared.delegate as! AppDelegate
        // swiftlint:enable force_cast
    }()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Setup Storage

        storage = Storage(userDefaults: userDefaults)

        // Setup CloudKit

        // Subscribe for silent pushes
        // (Silent pushes are available without any confirmation from the user)
        application.registerForRemoteNotifications()

        cloudKitStorage = CloudKitStorage(userDefaults: userDefaults, storage: storage)
        cloudKitStorage.delegate = self
        if userDefaults.isCloudBackupEnabled {
            // performs initial fetch
            cloudKitStorage.startSync(userInitiated: false, completion: nil)
        }

        return true
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if !userDefaults.isCloudBackupEnabled {
            completionHandler(.failed)
            return
        }

        guard let cloudKitStorage = cloudKitStorage,
            let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            completionHandler(.failed)
            return
        }

        if notification.subscriptionID == cloudKitStorage.subscriptionID {
            cloudKitStorage.fetchChanges(completion: completionHandler)
        }
        else {
            completionHandler(.noData)
        }
    }
}

extension AppDelegate: CloudKitStorageDelegate {
    func cloudKitStorage<T: LocalStorageObject>(_ cloudKitStorage: CloudKitStorage<T>,
                                                didFailedWithError error: CKError) {
        guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
            return
        }

        let alert = UIAlertController(title: NSLocalizedString("iCloud Backup Error", comment: ""),
                                      message: error.userAlertMessage,
                                      preferredStyle: .alert)

        if error.code == .userDeletedZone {
            let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""),
                                         style: .default,
                                         handler: { _ in
                                             // just re-start sync to upload data again
                                             self.enableCloudBackup()
            })
            alert.addAction(okAction)
            alert.preferredAction = okAction

            let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel)
            alert.addAction(cancelAction)
        }
        else {
            let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default)
            alert.addAction(okAction)
        }

        rootViewController.present(alert, animated: true, completion: nil)
    }

    private func enableCloudBackup() {
        cloudKitStorage.startSync(userInitiated: true) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                self.userDefaults.isCloudBackupEnabled = false

                guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
                    return
                }

                let alert = UIAlertController.alertWithError(error)
                rootViewController.present(alert, animated: true, completion: nil)
            }
        }
    }
}
