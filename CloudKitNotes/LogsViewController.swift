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

class LogsViewController: UIViewController {
    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "CloudKitStorage Logs"

        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel,
                                           target: self,
                                           action: #selector(cancelButtonAction))
        navigationItem.leftBarButtonItem = cancelButton

        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        textView.frame = view.bounds
        textView.isEditable = false
        if let font = UIFont(name: "Menlo-Regular", size: 11) {
            textView.font = font
        }
        view.addSubview(textView)

        updateLogs()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateLogs),
                                               name: LogsStorage.logsUpdatedNotification,
                                               object: nil)
    }

    @objc
    private func updateLogs() {
        textView.text = LogsStorage.shared.exportLogs
    }

    @objc
    private func cancelButtonAction() {
        dismiss(animated: true, completion: nil)
    }
}
