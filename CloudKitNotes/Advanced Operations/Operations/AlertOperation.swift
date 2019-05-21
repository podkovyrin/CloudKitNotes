//
//  Copyright © 2015 Apple Inc. All Rights Reserved.
//  See LICENSE.txt for this sample’s licensing information
//
//  Modified by Andrew Podkovyrin, 2019
//

import UIKit

class AlertOperation: ANOperation {
    // MARK: Properties

    private let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
    private let presentationContext: UIViewController?

    var title: String? {
        get {
            return alertController.title
        }
        set {
            alertController.title = newValue
            name = newValue
        }
    }

    var message: String? {
        get {
            return alertController.message
        }
        set {
            alertController.message = newValue
        }
    }

    // MARK: Initialization

    init(presentationContext: UIViewController? = nil) {
        self.presentationContext = presentationContext ?? UIApplication.shared.keyWindow?.rootViewController

        super.init()
        addCondition(AlertPresentation())

        /*
         This operation modifies the view controller hierarchy.
         Doing this while other such operations are executing can lead to
         inconsistencies in UIKit. So, let's make them mutally exclusive.
         */
        addCondition(MutuallyExclusive<UIViewController>())
    }

    func addAction(_ title: String, style: UIAlertAction.Style = .default, handler: ((AlertOperation) -> Void)? = nil) {
        let action = UIAlertAction(title: title, style: style) { [weak self] _ in
            if let self = self {
                handler?(self)
            }
            self?.finish()
        }
        alertController.addAction(action)
    }

    override func execute() {
        guard let presentationContext = presentationContext else {
            finish()
            return
        }

        DispatchQueue.main.async {
            if self.alertController.actions.isEmpty {
                self.addAction(NSLocalizedString("OK", comment: ""))
            }
            presentationContext.present(self.alertController, animated: true)
        }
    }
}
