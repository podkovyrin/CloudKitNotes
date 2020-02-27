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
import CloudSync
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    let userDefaults = UserDefaults.standard
    // swiftlint:disable implicitly_unwrapped_optional
    private(set) var storage: Storage!
    private(set) var cloudSync: CloudSync!
    // swiftlint:enable implicitly_unwrapped_optional

    static var shared = {
        // swiftlint:disable force_cast
        UIApplication.shared.delegate as! AppDelegate
        // swiftlint:enable force_cast
    }()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Setup Storage

        let config = CloudSync.Configuration(containerIdentifier: "iCloud.com.podkovyrin.CloudNotes",
                                             zoneName: "NotesZone")
        cloudSync = CloudSync(defaults: userDefaults, configuration: config)

        storage = Storage(userDefaults: userDefaults, cloudSync: cloudSync)

        // Subscribe for silent pushes
        // (Silent pushes are available without any confirmation from the user)
        application.registerForRemoteNotifications()

        return true
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if !userDefaults.isCloudBackupEnabled {
            completionHandler(.failed)
            return
        }

        cloudSync.processSubscriptionNotification(with: userInfo, completion: completionHandler)
    }
}
