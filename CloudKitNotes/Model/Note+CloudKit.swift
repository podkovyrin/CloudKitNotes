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

extension Note {
    private static var cloudKitRecordType = "Note"

    init(record: CKRecord) {
        id = record.recordID.recordName
        // swiftlint:disable force_unwrapping
        text = record["text"]!
        // swiftlint:enable force_unwrapping
        // swiftlint:disable force_cast
        modified = record["modified"] as! Date
        // swiftlint:enable force_cast

        ckData = record.encodedSystemFields
    }

    func recordIDIn(_ zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: id, zoneID: zoneID)
    }

    func recordIn(_ zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = recordIDIn(zoneID)
        let record = CKRecord(recordType: Self.cloudKitRecordType, recordID: recordID)
        record["text"] = text
        record["modified"] = modified

        return record
    }
}
