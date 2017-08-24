//
//  FetchCKRecordsFromManagedObjects.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/15/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import CloudKit
import CoreData

class FetchRecordsForModifiedObjectsOperation: CKFetchRecordsOperation {

    var fetchedRecords: [CKRecordID : CKRecord]?
    var preFetchModifiedRecords: [CKRecord]?
    fileprivate let coreDataManager: CoreDataManager
    fileprivate let modifiedManagedObjectIDs: [NSManagedObjectID]?
    
    init(coreDataManager: CoreDataManager, modifiedManagedObjectIDs: [NSManagedObjectID]) {
        
        self.coreDataManager = coreDataManager
        self.modifiedManagedObjectIDs = modifiedManagedObjectIDs
        
        super.init()
    }
    
    init (coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        self.modifiedManagedObjectIDs = nil
        super.init()
    }
    
    override func main() {
        
        print("FetchRecordsForModifiedObjectsOperation.main()")
        
        setOperationBlocks()
        
        let managedObjectContext = coreDataManager.createBackgroundManagedContext()
        
        managedObjectContext.performAndWait {
            
            if let modifiedManagedObjectIDs = self.modifiedManagedObjectIDs {
                let modifiedCloudKitObjects = self.coreDataManager.fetchCloudKitManagedObjects(managedObjectContext, managedObjectIDs: modifiedManagedObjectIDs)
                self.recordIDs = modifiedCloudKitObjects.flatMap { $0.cloudKitRecordID() }
            }
            else if let preFetchModifiedRecords = self.preFetchModifiedRecords {
                self.recordIDs = preFetchModifiedRecords.flatMap { $0.recordID }
            }
            
            super.main()
        }
    }
    
    fileprivate func setOperationBlocks() {
        
        fetchRecordsCompletionBlock = {
            [unowned self]
            (fetchedRecords: [CKRecordID : CKRecord]?, error: NSError?) -> Void in
            
            self.fetchedRecords = fetchedRecords
            print("FetchRecordsForModifiedObjectsOperation.fetchRecordsCompletionBlock - fetched \(String(describing: fetchedRecords?.count)) records")
        } as? ([CKRecordID : CKRecord]?, Error?) -> Void
    }
}
