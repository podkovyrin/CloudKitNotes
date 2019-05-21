//
//  Copyright © 2015 Apple Inc. All Rights Reserved.
//  See LICENSE.txt for this sample’s licensing information
//
//  Modified by Andrew Podkovyrin, 2019
//

import CloudKit
import Foundation

extension CKContainer {
    /**
     Verify that the current user has certain permissions for the `CKContainer`,
     and potentially requesting the permission if necessary.

     - parameter permission: The permissions to be verified on the container.

     - parameter shouldRequest: If this value is `true` and the user does not
     have the passed `permission`, then the user will be prompted for it.

     - parameter completion: A closure that will be executed after verification
     completes. The `Error` passed in to the closure is the result of either
     retrieving the account status, or requesting permission, if either
     operation fails. If the verification was successful, this value will
     be `nil`.
     */
    func verify(_ permission: CKContainer.Application.Permissions = [],
                request shouldRequest: Bool = false,
                completion: @escaping (Error?) -> Void) {
        verifyAccountStatus(self, permission: permission, shouldRequest: shouldRequest, completion: completion)
    }
}

/**
 Make these helper functions instead of helper methods, so we don't pollute
 `CKContainer`.
 */
private func verifyAccountStatus(_ container: CKContainer,
                                 permission: CKContainer.Application.Permissions,
                                 shouldRequest: Bool,
                                 completion: @escaping (Error?) -> Void) {
    container.accountStatus { accountStatus, error in
        // since CloudKit does not return error for `noAccount` status
        // we provide fallback errors
        switch accountStatus {
        case .couldNotDetermine:
            completion(error ?? CKError(.internalError))
        case .available:
            if permission != [] {
                verifyPermission(container,
                                 permission: permission,
                                 shouldRequest: shouldRequest,
                                 completion: completion)
            }
            else {
                completion(nil)
            }
        case .restricted:
            completion(error ?? CKError(.managedAccountRestricted))
        case .noAccount:
            completion(error ?? CKError(.notAuthenticated))
        @unknown default:
            fatalError("Unhandled account status")
        }
    }
}

private func verifyPermission(_ container: CKContainer,
                              permission: CKContainer.Application.Permissions,
                              shouldRequest: Bool,
                              completion: @escaping (Error?) -> Void) {
    container.status(forApplicationPermission: permission) { permissionStatus, error in
        if permissionStatus == .granted {
            completion(nil)
        }
        else if permissionStatus == .initialState && shouldRequest {
            requestPermission(container, permission: permission, completion: completion)
        }
        else {
            completion(error)
        }
    }
}

private func requestPermission(_ container: CKContainer,
                               permission: CKContainer.Application.Permissions,
                               completion: @escaping (Error?) -> Void) {
    DispatchQueue.main.async {
        container.requestApplicationPermission(permission) { requestStatus, error in
            if requestStatus == .granted {
                completion(nil)
            }
            else {
                completion(error)
            }
        }
    }
}
