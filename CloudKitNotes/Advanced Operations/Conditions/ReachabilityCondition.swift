//
//  Copyright © 2015 Apple Inc. All Rights Reserved.
//  See LICENSE.txt for this sample’s licensing information
//
//  Modified by Andrew Podkovyrin, 2019
//

import Foundation
import SystemConfiguration

/**
 This is a condition that performs a very high-level reachability check.
 It does *not* perform a long-running reachability check, nor does it respond to changes in reachability.
 Reachability is evaluated once when the operation to which this is attached is asked about its readiness.
 */
struct ReachabilityCondition: OperationCondition {
    static let name = "Reachability"
    static let isMutuallyExclusive = false

    let host: URL

    init(host: URL) {
        self.host = host
    }

    func dependency(for operation: ANOperation) -> Operation? {
        return nil
    }

    func evaluate(for operation: ANOperation, completion: @escaping (OperationConditionResult) -> Void) {
        ReachabilityController.requestReachability(host) { reachable in
            if reachable {
                completion(.success)
            }
            else {
                let error = OperationError.reachabilityConditionFailed(host: self.host)
                completion(.failure(error))
            }
        }
    }
}

/// A private singleton that maintains a basic cache of `SCNetworkReachability` objects.
private class ReachabilityController {
    static var reachabilityRefs = [String: SCNetworkReachability]()

    static let reachabilityQueue = DispatchQueue(label: "Operations.Reachability", qos: .default, attributes: [])

    static func requestReachability(_ url: URL, completionHandler: @escaping (Bool) -> Void) {
        guard let host = url.host else {
            completionHandler(false)
            return
        }

        reachabilityQueue.async {
            var ref = self.reachabilityRefs[host]

            if ref == nil {
                let hostString = host as NSString
                if let nodename = hostString.utf8String {
                    ref = SCNetworkReachabilityCreateWithName(nil, nodename)
                }
            }

            if let ref = ref {
                self.reachabilityRefs[host] = ref

                var reachable = false
                var flags: SCNetworkReachabilityFlags = []
                if SCNetworkReachabilityGetFlags(ref, &flags) {
                    /*
                     Note that this is a very basic "is reachable" check.
                     Your app may choose to allow for other considerations,
                     such as whether or not the connection would require
                     VPN, a cellular connection, etc.
                     */
                    reachable = flags.contains(.reachable)
                }
                completionHandler(reachable)
            }
            else {
                completionHandler(false)
            }
        }
    }
}
