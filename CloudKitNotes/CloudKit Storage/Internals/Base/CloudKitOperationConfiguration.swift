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

import ANOperations
import CloudKit
import Foundation

/// Configuration object that is needed to pass container, database and userDefaults objects
/// to the high-level CloudKit operations.
/// Also provide pre-configured operation conditions
struct CloudKitOperationConfiguration {
    let container: CKContainer
    let database: CKDatabase
    let userDefaults: UserDefaults

    var cloudContainerCondition: OperationCondition {
        CloudContainerCondition(container: container)
    }

    init(container: CKContainer,
         database: CKDatabase,
         userDefaults: UserDefaults) {
        self.container = container
        self.database = database
        self.userDefaults = userDefaults
    }
}
