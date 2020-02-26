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

protocol LocalStorageObject {
    static var cloudKitRecordType: String { get }

    var identifier: String { get }
    var modified: Date { get }

    init(record: CKRecord) throws

    func recordIDInZoneID(_ zoneID: CKRecordZone.ID) -> CKRecord.ID
    func recordInZoneID(_ zoneID: CKRecordZone.ID) throws -> CKRecord
}

protocol LocalStorageChangesObserver: AnyObject {
    func storageDidModify(objectsToSave: [LocalStorageObject], objectsToDelete: [LocalStorageObject])
}

protocol LocalStorage: AnyObject {
    var changesObserver: LocalStorageChangesObserver? { get set }

    func processChangedObjects(_ changedObjects: [LocalStorageObject],
                               deletetedObjectIDs: [String])
    func allObjects() -> [LocalStorageObject]
}
