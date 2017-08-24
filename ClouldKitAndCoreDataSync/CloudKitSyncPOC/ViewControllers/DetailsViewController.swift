//
//  DetailsViewController.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 12/12/15.
//  Copyright © 2015 Nick Harris. All rights reserved.
//

import UIKit
import CoreData

class DetailsViewController: UIViewController, CoreDataManagerViewController {
    
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var deleteButton: UIBarButtonItem!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var addedLabel: UILabel!
    @IBOutlet weak var lastUpdatedLabel: UILabel!
    @IBOutlet weak var notesButton: UIButton!
    
    var modelObjectType: ModelObjectType?
    var car: Car?
    var truck: Truck?
    var bus: Bus?
    var coreDataManager: CoreDataManager?
    var dateFormatter = DateFormatter()
    var hasObject: Bool = false
    let noNameErrorMessage = "Please supply a name"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dateFormatter.dateStyle = DateFormatter.Style.short
        dateFormatter.timeStyle = DateFormatter.Style.medium
        
        NotificationCenter.default.addObserver(self, selector: #selector(DetailsViewController.managedObjectContextChanged(_:)), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: coreDataManager?.mainThreadManagedObjectContext)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupView()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func managedObjectContextChanged(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            // we don't care about inserted objects in this view
            if let updatedObjects = userInfo[NSUpdatedObjectsKey] {
                checkForUpdate(updatedObjects as! Set<NSManagedObject>)
            }
            if let refreshed = userInfo[NSRefreshedObjectsKey] {
                checkForUpdate(refreshed as! Set<NSManagedObject>)
            }
            if let deletedObjects = userInfo[NSDeletedObjectsKey] {
                checkIfDeleted(deletedObjects as! Set<NSManagedObject>)
            }
        }
    }
    
    func checkForUpdate(_ updatedObjects: Set<NSManagedObject>) {
        if let rootObject = modelObject(),
           let managedObject = rootObject as? NSManagedObject,
           let updatedObjectIndex = updatedObjects.index(of: managedObject) {
            let updatedObject = updatedObjects[updatedObjectIndex]
            setLabels(updatedObject as! CTBRootManagedObject)
        }
    }
    
    func checkIfDeleted(_ deletedObjects: Set<NSManagedObject>) {
        if let rootObject = modelObject(),
            let managedObject = rootObject as? NSManagedObject {
                if deletedObjects.contains(managedObject) {
                    navigationController?.popViewController(animated: true)
                }
        }
    }
    
    // MARK: Setup the view
    func setupView() {
        if let modelObject = modelObject()  {
            setLabels(modelObject)
        }
        else {
            // new item, disable the delete and notes buttons
            deleteButton.isEnabled = false
            notesButton.isEnabled = false
            addedLabel.text = ""
            lastUpdatedLabel.text = ""
        }
    }
    
    func modelObject() -> CTBRootManagedObject? {
        if let managedObject = car {
            return managedObject
        }
        else if let managedObject = truck {
            return managedObject
        }
        else if let managedObject = bus {
            return managedObject
        }
        else {
            return nil
        }
    }
    
    func setLabels(_ managedObject: CTBRootManagedObject) {
        hasObject = true
        deleteButton.isEnabled = true
        notesButton.isEnabled = true
        nameTextField.text = managedObject.name
        if let added = managedObject.added,
            let lastUpdated = managedObject.lastUpdate {
                addedLabel.text = dateFormatter.string(from: added)
                lastUpdatedLabel.text = dateFormatter.string(from: lastUpdated)
        }
    }
    
    func setFirstResponder() {
        if car == nil && truck == nil && bus == nil {
            // new item, set the text field as the first responder
            nameTextField.becomeFirstResponder()
        }
    }
    
    // MARK: Validate and Save
    @IBAction func saveAction() {
        let validationResult = validateProject()
        
        if let errorMessage = validationResult.errorMessage {
            showErrorAlert(errorMessage) {
                if let safeInputView = validationResult.inputView {
                    safeInputView.becomeFirstResponder()
                }
            }
        }
        else {
            saveObject()
        }
    }
    
    func validateProject() -> (errorMessage: String?, inputView: UIView?) {
        guard let objectName = nameTextField.text else {
            return (noNameErrorMessage, nameTextField)
        }
        
        if objectName.isEmpty {
            return (noNameErrorMessage, nameTextField)
        }
        
        return(nil, nil)
    }
    
    func saveObject() {
        view.endEditing(true)
        
        guard let managedObjectContext = coreDataManager?.mainThreadManagedObjectContext,
            let objectName = nameTextField.text,
            let modelObjectType = modelObjectType else {
                fatalError("DetailsViewController - saveObject: guard statement failed for either no managedObjectContext or invalid input")
        }
        
        var managedObject: CTBRootManagedObject? = nil
        if !hasObject {
            switch modelObjectType {
            case .Car:
                managedObject = createNewCarObject(managedObjectContext)
            case .Truck:
                managedObject = createNewTruckObject(managedObjectContext)
            case .Bus:
                managedObject = createNewBusObject(managedObjectContext)
            default: break
            }
            
            managedObject?.added = Date()
            hasObject = true
        }
        else {
            switch modelObjectType {
            case .Car:
                managedObject = car
            case .Truck:
                managedObject = truck
            case .Bus:
                managedObject = bus
            default: break
            }
        }
        
        managedObject?.name = objectName
        managedObject?.lastUpdate = Date()
        
        coreDataManager?.save()
        setLabels(managedObject!)
    }
    
    func createNewCarObject(_ managedObjectContext: NSManagedObjectContext) -> CTBRootManagedObject {
        guard let newCar = NSEntityDescription.insertNewObject(forEntityName: "Car", into: managedObjectContext) as? Car else {
            fatalError("DetailsViewController - saveProject : could not create Car object")
        }
        
        car = newCar
        return car!
    }
    
    func createNewTruckObject(_ managedObjectContext: NSManagedObjectContext) -> CTBRootManagedObject {
        guard let newTruck = NSEntityDescription.insertNewObject(forEntityName: "Truck", into: managedObjectContext) as? Truck else {
            fatalError("DetailsViewController - saveProject : could not create Truck object")
        }
        
        truck = newTruck
        return truck!
    }
    
    func createNewBusObject(_ managedObjectContext: NSManagedObjectContext) -> CTBRootManagedObject {
        guard let newBus = NSEntityDescription.insertNewObject(forEntityName: "Bus", into: managedObjectContext) as? Bus else {
            fatalError("DetailsViewController - saveProject : could not create Bus object")
        }
        
        bus = newBus
        return bus!
    }
    
    // MARK: Delete
    @IBAction func deleteAction() {
        let actionSheetController = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        
        let deleteAction = UIAlertAction(title: "Delete", style: UIAlertActionStyle.destructive) {
            [unowned self]
            action in
            
            self.deleteObject()
        }
        actionSheetController.addAction(deleteAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil)
        actionSheetController.addAction(cancelAction)
        
        present(actionSheetController, animated: true, completion: nil)
    }
    
    func deleteObject() {
        guard let managedObjectContext = coreDataManager?.mainThreadManagedObjectContext else {
            fatalError("DetailsViewController - deleteManagedObject: guard statement failed for no managedObjectContext")
        }
        
        if let car = car {
            car.addDeletedCloudKitObject()
            managedObjectContext.delete(car)
        }
        else if let truck = truck {
            truck.addDeletedCloudKitObject()
            managedObjectContext.delete(truck)
        }
        else if let bus = bus {
            bus.addDeletedCloudKitObject()
            managedObjectContext.delete(bus)
        }
        
        coreDataManager?.save()
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: Show Error
    func showErrorAlert(_ errorMessage: String, okAction:(()->())?) {
        let alertController = UIAlertController(title: nil, message: errorMessage, preferredStyle: .alert)
        
        let OKAction = UIAlertAction(title: "OK", style: .default) {
            action in
            
            if let safeOkAction = okAction {
                safeOkAction()
            }
        }
        alertController.addAction(OKAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    // MARK: Segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        // set the coreDataManager either on the root of a UINavigationController or on the segue destination itself
        if var destinationCoreDataViewController = segue.destination as? CoreDataManagerViewController {
            destinationCoreDataViewController.coreDataManager = coreDataManager
            destinationCoreDataViewController.modelObjectType = modelObjectType
        }
        
        if let notesTableViewController = segue.destination as? NotesTableViewController {
            notesTableViewController.car = car
            notesTableViewController.bus = bus
            notesTableViewController.truck = truck
        }
    }

}
