//
//  CoreDataManager.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 12/12/15.
//  Copyright © 2015 Nick Harris. All rights reserved.
//

import CoreData
import CloudKit

typealias networkOperationResult = (_ success: Bool, _ errorMessage: String?) -> Void

class CoreDataManager: NSObject {
    
    var mainThreadManagedObjectContext: NSManagedObjectContext
    var cloudKitManager: CloudKitManager?
    fileprivate var privateObjectContext: NSManagedObjectContext
    fileprivate let coordinator: NSPersistentStoreCoordinator
    
    init(closure:@escaping ()->()) {
        
        guard let modelURL = Bundle.main.url(forResource: "CoreDataModel", withExtension: "momd"),
            let managedObjectModel = NSManagedObjectModel.init(contentsOf: modelURL)
            else {
                fatalError("CoreDataManager - COULD NOT INIT MANAGED OBJECT MODEL")
        }
        
        coordinator = NSPersistentStoreCoordinator.init(managedObjectModel: managedObjectModel)
        
        mainThreadManagedObjectContext = NSManagedObjectContext.init(concurrencyType: NSManagedObjectContextConcurrencyType.mainQueueConcurrencyType)
        privateObjectContext = NSManagedObjectContext.init(concurrencyType: NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
        
        privateObjectContext.persistentStoreCoordinator = coordinator
        mainThreadManagedObjectContext.persistentStoreCoordinator = coordinator
        
        super.init()
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {
            [unowned self] in
            
            let options = [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true,
                NSSQLitePragmasOption: ["journal_mode": "DELETE"]
            ] as [String : Any]
            
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last
            let storeURL = URL.init(string: "coredatamodel.sqlite", relativeTo: documentsURL)
            
            do {
                try self.coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
                
                DispatchQueue.main.async {
                    closure()
                }
            }
            catch let error as NSError {
                fatalError("CoreDataManager - COULD NOT INIT SQLITE STORE: \(error.localizedDescription)")
            }
        }
        
        cloudKitManager = CloudKitManager(coreDataManager: self)
        
        NotificationCenter.default.addObserver(self, selector: #selector(CoreDataManager.mergeContext(_:)), name:NSNotification.Name.NSManagedObjectContextDidSave , object: nil)
    }
    
    func mergeContext(_ notification: Notification) {
        
        let sender = notification.object as! NSManagedObjectContext
        
        if sender != mainThreadManagedObjectContext {
            mainThreadManagedObjectContext.performAndWait {
                [unowned self] in
                
                print("mainThreadManagedObjectContext.mergeChangesFromContextDidSaveNotification")
                self.mainThreadManagedObjectContext.mergeChanges(fromContextDidSave: notification)
            }
        }
    }
    
    func createBackgroundManagedContext() -> NSManagedObjectContext {
        
        let backgroundManagedObjectContext = NSManagedObjectContext.init(concurrencyType: NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
        backgroundManagedObjectContext.persistentStoreCoordinator = coordinator
        backgroundManagedObjectContext.undoManager = nil
        return backgroundManagedObjectContext
    }
    
    func save() {
        
        let insertedObjects = mainThreadManagedObjectContext.insertedObjects
        let modifiedObjects = mainThreadManagedObjectContext.updatedObjects
        let deletedRecordIDs = mainThreadManagedObjectContext.deletedObjects.flatMap { ($0 as? CloudKitManagedObject)?.cloudKitRecordID() }
        
        if privateObjectContext.hasChanges || mainThreadManagedObjectContext.hasChanges {
            
            self.mainThreadManagedObjectContext.performAndWait {
                [unowned self] in
                
                do {
                    try self.mainThreadManagedObjectContext.save()
                    self.savePrivateObjectContext()
                }
                catch let error as NSError {
                    fatalError("CoreDataManager - SAVE MANAGEDOBJECTCONTEXT FAILED: \(error.localizedDescription)")
                }
                
                let insertedManagedObjectIDs = insertedObjects.flatMap { $0.objectID }
                let modifiedManagedObjectIDs = modifiedObjects.flatMap { $0.objectID }
                
                self.cloudKitManager?.saveChangesToCloudKit(insertedManagedObjectIDs, modifiedManagedObjectIDs: modifiedManagedObjectIDs, deletedRecordIDs: deletedRecordIDs)
            }
        }
    }
    
    func saveBackgroundManagedObjectContext(_ backgroundManagedObjectContext: NSManagedObjectContext) {
        
        if backgroundManagedObjectContext.hasChanges {
            do {
                try backgroundManagedObjectContext.save()
            }
            catch let error as NSError {
                fatalError("CoreDataManager - save backgroundManagedObjectContext ERROR: \(error.localizedDescription)")
            }
        }
    }
    
    func sync() {
        cloudKitManager?.performFullSync()
    }
    
    internal func savePrivateObjectContext() {
        
        privateObjectContext.performAndWait {
            [unowned self] in
            
            print("savePrivateObjectContext")
            do {
                try self.privateObjectContext.save()
            }
            catch let error as NSError {
                fatalError("CoreDataManager - SAVE PRIVATEOBJECTCONTEXT FAILED: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: Fetch CloudKitManagedObjects from Context by NSManagedObjectID
    func fetchCloudKitManagedObjects(_ managedObjectContext: NSManagedObjectContext, managedObjectIDs: [NSManagedObjectID]) -> [CloudKitManagedObject] {
        
        var cloudKitManagedObjects: [CloudKitManagedObject] = []
        for managedObjectID in managedObjectIDs {
            do {
                let managedObject = try managedObjectContext.existingObject(with: managedObjectID)
                
                if let cloudKitManagedObject = managedObject as? CloudKitManagedObject {
                    cloudKitManagedObjects.append(cloudKitManagedObject)
                }
            }
            catch let error as NSError {
                print("Error fetching from CoreData: \(error.localizedDescription)")
            }
        }
        
        return cloudKitManagedObjects
    }
}
