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
import Foundation

protocol StorageUIChangesDelegate: AnyObject {
    func storage(_ storage: Storage, display error: Error)
    func storage(_ storage: Storage,
                 didInsertObjectsAtIndexes insertedIndexes: [Int],
                 didUpdateObjectsAtIndexes updatedIndexes: [Int],
                 didDeleteObjectsAtIndexes deletedIndexes: [Int])
    func storage(reloadData storage: Storage)
}

/// Simple UserDefaults-based offline storage
final class Storage {
    private(set) var notes: [Note]
    weak var uiDelegate: StorageUIChangesDelegate?

    private let userDefaults: UserDefaults

    private let cloudSync: CloudSync

    init(userDefaults: UserDefaults, cloudSync: CloudSync) {
        self.userDefaults = userDefaults
        self.cloudSync = cloudSync
        notes = userDefaults.notes ?? []

        if userDefaults.isCloudBackupEnabled {
            startSync(userInitiated: false)
        }
    }

    func startSync(userInitiated: Bool = true) {
        userDefaults.isCloudBackupEnabled = true

        cloudSync.errorHandler = { [weak self] error in
            guard let self = self else { return }

            if error.isCloudKitZoneDeleted || error.isCloudKitAccountProblem {
                self.stopSync()
            }

            self.uiDelegate?.storage(self, display: error)
        }

        cloudSync.didChangeRecords = { [weak self] records in
            self?.processChangedObjects(records, deletetedObjectIDs: [])
        }

        cloudSync.didDeleteRecords = { [weak self] deletedIdentifiers in
            self?.processChangedObjects([], deletetedObjectIDs: deletedIdentifiers)
        }

        let notUploaded = userInitiated ? notes : notes.filter { $0.ckData == nil }
        let records = notUploaded.map { $0.recordIn(cloudSync.zoneID) }

        cloudSync.start(currentRecords: records, verificationCompletion: { error in
            if error != nil {
                self.userDefaults.isCloudBackupEnabled = false
            }
        })
    }

    func disableSync() {
        cloudSync.disable { error in
            if let error = error, error.isCloudKitAccountProblem == false {
                self.uiDelegate?.storage(self, display: error)
            }
            else {
                self.stopSync()
            }
        }
    }

    func addNote(text: String) {
        let note = Note(id: UUID().uuidString, text: text, modified: Date())
        notes.append(note)
        userDefaults.notes = notes

        if userDefaults.isCloudBackupEnabled {
            let record = note.recordIn(cloudSync.zoneID)
            cloudSync.save(records: [record])
        }

        uiDelegate?.storage(self, didInsertObjectsAtIndexes: [notes.count - 1],
                            didUpdateObjectsAtIndexes: [],
                            didDeleteObjectsAtIndexes: [])
    }

    func updateNote(_ note: Note, text: String) {
        var newNote = Note(id: note.id, text: text, modified: Date())
        newNote.ckData = note.ckData

        // swiftlint:disable force_unwrapping
        let index = notes.firstIndex(of: note)!
        // swiftlint:enable force_unwrapping
        notes[index] = newNote
        userDefaults.notes = notes

        if userDefaults.isCloudBackupEnabled {
            let record = newNote.recordIn(cloudSync.zoneID)
            cloudSync.save(records: [record])
        }

        uiDelegate?.storage(self, didInsertObjectsAtIndexes: [],
                            didUpdateObjectsAtIndexes: [index],
                            didDeleteObjectsAtIndexes: [])
    }

    func deleteNote(_ note: Note) {
        // swiftlint:disable force_unwrapping
        let index = notes.firstIndex(of: note)!
        // swiftlint:enable force_unwrapping
        notes.remove(at: index)
        userDefaults.notes = notes

        if userDefaults.isCloudBackupEnabled {
            cloudSync.delete(recordIDs: [note.recordIDIn(cloudSync.zoneID)])
        }

        uiDelegate?.storage(self, didInsertObjectsAtIndexes: [],
                            didUpdateObjectsAtIndexes: [],
                            didDeleteObjectsAtIndexes: [index])
    }

    private func stopSync() {
        userDefaults.isCloudBackupEnabled = false

        cloudSync.stop()
        cloudSync.errorHandler = nil
        cloudSync.didChangeRecords = nil
        cloudSync.didDeleteRecords = nil

        notes = notes.map {
            var note = $0
            note.ckData = nil
            return note
        }
        userDefaults.notes = notes

        uiDelegate?.storage(reloadData: self)
    }

    private func processChangedObjects(_ changedObjects: [CKRecord],
                                       deletetedObjectIDs: [String]) {
        var insertedIndexes = [Int]()
        var updatedIndexes = [Int]()
        var deletedIndexes = [Int]()

        var notesCopy = notes

        // Order of processing updates in batch by UITableView: deletes, inserts, updates

        for id in deletetedObjectIDs {
            // If we can't find local object that means delete was initiated from current device
            if let index = notesCopy.firstIndex(where: { $0.id == id }) {
                notesCopy.remove(at: index)
                deletedIndexes.append(index)
            }
        }

        let changedNotes = changedObjects.map { Note(record: $0) }
        for note in changedNotes {
            if let index = notesCopy.firstIndex(of: note) {
                notesCopy[index] = note
                updatedIndexes.append(index)
            }
            else {
                notesCopy.append(note)
                insertedIndexes.append(notesCopy.count - 1)
            }
        }

        notes = notesCopy
        userDefaults.notes = notesCopy

        uiDelegate?.storage(self, didInsertObjectsAtIndexes: insertedIndexes,
                            didUpdateObjectsAtIndexes: updatedIndexes,
                            didDeleteObjectsAtIndexes: deletedIndexes)
    }
}

private extension UserDefaults {
    var notes: [Note]? {
        get {
            if let data = value(forKey: "notes-key") as? Data {
                return try? PropertyListDecoder().decode([Note].self, from: data)
            }
            return nil
        }
        set {
            set(try? PropertyListEncoder().encode(newValue), forKey: "notes-key")
        }
    }
}
