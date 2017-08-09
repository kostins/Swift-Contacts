//
//  ABookDataProvider.swift
//  Swift Contacts
//
//  Created by Stephan Kostine on 2014-12-13.
//  Copyright (c) 2014 istra. All rights reserved.
//
//  Data model for Address Book
//  Loads users from randomuser server
//  Data Source for Master Tabveview backed by CoreData

import UIKit
import CoreData

class ABookDataProvider: NSObject, UITableViewDataSource, NSFetchedResultsControllerDelegate {
    // MARK: - Properties
    private let numberOfUsers = 30
    
    // JSON object obtained from web services is kept in Core Data
    private var managedObjectContext: NSManagedObjectContext? {
        let appDelegate =
        UIApplication.shared.delegate as! AppDelegate
    
        return appDelegate.managedObjectContext
    }
    
    private weak var tableView: UITableView?
    
    override init(){
        super.init()
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        let url = URL(string: "https://randomuser.me/api/?results=\(numberOfUsers)")!
        let task = session.dataTask(with: url) { (data, response, error) in
            if error != nil {
                self.reportError(error!.localizedDescription)
            } else {
                self.serializeJSON(data) // JSON Serialization
            }
        }
        task.resume()
        
    }
    
    // MARK: - Operations
    private func convertFirstToUppercase(_ str: String) ->String{
        if str.isEmpty {return str}
        var s = str.characters.map {
            String($0)
        }
        s[0] = s[0].capitalized
        // Capitalize all words in name
        for i in 0 ..< s.count - 1 {
            if s[i] == " " {
                s[i+1] = s[i+1].capitalized
            }
        }
        return s.joined(separator: "")
    }
    
    private func reportError(_ details: String){
        let alert = UIAlertController(title: "JSON Data Provider", message: details, preferredStyle:.alert)
        let action = UIAlertAction(title: "OK", style: UIAlertActionStyle.default){(action:UIAlertAction) -> Void in}
        alert.addAction(action)
        UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated:true, completion:nil)
    }
    
    private func serializeJSON(_ data:Data?){
        if data == nil {return}
        // extract users into users array
        var result: Any?
        do {
            result = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers)
        } catch let error as NSError {
            reportError(error.description)
            return
        }
        var users: [Dictionary<String, AnyObject>] = Array()
        // unwrap {results:[*]}
        let dResult = result as? [String: AnyObject]
        if dResult == nil {reportError("Data format is not supported");return}
        for (keyResult, valueResults) in dResult!{
            if keyResult == "results"{
                //  process array of user/seed dictionaries
                let userArray = valueResults as? [NSDictionary]
                if userArray == nil {reportError("Data Format error: no array for results key"); return}
                for user in userArray!{
                    let dUser = user as? [String: AnyObject]
                    if dUser == nil {reportError("Data Format error: array member is not a dictionary"); return}
                    users.append(dUser!)
                }// end array of users loop
            }// end if statement
        }// end keys loop
        if users.count == 0 {
            reportError("Random User server did not provide any data.")
        }
        else{
            clearCoreData("Contacts")
            for user in users {
                insertNewObject(user)
            }
            do {
                try self.fetchedResultsController.managedObjectContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                //print("Unresolved error \(error), \(error.userInfo)")
                abort()
            }
            tableView?.reloadData()
        }
    }
    
    func clearCoreData(_ entity:String) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: entity, in: managedObjectContext!)
        fetchRequest.includesPropertyValues = false
        do {
            if let results = fetchedResultsController.fetchedObjects as? [NSManagedObject] {
                for result in results {
                    managedObjectContext!.delete(result)
                }
                
                try managedObjectContext!.save()
            }
        } catch {
            NSLog("failed to clear core data")
        }
    }
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.tableView = tableView
        let sectionInfo = self.fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as UITableViewCell
        
        let object = self.fetchedResultsController.object(at: indexPath) as! NSManagedObject
        self.configureCell(cell, withObject: object)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let context = self.fetchedResultsController.managedObjectContext
            context.delete(self.fetchedResultsController.object(at: indexPath) as! NSManagedObject)
            
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                //print("Unresolved error \(error), \(error.userInfo)")
                abort()
            }
        }
    }
    
    func configureCell(_ cell: UITableViewCell, withObject object: NSManagedObject) {
        if let c = cell as? MasterCell {
            c.object = object
        }
    }
    
    // MARK: - Fetched results controller
    func insertNewObject(_ user: Dictionary<String, AnyObject>) {
        let context = self.fetchedResultsController.managedObjectContext
        let entity = self.fetchedResultsController.fetchRequest.entity!
        let newManagedObject = NSEntityDescription.insertNewObject(forEntityName: entity.name!, into: context)
        
        // If appropriate, configure the new managed object.
        // Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
        if let username = user["name"] as? [String: String] {
            if let first = username["first"] {
                newManagedObject.setValue(convertFirstToUppercase(first), forKey: "firstname")
            }
            if let last = username["last"] {
                newManagedObject.setValue(convertFirstToUppercase(last), forKey: "lastname")
            }
            if let title = username["title"] {
                newManagedObject.setValue(convertFirstToUppercase(title), forKey: "title")
            }
        }
        if let gender = user["gender"] as? String{
            newManagedObject.setValue(convertFirstToUppercase(gender), forKey: "gender")
        }
        if let phone = user["phone"] as? String{
            newManagedObject.setValue(phone, forKey: "phone")
        }
        if let email = user["email"] as? String{
            newManagedObject.setValue(email, forKey: "email")
        }
        if let cell = user["cell"] as? String{
            newManagedObject.setValue(cell, forKey: "cell")
        }
        if let picture = user["picture"] as? [String : String] {
            if let thumb = picture["thumbnail"] {
                newManagedObject.setValue(thumb, forKey: "thumbnail")
            }
        }
    }
    
    fileprivate var _fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>?
    
    var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        // Edit the entity name as appropriate.
        let entity = NSEntityDescription.entity(forEntityName: "Contacts", in: self.managedObjectContext!)
        fetchRequest.entity = entity
        
        // Set the batch size to a suitable number.
        fetchRequest.fetchBatchSize = numberOfUsers
        
        // Edit the sort key as appropriate.
        let sortDescriptor1 = NSSortDescriptor(key: "lastname", ascending: true)
        
        let sortDescriptor2 = NSSortDescriptor(key: "firstname", ascending: true)
        
        fetchRequest.sortDescriptors = [sortDescriptor1, sortDescriptor2]
        
        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext!, sectionNameKeyPath: nil, cacheName: nil)
        aFetchedResultsController.delegate = self
        _fetchedResultsController = aFetchedResultsController
        
        do {
            try _fetchedResultsController!.performFetch()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            //print("Unresolved error \(error), \(error.userInfo)")
            abort()
        }
        
        return _fetchedResultsController!
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView?.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            self.tableView?.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete:
            self.tableView?.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        default:
            return
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView?.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            tableView?.deleteRows(at: [indexPath!], with: .fade)
        case .update:
            self.configureCell(tableView!.cellForRow(at: indexPath!)!, withObject: anObject as! NSManagedObject)
        case .move:
            tableView?.moveRow(at: indexPath!, to: newIndexPath!)
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView?.endUpdates()
    }
    
    /*
     // Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.
     
     func controllerDidChangeContent(controller: NSFetchedResultsController) {
     // In the simplest, most efficient, case, reload the table view.
     self.tableView.reloadData()
     }
     */

}
