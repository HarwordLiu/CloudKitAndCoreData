//
//  Bus.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 12/12/15.
//  Copyright © 2015 Nick Harris. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

class Bus: NSManagedObject, CTBRootManagedObject, CloudKitManagedObject {

    var recordType: String { return  ModelObjectType.Bus.rawValue }
    
    func managedObjectToRecord(_ record: CKRecord?) -> CKRecord {
        guard let name = name,
            let added = added,
            let lastUpdate = lastUpdate else {
                fatalError("Required properties for record not set")
        }
        let busRecord = cloudKitRecord(record, parentRecordZoneID: nil)
        
        recordName = busRecord.recordID.recordName
        recordID = NSKeyedArchiver.archivedData(withRootObject: busRecord.recordID)
        
        busRecord["name"] = name as CKRecordValue
        busRecord["added"] = added as CKRecordValue
        busRecord["lastUpdate"] = lastUpdate as CKRecordValue
        
        return busRecord
    }
    
    func updateWithRecord(_ record: CKRecord) {
        name = record["name"] as? String
        added = record["added"] as? Date
        lastUpdate = record["lastUpdate"] as? Date
        recordName = record.recordID.recordName
        recordID = NSKeyedArchiver.archivedData(withRootObject: record.recordID)
    }

}
