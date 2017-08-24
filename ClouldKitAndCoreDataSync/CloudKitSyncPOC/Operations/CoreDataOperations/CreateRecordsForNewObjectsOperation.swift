//
//  CreateRecordsForNewObjectsOperation.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/22/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import CoreData
import CloudKit

class CreateRecordsForNewObjectsOperation: Operation {

    var createdRecords: [CKRecord]?
    fileprivate let insertedManagedObjectIDs: [NSManagedObjectID]
    fileprivate let coreDataManager: CoreDataManager
    
    init(insertedManagedObjectIDs: [NSManagedObjectID], coreDataManager: CoreDataManager) {
        
        self.insertedManagedObjectIDs = insertedManagedObjectIDs
        self.coreDataManager = coreDataManager
        self.createdRecords = nil
        super.init()
    }
    
    override func main() {
        
        print("CreateRecordsForNewObjectsOperation.main()")
        
        let managedObjectContext = coreDataManager.createBackgroundManagedContext()
        
        if insertedManagedObjectIDs.count > 0 {
            managedObjectContext.performAndWait {
                [unowned self] in
                
                let insertedCloudKitObjects = self.coreDataManager.fetchCloudKitManagedObjects(managedObjectContext, managedObjectIDs: self.insertedManagedObjectIDs)
                self.createdRecords = insertedCloudKitObjects.flatMap() { $0.managedObjectToRecord(.none) }
                self.coreDataManager.saveBackgroundManagedObjectContext(managedObjectContext)
            }
        }
    }
}
