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

extension UserDefaults {
    private enum Keys {
        static let createdCustomZoneKey = "notes.cloudkit-storage.created-custom-zone"
        static let subscribedToChangesKey = "notes.cloudkit-storage.subscribed-to-changes"
        static let previousDatabaseChangeTokenKey = "notes.cloudkit-storage.previous-database-change-token"
        static let previousZoneChangeTokenKey = "notes.cloudkit-storage.previous-zone-change-token"
    }

    var createdCustomZone: Bool {
        get { bool(forKey: Keys.createdCustomZoneKey) }
        set { set(newValue, forKey: Keys.createdCustomZoneKey) }
    }

    var subscribedToChanges: Bool {
        get { bool(forKey: Keys.subscribedToChangesKey) }
        set { set(newValue, forKey: Keys.subscribedToChangesKey) }
    }

    var previousDatabaseChangeToken: CKServerChangeToken? {
        get {
            guard let tokenData = object(forKey: Keys.previousDatabaseChangeTokenKey) as? Data else {
                return nil
            }

            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self,
                                                           from: tokenData)
        }
        set {
            let key = Keys.previousDatabaseChangeTokenKey

            guard let newValue = newValue,
                let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue,
                                                             requiringSecureCoding: true)
            else {
                removeObject(forKey: key)
                return
            }

            set(data, forKey: key)
        }
    }

    var previousZoneChangeToken: CKServerChangeToken? {
        get {
            guard let tokenData = object(forKey: Keys.previousZoneChangeTokenKey) as? Data else {
                return nil
            }

            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self,
                                                           from: tokenData)
        }
        set {
            let key = Keys.previousZoneChangeTokenKey

            guard let newValue = newValue,
                let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue,
                                                             requiringSecureCoding: true)
            else {
                removeObject(forKey: key)
                return
            }

            set(data, forKey: key)
        }
    }

    func resetToDefaults() {
        createdCustomZone = false
        subscribedToChanges = false
        previousDatabaseChangeToken = nil
        previousZoneChangeToken = nil
    }
}
