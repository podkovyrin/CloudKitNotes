import CloudKit
import os.log

extension CKContainer {
    func accountStatus(_ log: OSLog, completion: @escaping (Error?) -> Void) {
        os_log("Verifying account status", log: log, type: .info)

        accountStatus { accountStatus, error in
            // since CloudKit does not return error for `noAccount` status we provide fallback errors
            switch accountStatus {
            case .couldNotDetermine:
                os_log("Account status: Could Not Determine", log: log, type: .info)
                completion(error ?? CKError(.internalError))
            case .available:
                os_log("Account status: Available", log: log, type: .info)
                completion(nil)
            case .restricted:
                os_log("Account status: Restricted", log: log, type: .info)
                completion(error ?? CKError(.managedAccountRestricted))
            case .noAccount:
                os_log("Account status: No Account", log: log, type: .info)
                completion(error ?? CKError(.notAuthenticated))
            @unknown default:
                preconditionFailure("Unhandled account status")
            }
        }
    }
}
