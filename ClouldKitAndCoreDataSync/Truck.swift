//
//  Truck.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 12/12/15.
//  Copyright © 2015 Nick Harris. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

class Truck: NSManagedObject, CTBRootManagedObject, CloudKitManagedObject {

    var recordType: String { return  ModelObjectType.Truck.rawValue }
    
    func managedObjectToRecord(_ record: CKRecord?) -> CKRecord {
        guard let name = name,
            let added = added,
            let lastUpdate = lastUpdate else {
                fatalError("Required properties for record not set")
        }
        let truckRecord = cloudKitRecord(record, parentRecordZoneID: nil)
        
        recordName = truckRecord.recordID.recordName
        recordID = NSKeyedArchiver.archivedData(withRootObject: truckRecord.recordID)
        
        truckRecord["name"] = name as CKRecordValue
        truckRecord["added"] = added as CKRecordValue
        truckRecord["lastUpdate"] = lastUpdate as CKRecordValue
        
        return truckRecord
    }

    func updateWithRecord(_ record: CKRecord) {
        name = record["name"] as? String
        added = record["added"] as? Date
        lastUpdate = record["lastUpdate"] as? Date
        recordName = record.recordID.recordName
        recordID = NSKeyedArchiver.archivedData(withRootObject: record.recordID)
    }
}
