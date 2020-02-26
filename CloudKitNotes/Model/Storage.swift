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

import Foundation

protocol StorageUIChangesDelegate: AnyObject {
    func storage(_ storage: Storage,
                 didInsertObjectsAtIndexes insertedIndexes: [Int],
                 didUpdateObjectsAtIndexes updatedIndexes: [Int],
                 didDeleteObjectsAtIndexes deletedIndexes: [Int])
}

/// Simple UserDefaults-based offline storage
class Storage: LocalStorage {
    private(set) var notes: [Note]
    weak var uiDelegate: StorageUIChangesDelegate?

    weak var changesObserver: LocalStorageChangesObserver?

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        notes = userDefaults.notes
    }

    func addNote(text: String) {
        let note = Note(id: UUID().uuidString, text: text, modified: Date())
        notes.append(note)
        userDefaults.notes = notes

        changesObserver?.storageDidModify(objectsToSave: [note], objectsToDelete: [])
        uiDelegate?.storage(self, didInsertObjectsAtIndexes: [notes.count - 1],
                            didUpdateObjectsAtIndexes: [],
                            didDeleteObjectsAtIndexes: [])
    }

    func updateNote(_ note: Note, text: String) {
        let newNote = Note(id: note.id, text: text, modified: Date())
        // swiftlint:disable force_unwrapping
        let index = notes.firstIndex(of: note)!
        // swiftlint:enable force_unwrapping
        notes[index] = newNote
        userDefaults.notes = notes

        changesObserver?.storageDidModify(objectsToSave: [newNote], objectsToDelete: [])
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

        changesObserver?.storageDidModify(objectsToSave: [], objectsToDelete: [note])
        uiDelegate?.storage(self, didInsertObjectsAtIndexes: [],
                            didUpdateObjectsAtIndexes: [],
                            didDeleteObjectsAtIndexes: [index])
    }

    // MARK: Local Storage

    func processChangedObjects(_ changedObjects: [LocalStorageObject],
                               deletetedObjectIDs: [String]) {
        var insertedIndexes = [Int]()
        var updatedIndexes = [Int]()
        var deletedIndexes = [Int]()

        var notesCopy = notes

        // Order of processing updates in batch by UITableView: deletes, inserts, updates

        for id in deletetedObjectIDs {
            if let index = notesCopy.firstIndex(where: { $0.id == id }) {
                notesCopy.remove(at: index)
                deletedIndexes.append(index)
            }
            else {
                debugPrint("Failed to delete local object with id \(id) - not found")
            }
        }

        for case let note as Note in changedObjects {
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

    func allObjects() -> [LocalStorageObject] {
        notes
    }
}

private extension Note {
    init(dictionary: [String: Any]) {
        // swiftlint:disable force_cast
        id = dictionary["id"] as! String
        text = dictionary["text"] as! String
        modified = dictionary["modified"] as! Date
        // swiftlint:enable force_cast
    }

    func asDictionary() -> [String: Any] {
        ["id": id, "text": text, "modified": modified]
    }
}

private extension UserDefaults {
    var notes: [Note] {
        get {
            let rawNotes = array(forKey: "notes") as? [[String: Any]] ?? []
            var notes = [Note]()
            for rawNote in rawNotes {
                notes.append(Note(dictionary: rawNote))
            }
            return notes
        }
        set {
            var rawNotes = [[String: Any]]()
            for note in newValue {
                rawNotes.append(note.asDictionary())
            }
            set(rawNotes, forKey: "notes")
        }
    }
}
