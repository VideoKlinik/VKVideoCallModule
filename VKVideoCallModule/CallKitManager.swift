//
//  CallKitManager.swift
//  Sante
//
//  Created by Caglar Cakar on 10.09.2019.
//  Copyright © 2019 Dijital Garaj. All rights reserved.
//

import Foundation
import CallKit

class CallKitManager: NSObject {
    var callKitProvider: CXProvider!
    var callKitCallController: CXCallController!
    var UUID:UUID!
}

