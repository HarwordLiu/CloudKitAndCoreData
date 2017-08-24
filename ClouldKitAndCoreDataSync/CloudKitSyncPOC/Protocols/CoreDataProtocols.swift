//
//  CoreDataProtocols.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/12/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import Foundation

protocol CoreDataManagerViewController {
    var coreDataManager: CoreDataManager? { get set }
    var modelObjectType: ModelObjectType? { get set }
}

@objc protocol CTBRootManagedObject {
    var name: String? { get set }
    var added: Date? { get set }
    var lastUpdate: Date? { get set }
    var notes: NSSet? { get set }
}
