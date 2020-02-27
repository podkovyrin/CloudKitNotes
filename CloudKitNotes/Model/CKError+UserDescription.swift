//
//  CKError+Storage.swift
//  CloudKitNotes
//
//  Created by Andrew Podkovyrin on 2/28/20.
//  Copyright © 2020 AP. All rights reserved.
//

import CloudKit
import UIKit

extension CKError {
    var userDescription: String? {
        switch code {
        case .userDeletedZone:
            return NSLocalizedString("""
            Backed up data was removed from iCloud.
            """, comment: "")
        case .quotaExceeded:
            let localizedString = NSLocalizedString("""
            Not Enough Storage\nThis %@ cannot be backed up because there is not enough iCloud storage available.
            You can manage your storage in Settings.
            """, comment: "...This iPhone cannot be backed up...")
            return String(format: localizedString, UIDevice.current.model)
        case .incompatibleVersion:
            return NSLocalizedString("""
            Current app version is outdated. Please upgrade to the newest version of the app.
            """, comment: "")
        case .managedAccountRestricted, .notAuthenticated:
            return NSLocalizedString("""
            An iCloud account is required to use the backup feature.
            You can manage your iCloud account in Settings.
            """, comment: "")
        default:
            return localizedDescription
        }
    }
}
