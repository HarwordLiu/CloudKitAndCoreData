//
//  Note.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 12/12/15.
//  Copyright © 2015 Nick Harris. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

class Note: NSManagedObject, CloudKitManagedObject {
    
    var recordType: String { return  ModelObjectType.Note.rawValue }

    func managedObjectToRecord(_ record: CKRecord?) -> CKRecord {
        guard let text = text,
            let added = added,
            let lastUpdate = lastUpdate else {
                fatalError("Required properties for record not set")
        }
        
        var noteRecord: CKRecord
        if let record = record {
            noteRecord = record
        }
        else {
            noteRecord = createNoteRecord()
        }
        
        noteRecord["text"] = text as CKRecordValue
        noteRecord["added"] = added as CKRecordValue
        noteRecord["lastUpdate"] = lastUpdate as CKRecordValue
        
        return noteRecord
    }
    
    func updateWithRecord(_ record: CKRecord) {
        text = record["text"] as? String
        added = record["added"] as? Date
        lastUpdate = record["lastUpdate"] as? Date
        recordName = record.recordID.recordName
        recordID = NSKeyedArchiver.archivedData(withRootObject: record.recordID)
        
        if car == .none && truck == .none && bus == .none {
            // need to set the parent object based on the CKReference in the record
            setParentObjectFromCloudKitRecord(record)
        }
    }
    
    func createNoteRecord() -> CKRecord {
        // we need to figure out what type of object the parent is
        if let car = car {
            return createNoteRecordWithParent(car)
        }
        else if let truck = truck {
            return createNoteRecordWithParent(truck)
        }
        else if let bus = bus {
            return createNoteRecordWithParent(bus)
        }
        else {
            fatalError("ERROR Have a note without a parent")
        }
    }
    
    func createNoteRecordWithParent(_ parentObject: CloudKitManagedObject) -> CKRecord {
        guard let cloudKitZone = CloudKitZone(recordType: parentObject.recordType),
              let parentRecordID = parentObject.cloudKitRecordID() else {
            fatalError("ERROR - not enough information to create a CKReference for a Note")
        }
        
        let noteRecord = cloudKitRecord(nil, parentRecordZoneID: cloudKitZone.recordZoneID())
        let parentReference = CKReference(recordID: parentRecordID, action: .deleteSelf)
        
        recordName = noteRecord.recordID.recordName
        recordID = NSKeyedArchiver.archivedData(withRootObject: noteRecord.recordID)
        
        noteRecord["parent"] = parentReference
        
        return noteRecord
    }
    
    func setParentObjectFromCloudKitRecord(_ record: CKRecord) {
        guard let cloudKitReference = record["parent"] as? CKReference,
              let managedObjectContext = managedObjectContext else {
            fatalError("ERROR - attempted to set the parent of a core data object from a CKRecord that does not have a CKReference or managedObjectContext")
        }
        
        let recordID = cloudKitReference.recordID
        let zoneName = recordID.zoneID.zoneName
        let recordName = recordID.recordName
        
        guard let cloudKitZone = CloudKitZone(rawValue: zoneName),
              let parentObject = fetchParentObject(cloudKitZone.recordType(), recordName: recordName, managedObjectContext: managedObjectContext) else {
            fatalError("ERROR - attempted to set the parent of a Note with parent that has an unexpected zone or is not in local storage")
        }
        
        switch cloudKitZone.recordType() {
        case ModelObjectType.Car.rawValue:
            car = parentObject as? Car
        case ModelObjectType.Truck.rawValue:
            truck = parentObject as? Truck
        case ModelObjectType.Bus.rawValue:
            bus = parentObject as? Bus
        default:
            fatalError("ERROR - unknown recordType from CloudKitZone")
        }
    }
    
    internal func fetchParentObject(_ entityName: String, recordName: String, managedObjectContext: NSManagedObjectContext) -> CloudKitManagedObject? {
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "recordName LIKE[c] %@", recordName)
        
        do {
            let fetchResults = try managedObjectContext.fetch(fetchRequest)
            
            guard fetchResults.count <= 1 else {
                fatalError("ERROR: Found more then one core data object with recordName")
            }
            
            if fetchResults.count == 1 {
                return fetchResults[0] as? CloudKitManagedObject
            }
        }
        catch let error as NSError {
            print("Error fetching from CoreData: \(error.localizedDescription)")
        }
        
        return nil
    }
}
