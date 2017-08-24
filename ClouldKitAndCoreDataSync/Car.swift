//
//  Car.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 12/12/15.
//  Copyright © 2015 Nick Harris. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

class Car: NSManagedObject, CTBRootManagedObject, CloudKitManagedObject {
    
    var recordType: String { return  ModelObjectType.Car.rawValue }
    
    func managedObjectToRecord(_ record: CKRecord?) -> CKRecord {
        guard let name = name,
              let added = added,
              let lastUpdate = lastUpdate else {
            fatalError("Required properties for record not set")
        }
        
        let carRecord = cloudKitRecord(record, parentRecordZoneID: nil)
        
        recordName = carRecord.recordID.recordName
        recordID = NSKeyedArchiver.archivedData(withRootObject: carRecord.recordID)
        
        carRecord["name"] = name as CKRecordValue
        carRecord["added"] = added as CKRecordValue
        carRecord["lastUpdate"] = lastUpdate as CKRecordValue
        
        return carRecord
    }

    func updateWithRecord(_ record: CKRecord) {
        name = record["name"] as? String
        added = record["added"] as? Date
        lastUpdate = record["lastUpdate"] as? Date
        recordName = record.recordID.recordName
        recordID = NSKeyedArchiver.archivedData(withRootObject: record.recordID)
    }
}
