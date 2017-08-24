//
//  FetchOfflineChangesFromCoreDataOperation.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/27/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import CoreData
import CloudKit

class FetchOfflineChangesFromCoreDataOperation: Operation {
    
    var updatedManagedObjects: [NSManagedObjectID]
    var deletedRecordIDs: [CKRecordID]
    
    fileprivate let coreDataManager: CoreDataManager
    fileprivate let cloudKitManager: CloudKitManager
    fileprivate let entityNames: [String]
    
    init(coreDataManager: CoreDataManager, cloudKitManager: CloudKitManager, entityNames: [String]) {
        
        self.coreDataManager = coreDataManager
        self.cloudKitManager = cloudKitManager
        self.entityNames = entityNames
        
        self.updatedManagedObjects = []
        self.deletedRecordIDs = []
        
        super.init()
    }

    override func main() {
        
        print("FetchOfflineChangesFromCoreDataOperation.main()")
        
        let managedObjectContext = coreDataManager.createBackgroundManagedContext()
        
        managedObjectContext.performAndWait {
            [unowned self] in
            
            let lastCloudKitSyncTimestamp = self.cloudKitManager.lastCloudKitSyncTimestamp
            
            for entityName in self.entityNames {
                self.fetchOfflineChangesForEntityName(entityName, lastCloudKitSyncTimestamp: lastCloudKitSyncTimestamp, managedObjectContext: managedObjectContext)
            }
            
            self.deletedRecordIDs = self.fetchDeletedRecordIDs(managedObjectContext)
        }
    }
    
    func fetchOfflineChangesForEntityName(_ entityName: String, lastCloudKitSyncTimestamp: Date, managedObjectContext: NSManagedObjectContext) {
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "lastUpdate > %@", lastCloudKitSyncTimestamp as CVarArg)
        
        do {
            let fetchResults = try managedObjectContext.fetch(fetchRequest)
            let managedObjectIDs = fetchResults.flatMap() { ($0 as? NSManagedObject)?.objectID  }
            
            updatedManagedObjects.append(contentsOf: managedObjectIDs)
        }
        catch let error as NSError {
            print("Error fetching from CoreData: \(error.localizedDescription)")
        }
    }
    
    func fetchDeletedRecordIDs(_ managedObjectContext: NSManagedObjectContext) -> [CKRecordID] {
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ModelObjectType.DeletedCloudKitObject.rawValue)
        
        do {
            let fetchResults = try managedObjectContext.fetch(fetchRequest)
            return fetchResults.flatMap() { ($0 as? DeletedCloudKitObject)?.cloudKitRecordID()  }
        }
        catch let error as NSError {
            print("Error fetching from CoreData: \(error.localizedDescription)")
        }
        
        return []
    }
}
