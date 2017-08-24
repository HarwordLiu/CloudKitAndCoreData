//
//  ObjectTableViewController.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 12/12/15.
//  Copyright © 2015 Nick Harris. All rights reserved.
//

import UIKit
import CoreData

class ObjectTableViewController: UITableViewController, CoreDataManagerViewController, NSFetchedResultsControllerDelegate {
    
    lazy var coreDataEntityName: String = self.getCoreDataObjectName()
    func getCoreDataObjectName() -> String {
        guard let restorationIdentifier = restorationIdentifier,
            let objectType = ModelObjectType.init(storyboardRestorationID: restorationIdentifier) else {
                fatalError("Tabbar view setup without a known restorationIdentifier")
        }
        
        modelObjectType = objectType
        return objectType.rawValue
    }
    
    var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>?
    var modelObjectType: ModelObjectType?
    var coreDataManager: CoreDataManager? {
        didSet {
            if isViewLoaded {
                configureFetchedResultsController()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if coreDataManager != nil {
            configureFetchedResultsController()
        }
    }
    
    func configureFetchedResultsController() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: coreDataEntityName)
        let nameSortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        
        fetchRequest.sortDescriptors = [nameSortDescriptor]
        
        if let managedObjectContext = coreDataManager?.mainThreadManagedObjectContext {
            fetchedResultsController = NSFetchedResultsController(
                fetchRequest: fetchRequest,
                managedObjectContext: managedObjectContext,
                sectionNameKeyPath: nil,
                cacheName: nil)
        }
        
        fetchedResultsController?.delegate = self
        
        do {
            try fetchedResultsController?.performFetch()
        }
        catch let error as NSError {
            fatalError("ObjectTableViewController - configureFetchedResultsController: fetch failed \(error.localizedDescription)")
        }
        
        tableView.reloadData()
    }
    
    // MARK: IBAction
    @IBAction func addObjectAction() {
        performSegue(withIdentifier: "DetailsObjectSegue", sender: nil)
    }
    
    @IBAction func refresh() {
        coreDataManager?.sync()
    }
    
    // MARK: NSFetchedResultsControllerDelegate
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            guard let newIndexPath = newIndexPath else {
                fatalError("ObjectTableViewController: nil indexpath")
            }
            tableView.insertRows(at: [newIndexPath], with: .fade)
            
        case .update:
            guard let indexPath = indexPath,
                let objectListCell = tableView.cellForRow(at: indexPath) as? ObjectListCell,
                let managedObject = anObject as? NSManagedObject,
                let ctbRootObject = managedObject as? CTBRootManagedObject else {
                    fatalError("ObjectTableViewController: not enough data to update a cell")
            }
            objectListCell.configureCell(ctbRootObject)
            
        case .delete:
            guard let indexPath = indexPath else {
                fatalError("ObjectTableViewController: nil indexpath")
            }
            tableView.deleteRows(at: [indexPath], with: .fade)
            
        case .move:
            guard let newIndexPath = newIndexPath,
                let indexPath = indexPath else {
                    fatalError("ObjectTableViewController: not enough data to move a cell")
            }
            tableView.deleteRows(at: [indexPath], with: .fade)
            tableView.insertRows(at: [newIndexPath], with: .fade)
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
    
    // MARK: UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let numberOfObjects = fetchedResultsController?.fetchedObjects?.count {
            return numberOfObjects
        }
        
        return 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let objectListCell = tableView.dequeueReusableCell(withIdentifier: ObjectListCell.ReuseID) as? ObjectListCell,
           let managedObject = fetchedResultsController?.object(at: indexPath) as? NSManagedObject,
           let ctbRootObject = managedObject as? CTBRootManagedObject {
                objectListCell.configureCell(ctbRootObject)
                return objectListCell
            }
        else {
            fatalError("ObjectTableViewController: Unexpected Cell Type")
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if let managedObject = fetchedResultsController?.object(at: indexPath) as? NSManagedObject {
                
                if let cloudKitManagedObject = managedObject as? CloudKitManagedObject {
                    cloudKitManagedObject.addDeletedCloudKitObject()
                }
                
                coreDataManager?.mainThreadManagedObjectContext.delete(managedObject)
                coreDataManager?.save()
            }
        }
    }
    
    // MARK: UITableViewDelegate
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .delete
    }
    
    // MARK: Segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        // set the coreDataManager either on the root of a UINavigationController or on the segue destination itself
        if var destinationCoreDataViewController = segue.destination as? CoreDataManagerViewController {
            destinationCoreDataViewController.coreDataManager = coreDataManager
            destinationCoreDataViewController.modelObjectType = modelObjectType
        }
        
        if let detailsViewController = segue.destination as? DetailsViewController {
            if let tableViewCell = sender as? UITableViewCell,
               let indexPath = tableView?.indexPath(for: tableViewCell)
            {
                if let car = fetchedResultsController?.object(at: indexPath) as? Car {
                    detailsViewController.car = car
                }
                else if let truck = fetchedResultsController?.object(at: indexPath) as? Truck {
                    detailsViewController.truck = truck
                }
                else if let bus = fetchedResultsController?.object(at: indexPath) as? Bus {
                    detailsViewController.bus = bus
                }
            }
            
            DispatchQueue.main.async(execute: {
                [unowned self] in
                
                self.transitionCoordinator?.animate(alongsideTransition: nil, completion: { (UIViewControllerTransitionCoordinatorContext) -> Void in
                    detailsViewController.setFirstResponder()
                })
            })
        }
    }
}

class ObjectListCell: UITableViewCell {
    class var ReuseID: String { return "ObjectListCellID" }
    
    func configureCell(_ object: CTBRootManagedObject) {
        textLabel?.text = object.name
    }
}
