//
//  SaveChangedRecordsToCoreDataOperation.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/17/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import CloudKit
import CoreData

class SaveChangedRecordsToCoreDataOperation: Operation {
    
    var changedRecords: [CKRecord]
    var deletedRecordIDs: [CKRecordID]
    fileprivate var rootRecords: [CKRecord]
    fileprivate var noteRecords: [CKRecord]
    fileprivate let coreDataManager: CoreDataManager
    

    init(coreDataManager: CoreDataManager) {
        
        // set the coreDataManager here
        self.coreDataManager = coreDataManager
        
        // set the default values
        self.changedRecords = []
        self.deletedRecordIDs = []
        self.rootRecords = []
        self.noteRecords = []
    }
    
    override func main() {
        
        print("SaveChangedRecordsToCoreDataOperation.main()")
        
        // this is where we set the correct managedObjectContext
        let managedObjectContext = self.coreDataManager.createBackgroundManagedContext()
        
        managedObjectContext.performAndWait {
            [unowned self] in
            
            // loop through changed records and filter our child records
            for record in self.changedRecords {
                if let modelObjecType = ModelObjectType(rawValue: record.recordType) {
                    
                    if modelObjecType == ModelObjectType.Note {
                        self.noteRecords.append(record)
                    }
                    else {
                        self.rootRecords.append(record)
                    }
                }
            }
            
            // loop through all the changed root records first and insert or update them in core data
            for record in self.rootRecords {
                self.saveRecordToCoreData(record, managedObjectContext: managedObjectContext)
            }
            
            // loop through all the changed child records next and insert or update them in core data
            for record in self.noteRecords {
                self.saveRecordToCoreData(record, managedObjectContext: managedObjectContext)
            }
            
            // loop through all the deleted recordIDs and delete the objects from core data
            for recordID in self.deletedRecordIDs {
                self.deleteRecordFromCoreData(recordID, managedObjectContext: managedObjectContext)
            }
            
            // save the context
            self.coreDataManager.saveBackgroundManagedObjectContext(managedObjectContext)
        }
    }
    
    fileprivate func saveRecordToCoreData(_ record: CKRecord, managedObjectContext: NSManagedObjectContext) {
        
        print("saveRecordToCoreData: \(record.recordType)")
        let fetchRequest = createFetchRequest(record.recordType, recordName: record.recordID.recordName)
        
        if let cloudKitManagedObject = fetchObject(fetchRequest, managedObjectContext: managedObjectContext) {
            print("UPDATE CORE DATA OBJECT")
            cloudKitManagedObject.updateWithRecord(record)
        }
        else {
            print("NEW CORE DATA OBJECT")
            let cloudKitManagedObject = createNewCloudKitManagedObject(record.recordType, managedObjectContext: managedObjectContext)
            cloudKitManagedObject.updateWithRecord(record)
        }
    }
    
    fileprivate func createFetchRequest(_ entityName: String, recordName: String) -> NSFetchRequest<NSFetchRequestResult> {
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "recordName LIKE[c] %@", recordName)
        
        return fetchRequest
    }
    
    fileprivate func fetchObject(_ fetchRequest: NSFetchRequest<NSFetchRequestResult>, managedObjectContext: NSManagedObjectContext) -> CloudKitManagedObject? {
        
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
    
    fileprivate func createNewCloudKitManagedObject(_ entityName: String, managedObjectContext: NSManagedObjectContext) -> CloudKitManagedObject {
        
        guard let newCloudKitManagedObject = NSEntityDescription.insertNewObject(forEntityName: entityName, into: managedObjectContext) as? CloudKitManagedObject else {
            fatalError("SaveChangedRecordsToCoreDataOperation: could not create object")
        }
        
        return newCloudKitManagedObject
    }
    
    fileprivate func deleteRecordFromCoreData(_ recordID: CKRecordID, managedObjectContext: NSManagedObjectContext) {
        
        let entityName = entityNameFromRecordName(recordID.recordName)
        let fetchRequest = createFetchRequest(entityName, recordName: recordID.recordName)
        
        if let cloudKitManagedObject = fetchObject(fetchRequest, managedObjectContext: managedObjectContext) {
            print("DELETE CORE DATA OBJECT: \(cloudKitManagedObject)")
            managedObjectContext.delete(cloudKitManagedObject as! NSManagedObject)
        }
    }
    
    fileprivate func entityNameFromRecordName(_ recordName: String) -> String {
        
        guard let index = recordName.characters.index(of: ".") else {
            fatalError("ERROR - RecordID.recordName does not contain an entity prefix")
        }
        
        let entityName = recordName.substring(to: index)
        
        guard let managedObjectType = ModelObjectType(rawValue: entityName) else {
            fatalError("ERROR - unknown managedObjectType: \(entityName)")
        }
        
        return managedObjectType.rawValue
    }
}
