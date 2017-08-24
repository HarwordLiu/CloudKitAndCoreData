//
//  NoteDetailsViewController.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 12/12/15.
//  Copyright © 2015 Nick Harris. All rights reserved.
//

import UIKit
import CoreData

class NoteDetailsViewController: UIViewController, CoreDataManagerViewController {

    @IBOutlet weak var noteTextView: UITextView!
    @IBOutlet weak var deleteButton: UIBarButtonItem!
    
    let noNoteErrorMessage = "Please supply a note"
    var originalFrameHeight: CGFloat?
    var coreDataManager: CoreDataManager?
    var modelObjectType: ModelObjectType?
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
    var note: Note?
    var managedObject: CTBRootManagedObject?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(NoteDetailsViewController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(NoteDetailsViewController.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(NoteDetailsViewController.managedObjectContextChanged(_:)), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: coreDataManager?.mainThreadManagedObjectContext)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        originalFrameHeight = view.frame.size.height
        
        setTextView()
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
        if let note = note,
            let updatedObjectIndex = updatedObjects.index(of: note) {
                let updatedObject = updatedObjects[updatedObjectIndex]
                self.note = updatedObject as? Note
                setTextView()
        }
    }
    
    func checkIfDeleted(_ deletedObjects: Set<NSManagedObject>) {
        if let managedObject = managedObject {
            if deletedObjects.contains(managedObject as! NSManagedObject) {
                navigationController?.popToRootViewController(animated: true)
            }
        }
        if let note = note {
            if deletedObjects.contains(note) {
                navigationController?.popViewController(animated: true)
            }
        }
    }
    
    func setTextView() {
        if let note = note {
            noteTextView.text = note.text
        }
        else {
            noteTextView.text = ""
            deleteButton.isEnabled = false
        }
    }
    
    func setFirstResponder() {
        
        if note == nil {
            noteTextView.becomeFirstResponder()
        }
    }
    
    @IBAction func saveAction() {
        let validationResult = validateNote()
        
        if let errorMessage = validationResult.errorMessage {
            showErrorAlert(errorMessage) {
                if let safeInputView = validationResult.inputView {
                    safeInputView.becomeFirstResponder()
                }
            }
        }
        else {
            saveNote()
        }
    }
    
    // MARK: Validate and Save
    func validateNote() -> (errorMessage: String?, inputView: UIView?) {
        guard let noteText = noteTextView.text else {
            return (noNoteErrorMessage, noteTextView)
        }
        
        if noteText.isEmpty {
            return (noNoteErrorMessage, noteTextView)
        }
        
        return (nil, nil)
    }
    
    func saveNote() {
        view.endEditing(true)
        
        guard let managedObjectContext = coreDataManager?.mainThreadManagedObjectContext,
            let noteText = noteTextView.text else {
                fatalError("NoteDetailsViewController: guard statement failed for either no managedObjectContext or invalid input")
        }
        
        if note == nil {
            guard let newNote = NSEntityDescription.insertNewObject(forEntityName: "Note", into: managedObjectContext) as? Note else {
                fatalError("NoteDetailsViewController: could not create Note object")
            }
            
            // make sure to set its uniqueID as well.
            newNote.added = Date()            
            if let car = car {
                if let notes = car.value(forKeyPath: "notes") as? NSMutableSet {
                    notes.add(newNote)
                }
                newNote.car = car
            }
            else if let truck = truck {
                if let notes = truck.value(forKeyPath: "notes") as? NSMutableSet {
                    notes.add(newNote)
                }
                newNote.truck = truck
            }
            else if let bus = bus {
                if let notes = bus.value(forKeyPath: "notes") as? NSMutableSet {
                    notes.add(newNote)
                }
                newNote.bus = bus
            }
            
            note = newNote
        }
        
        note?.text = noteText
        note?.lastUpdate = Date()
        managedObject?.lastUpdate = Date()
        
        coreDataManager?.save()
        
        deleteButton.isEnabled = true
    }
    
    // MARK: Delete note
    @IBAction func deleteNote() {
        
        let actionSheetController = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        
        let deleteAction = UIAlertAction(title: "Delete", style: UIAlertActionStyle.destructive) {
            [unowned self]
            action in
            
            guard let managedObjectContext = self.coreDataManager?.mainThreadManagedObjectContext,
                let note = self.note else {
                    fatalError("NoteDetailsViewController: No managedObjectContext or note")
            }
            
            note.addDeletedCloudKitObject()
            
            managedObjectContext.delete(note)
            self.managedObject?.lastUpdate = Date()
            self.coreDataManager?.save()
            self.navigationController?.popViewController(animated: true)
        }
        actionSheetController.addAction(deleteAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil)
        actionSheetController.addAction(cancelAction)
        
        present(actionSheetController, animated: true, completion: nil)
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

    // MARK: Keyboard
    func keyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let animationDuration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? Double,
            let keyboardEndFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let rawAnimationCurve = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber
            else {
                fatalError("NoteDetailsViewController: Could not handle keyboard notification correctly")
        }
        
        let convertedKeyboardEndFrame = view.convert(keyboardEndFrame, from: view.window)
        let shiftedRawAnimationCurve = rawAnimationCurve.uint32Value << 16
        let animationCurve = UIViewAnimationOptions(rawValue: UInt(shiftedRawAnimationCurve))
        
        let offset = noteTextView.frame.origin.y + noteTextView.frame.size.height - convertedKeyboardEndFrame.origin.y
        var viewFrame = view.frame
        viewFrame = CGRect(x: viewFrame.origin.x, y: viewFrame.origin.y, width: viewFrame.size.width, height: viewFrame.size.height - offset)
        view.frame = viewFrame
        
        UIView.animate(withDuration: animationDuration, delay: 0.0, options: [.beginFromCurrentState, animationCurve], animations: {
            [unowned self] in
            self.view.layoutIfNeeded()
            }, completion: nil)
    }
    
    func keyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let animationDuration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? Double,
            let rawAnimationCurve = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber,
            let originalFrameHeight = originalFrameHeight
            else {
                fatalError("NoteDetailsViewController: Could not handle keyboard notification correctly")
        }
        
        let shiftedRawAnimationCurve = rawAnimationCurve.uint32Value << 16
        let animationCurve = UIViewAnimationOptions(rawValue: UInt(shiftedRawAnimationCurve))
        
        var viewFrame = view.frame
        viewFrame = CGRect(x: viewFrame.origin.x, y: viewFrame.origin.y, width: viewFrame.size.width, height: originalFrameHeight)
        view.frame = viewFrame
        
        UIView.animate(withDuration: animationDuration, delay: 0.0, options: [.beginFromCurrentState, animationCurve], animations: {
            [unowned self] in
            self.view.layoutIfNeeded()
            }, completion: nil)
    }
}
