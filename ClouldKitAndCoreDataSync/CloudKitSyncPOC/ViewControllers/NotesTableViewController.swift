//
//  NotesTableViewController.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 12/12/15.
//  Copyright © 2015 Nick Harris. All rights reserved.
//

import UIKit
import CoreData

class NotesTableViewController: UITableViewController, CoreDataManagerViewController, NSFetchedResultsControllerDelegate {
    
    var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>?
    var modelObjectType: ModelObjectType?
    var managedObject: CTBRootManagedObject?
    var car: Car? {
        didSet {
            if let car = car {
                managedObject = car as CTBRootManagedObject
            }
        }
    }
    var truck: Truck? {
        didSet {
            if let truck = truck {
                managedObject = truck as CTBRootManagedObject
            }
        }
    }
    var bus: Bus? {
        didSet {
            if let bus = bus {
                managedObject = bus as CTBRootManagedObject
            }
        }
    }
    var coreDataManager: CoreDataManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if coreDataManager != nil {
            configureFetchedResultsController()
        }
    }
    
    // NSFetchedResultsController
    func configureFetchedResultsController() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Note")
        let nameSortDescriptor = NSSortDescriptor(key: "added", ascending: true)
        
        fetchRequest.sortDescriptors = [nameSortDescriptor]
        fetchRequest.predicate = configureFetchPredicate()
        
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
            fatalError("NotesTableViewController - configureFetchedResultsController: fetch failed \(error.localizedDescription)")
        }
        
        tableView.reloadData()
    }
    
    func configureFetchPredicate() -> NSPredicate {
        if let car = car {
            return NSPredicate.init(format: "car == %@", car)
        }
        else if let truck = truck {
            return NSPredicate.init(format: "truck == %@", truck)
        }
        else if let bus = bus {
            return NSPredicate.init(format: "bus == %@", bus)
        }
        
        fatalError("NotesTableViewController: no suitable parent object found while configuring the FRC")
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
        if let noteListCell = tableView.dequeueReusableCell(withIdentifier: NoteListCell.ReuseID) as? NoteListCell,
            let note = fetchedResultsController?.object(at: indexPath) as? Note {
                noteListCell.configureCell(note)
                return noteListCell
        }
        else {
            fatalError("NotesTableViewController: Unexpected Cell Type")
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if let note = fetchedResultsController?.object(at: indexPath) as? Note {
                
                if let cloudKitManagedObject = managedObject as? CloudKitManagedObject {
                    cloudKitManagedObject.addDeletedCloudKitObject()
                }
                
                coreDataManager?.mainThreadManagedObjectContext.delete(note)
                coreDataManager?.save()
            }
        }
    }
    
    // MARK: UITableViewDelegate
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .delete
    }
    
    // MARK: NSFetchedResultsControllerDelegate
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            guard let newIndexPath = newIndexPath else {
                fatalError("NotesTableViewController: nil indexpath")
            }
            tableView.insertRows(at: [newIndexPath], with: .fade)
            
        case .update:
            guard let indexPath = indexPath,
                let noteListCell = tableView.cellForRow(at: indexPath) as? NoteListCell,
                let note = anObject as? Note else {
                    fatalError("NotesTableViewController: not enough data to update a cell")
            }
            noteListCell.configureCell(note)
            
        case .delete:
            guard let indexPath = indexPath else {
                fatalError("NotesTableViewController: nil indexpath")
            }
            tableView.deleteRows(at: [indexPath], with: .fade)
            
        case .move:
            guard let newIndexPath = newIndexPath,
                let indexPath = indexPath else {
                    fatalError("NotesTableViewController: not enough data to move a cell")
            }
            tableView.deleteRows(at: [indexPath], with: .fade)
            tableView.insertRows(at: [newIndexPath], with: .fade)
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
    
    // MARK: IBOutlet
    @IBAction func addNoteAction() {
        performSegue(withIdentifier: "NoteDetailsSegue", sender: nil)
    }
   
    // MARK: Segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        // set the coreDataManager either on the root of a UINavigationController or on the segue destination itself
        if var destinationCoreDataViewController = segue.destination as? CoreDataManagerViewController {
            destinationCoreDataViewController.coreDataManager = coreDataManager
            destinationCoreDataViewController.modelObjectType = modelObjectType
        }
        
        if let noteDetailsViewController = segue.destination as? NoteDetailsViewController {
            noteDetailsViewController.car = car
            noteDetailsViewController.truck = truck
            noteDetailsViewController.bus = bus
            
            if let tableViewCell = sender as? UITableViewCell,
                let indexPath = tableView?.indexPath(for: tableViewCell),
                let note = fetchedResultsController?.object(at: indexPath) as? Note
            {
                noteDetailsViewController.note = note
            }
            
            DispatchQueue.main.async(execute: {
                [unowned self] in
                
                self.transitionCoordinator?.animate(alongsideTransition: nil, completion: { (UIViewControllerTransitionCoordinatorContext) -> Void in
                    noteDetailsViewController.setFirstResponder()
                })
            })
        }
    }
}

class NoteListCell: UITableViewCell {
    class var ReuseID: String { return "NoteListCellID" }
    
    func configureCell(_ note: Note) {
        textLabel?.text = note.text
    }
}
