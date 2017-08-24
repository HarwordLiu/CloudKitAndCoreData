//
//  FetchRecordChangesForCloudKitZoneOperation.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/17/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import CloudKit
import CoreData

class FetchRecordChangesForCloudKitZoneOperation: CKFetchRecordChangesOperation {
    
    var changedRecords: [CKRecord]
    var deletedRecordIDs: [CKRecordID]
    var operationError: NSError?
    fileprivate let cloudKitZone: CloudKitZone
    
    init(cloudKitZone: CloudKitZone) {
        
        self.cloudKitZone = cloudKitZone
        
        self.changedRecords = []
        self.deletedRecordIDs = []
        
        super.init()
        self.recordZoneID = cloudKitZone.recordZoneID()
        self.previousServerChangeToken = getServerChangeToken(cloudKitZone)
    }
    
    override func main() {
        
        print("FetchCKRecordChangesForCloudKitZoneOperation.main() - \(String(describing: previousServerChangeToken))")
        
        setOperationBlocks()
        super.main()
    }
    
    // MARK: Set operation blocks
    func setOperationBlocks() {
        
        recordChangedBlock = {
            [unowned self]
            (record: CKRecord) -> Void in
            
            print("Record changed: \(record)")
            self.changedRecords.append(record)
        }
        
        recordWithIDWasDeletedBlock = {
            [unowned self]
            (recordID: CKRecordID) -> Void in
            
            print("Record deleted: \(recordID)")
            self.deletedRecordIDs.append(recordID)
        }
        
        fetchRecordChangesCompletionBlock = {
            [unowned self]
            (serverChangeToken: CKServerChangeToken?, clientChangeToken: Data?, error: NSError?) -> Void in
            
            if let operationError = error {
                print("SyncRecordChangesToCoreDataOperation resulted in an error: \(String(describing: error))")
                self.operationError = operationError
            }
            else {
                self.setServerChangeToken(self.cloudKitZone, serverChangeToken: serverChangeToken)
            }
        } as? (CKServerChangeToken?, Data?, Error?) -> Void
    }

    // MARK: Change token user default methods
    func getServerChangeToken(_ cloudKitZone: CloudKitZone) -> CKServerChangeToken? {
        
        let encodedObjectData = UserDefaults.standard.object(forKey: cloudKitZone.serverTokenDefaultsKey()) as? Data
        
        if let encodedObjectData = encodedObjectData {
            return NSKeyedUnarchiver.unarchiveObject(with: encodedObjectData) as? CKServerChangeToken
        }
        else {
            return nil
        }
    }
    
    func setServerChangeToken(_ cloudKitZone: CloudKitZone, serverChangeToken: CKServerChangeToken?) {
        
        if let serverChangeToken = serverChangeToken {
            UserDefaults.standard.set(NSKeyedArchiver.archivedData(withRootObject: serverChangeToken), forKey:cloudKitZone.serverTokenDefaultsKey())
        }
        else {
            UserDefaults.standard.set(nil, forKey:cloudKitZone.serverTokenDefaultsKey())
        }
    }
}
