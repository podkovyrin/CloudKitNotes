//
//  Copyright © 2015 Apple Inc. All Rights Reserved.
//  See LICENSE.txt for this sample’s licensing information
//
//  Modified by Andrew Podkovyrin, 2019
//

import CloudKit
import Foundation

/// A condition describing that the operation requires access to a specific CloudKit container.
struct CloudContainerCondition: OperationCondition {
    static let name = "CloudContainer"

    /*
     CloudKit has no problem handling multiple operations at the same time
     so we will allow operations that use CloudKit to be concurrent with each
     other.
     */
    static let isMutuallyExclusive = false

    let permission: CKContainer.Application.Permissions

    // this is the container to which you need access.
    private let container: CKContainer

    /**
     - parameter container: the `CKContainer` to which you need access.
     - parameter permission: the `CKApplicationPermissions` you need for the
     container. This parameter has a default value of `[]`, which would get
     you anonymized read/write access.
     */
    init(container: CKContainer, permission: CKContainer.Application.Permissions = []) {
        self.container = container
        self.permission = permission
    }

    func dependency(for operation: ANOperation) -> Operation? {
        return CloudKitPermissionOperation(container: container, permission: permission)
    }

    func evaluate(for operation: ANOperation, completion: @escaping (OperationConditionResult) -> Void) {
        container.verify(permission, request: false) { error in
            if let error = error {
                completion(.failure(error))
            }
            else {
                completion(.success)
            }
        }
    }
}

/**
 This operation asks the user for permission to use CloudKit, if necessary.
 If permission has already been granted, this operation will quickly finish.
 */
private class CloudKitPermissionOperation: ANOperation {
    let container: CKContainer
    let permission: CKContainer.Application.Permissions

    init(container: CKContainer, permission: CKContainer.Application.Permissions) {
        self.container = container
        self.permission = permission
        super.init()

        if permission != [] {
            /*
             Requesting non-zero permissions means that this potentially presents
             an alert, so it should not run at the same time as anything else
             that presents an alert.
             */
            addCondition(AlertPresentation())
        }
    }

    override func execute() {
        container.verify(permission, request: true) { [weak self] error in
            guard let self = self else { return }
            self.finishWithError(error)
        }
    }
}
