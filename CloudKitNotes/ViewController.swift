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

import UIKit

private let kCellId = "NoteCell"

// swiftlint:disable implicitly_unwrapped_optional force_unwrapping prohibited_interface_builder

class ViewController: UITableViewController {
    private var storage: Storage!
    private var cloudKitStorage: CloudKitStorage<Note>!
    private let userDefaults = AppDelegate.shared.userDefaults

    override func viewDidLoad() {
        super.viewDidLoad()

        storage = AppDelegate.shared.storage
        storage.uiDelegate = self

        cloudKitStorage = AppDelegate.shared.cloudKitStorage
    }

    @IBAction private func addAction(_ sender: Any) {
        let alert = UIAlertController.alertWithText { text in
            self.storage.addNote(text: text)

            // Ask user to enable CloudKit on adding very first note

            // Second entry point where CloudKit might get enabled
            // (others two: in AppDelegate on start up and by CKAccountChanged notification)
            self.enableCloudBackupIfAllowed()
        }
        present(alert, animated: true, completion: nil)
    }

    @IBAction private func actionsAction(_ sender: Any) {
        let cloudBackupEnabled = userDefaults.isCloudBackupEnabled

        let message = String(format: NSLocalizedString("iCloud Backup Enabled: %@", comment: ""),
                             cloudBackupEnabled ? "✅" : "❌")
        let actionSheet = UIAlertController(title: NSLocalizedString("Actions", comment: ""),
                                            message: message,
                                            preferredStyle: .actionSheet)

        if cloudBackupEnabled {
            let terminateAction = UIAlertAction(
                title: NSLocalizedString("Disable iCloud Backup", comment: ""),
                style: .destructive
            ) { _ in
                self.disableCloudBackup()
            }
            actionSheet.addAction(terminateAction)
        }
        else {
            let enableAction = UIAlertAction(
                title: NSLocalizedString("Enable iCloud Backup", comment: ""),
                style: .default
            ) { _ in
                self.enableCloudBackup()
            }
            actionSheet.addAction(enableAction)
        }

        let logsAction = UIAlertAction(title: "Logs", style: .default) { _ in
            let logsViewController = LogsViewController()
            let navigationController = UINavigationController(rootViewController: logsViewController)
            self.present(navigationController, animated: true, completion: nil)
        }
        actionSheet.addAction(logsAction)

        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel)
        actionSheet.addAction(cancelAction)

        present(actionSheet, animated: true, completion: nil)
    }

    // MARK: Private

    private func enableCloudBackup() {
        userDefaults.isCloudBackupEnabled = true

        cloudKitStorage.startSync { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                self.userDefaults.isCloudBackupEnabled = false

                let alert = UIAlertController.alertWithError(error)
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    private func disableCloudBackup() {
        cloudKitStorage.stopSyncAndDeleteAllData(completion: { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                let alert = UIAlertController.alertWithError(
                    error,
                    title: NSLocalizedString("Disabling Cloud Sync Failed", comment: "")
                )
                self.present(alert, animated: true, completion: nil)
            }
            else {
                self.userDefaults.isCloudBackupEnabled = false
            }
        })
    }

    private func enableCloudBackupIfAllowed() {
        guard !userDefaults.isCloudBackupAsked && !userDefaults.isCloudBackupEnabled else {
            return
        }

        let alert = UIAlertController(
            title: NSLocalizedString("iCloud Sync", comment: ""),
            message: NSLocalizedString("Do you want to enable syncing data to your iCloud?", comment: ""),
            preferredStyle: .alert
        )

        let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
            self.userDefaults.isCloudBackupAsked = true

            self.enableCloudBackup()
        }
        alert.addAction(okAction)
        alert.preferredAction = okAction

        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
            self.userDefaults.isCloudBackupAsked = true
        }
        alert.addAction(cancelAction)

        present(alert, animated: true, completion: nil)
    }
}

// MARK: ViewController + UITableView

extension ViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return storage.notes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kCellId, for: indexPath)

        let note = storage.notes[indexPath.row]
        cell.textLabel?.text = note.text

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let note = storage.notes[indexPath.row]

        let alert = UIAlertController.alertWithText(note.text) { text in
            self.storage.updateNote(note, text: text)
        }
        present(alert, animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let note = storage.notes[indexPath.row]
            storage.deleteNote(note)
        }
    }
}

// MARK: StorageUIChangesDelegate

extension ViewController: StorageUIChangesDelegate {
    func storage(_ storage: Storage,
                 didInsertObjectsAtIndexes insertedIndexes: [Int],
                 didUpdateObjectsAtIndexes updatedIndexes: [Int],
                 didDeleteObjectsAtIndexes deletedIndexes: [Int]) {
        let transform = { IndexPath(row: $0, section: 0) }
        let deletedIndexPaths = deletedIndexes.map(transform)
        let insertedIndexPaths = insertedIndexes.map(transform)
        let updatedIndexPaths = updatedIndexes.map(transform)

        tableView.performBatchUpdates({
            if !deletedIndexes.isEmpty {
                tableView.deleteRows(at: deletedIndexPaths, with: .automatic)
            }
            if !insertedIndexPaths.isEmpty {
                tableView.insertRows(at: insertedIndexPaths, with: .automatic)
            }
            if !updatedIndexPaths.isEmpty {
                tableView.reloadRows(at: updatedIndexPaths, with: .automatic)
            }
        }, completion: nil)
    }
}

// MARK: UIAlertController Helper

private extension UIAlertController {
    static func alertWithText(_ text: String = "",
                              completion: @escaping (String) -> Void) -> UIAlertController {
        let alert = UIAlertController(title: "Note", message: nil, preferredStyle: .alert)

        alert.addTextField { textField in
            textField.text = text
            textField.placeholder = DateFormatter.localizedString(from: Date(),
                                                                  dateStyle: .short,
                                                                  timeStyle: .medium)
        }

        let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
            let textField = alert.textFields!.first!
            let text = !textField.text!.isEmpty ? textField.text! : textField.placeholder!
            completion(text)
        }
        alert.addAction(okAction)
        alert.preferredAction = okAction

        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel)
        alert.addAction(cancelAction)

        return alert
    }
}

// MARK: Settings

private extension UserDefaults {
    enum Keys {
        static let isCloudBackupAskedKey = "notes.cloud-backup-asked"
    }

    var isCloudBackupAsked: Bool {
        get {
            return bool(forKey: Keys.isCloudBackupAskedKey)
        }
        set {
            set(newValue, forKey: Keys.isCloudBackupAskedKey)
        }
    }
}
