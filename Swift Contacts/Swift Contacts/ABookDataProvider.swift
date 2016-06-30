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

class ABookDataProvider: NSObject, NSURLConnectionDataDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate {
    private let numberOfUsers = 30
    private let sizeOfUserData = 1000
    private var connection:NSURLConnection?
    private var responseData: NSMutableData?
    
    // JSON object obtained from web services is kept in Core Data
    private var managedObjectContext: NSManagedObjectContext? {
        let appDelegate =
        UIApplication.sharedApplication().delegate as! AppDelegate
    
        return appDelegate.managedObjectContext
    }
    
    private weak var tableView: UITableView?
    
    override init(){
        super.init()
        responseData = NSMutableData(capacity: (numberOfUsers*sizeOfUserData))
        let request = NSURLRequest(URL: NSURL(string: "https://randomuser.me/api/?results=\(numberOfUsers)")!)
        connection = NSURLConnection(request: request, delegate: self)
        
    }
    // MARK: - Accessors
    
    var isDataLoaded: Bool {return responseData == nil}
    
    private func convertFirstToUppercase(str: String) ->String{
        if str.isEmpty {return str}
        let ind = str.startIndex.advancedBy(1)
        return str.substringToIndex(ind).uppercaseString + str.substringFromIndex(ind)
    }
    
    // MARK: - Operations
    
    private func reportError(details: String, releaseData: Bool = true){
        let alert = UIAlertController(title: "JSON Data Provider", message: details, preferredStyle:.Alert)
        let action = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default){(action:UIAlertAction) -> Void in}
        alert.addAction(action)
        UIApplication.sharedApplication().keyWindow?.rootViewController?.presentViewController(alert, animated:true, completion:nil)
        if releaseData {responseData = nil;}
    }
    
    // MARK: - NSURLConnectionDataDelegate Protocol
    
    func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse){
        self.responseData?.length = 0
    }
    
    func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        self.responseData?.appendData(data)
    }
    
    func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        reportError(error.description)
    }
    
    func connection(connection: NSURLConnection, willSendRequestForAuthenticationChallenge challenge: NSURLAuthenticationChallenge) {
        // Let's trust to self-signed sertificate
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            challenge.sender!.useCredential(NSURLCredential(forTrust:challenge.protectionSpace.serverTrust!), forAuthenticationChallenge:challenge)
        }
    }
    
    func connectionDidFinishLoading(connection: NSURLConnection) {
        assert(responseData != nil && responseData!.length != 0, "Data buffer empty")
        // extract users into users array
        var result: AnyObject?
        do {
            result = try NSJSONSerialization.JSONObjectWithData(responseData!, options: NSJSONReadingOptions.MutableContainers)
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
        responseData = nil  //release
        if users.count == 0 {
            reportError("Random User server did not provide any data.", releaseData: false)
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
    
    func clearCoreData(entity:String) {
        let fetchRequest = NSFetchRequest()
        fetchRequest.entity = NSEntityDescription.entityForName(entity, inManagedObjectContext: managedObjectContext!)
        fetchRequest.includesPropertyValues = false
        do {
            if let results = fetchedResultsController.fetchedObjects as? [NSManagedObject] {
                for result in results {
                    managedObjectContext!.deleteObject(result)
                }
                
                try managedObjectContext!.save()
            }
        } catch {
            NSLog("failed to clear core data")
        }
    }
    // MARK: - UITableViewDataSource
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.tableView = tableView
        let sectionInfo = self.fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as UITableViewCell
        
        let object = self.fetchedResultsController.objectAtIndexPath(indexPath) as! NSManagedObject
        self.configureCell(cell, withObject: object)
        
        return cell
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let context = self.fetchedResultsController.managedObjectContext
            context.deleteObject(self.fetchedResultsController.objectAtIndexPath(indexPath) as! NSManagedObject)
            
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
    
    func configureCell(cell: UITableViewCell, withObject object: NSManagedObject) {
        var name = String()
        if let first = object.valueForKey("firstname")?.description {
            name += first
        }
        if let last = object.valueForKey("lastname")?.description {
            name += " " + last
        }
        cell.textLabel!.text = name
        let phone = object.valueForKey("cell")?.description ?? String()
        let email = object.valueForKey("email")?.description ?? String()
        cell.detailTextLabel!.text = "cell: \(phone)\temail: \(email)"
    }
    
    // MARK: - Fetched results controller
    
    func insertNewObject(user: Dictionary<String, AnyObject>) {
        let context = self.fetchedResultsController.managedObjectContext
        let entity = self.fetchedResultsController.fetchRequest.entity!
        let newManagedObject = NSEntityDescription.insertNewObjectForEntityForName(entity.name!, inManagedObjectContext: context)
        
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
    }
    
    private var _fetchedResultsController: NSFetchedResultsController? = nil
    
    var fetchedResultsController: NSFetchedResultsController {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }
        
        let fetchRequest = NSFetchRequest()
        // Edit the entity name as appropriate.
        let entity = NSEntityDescription.entityForName("Contacts", inManagedObjectContext: self.managedObjectContext!)
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
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.tableView?.beginUpdates()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
        case .Insert:
            self.tableView?.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        case .Delete:
            self.tableView?.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        default:
            return
        }
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert:
            tableView?.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
        case .Delete:
            tableView?.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
        case .Update:
            self.configureCell(tableView!.cellForRowAtIndexPath(indexPath!)!, withObject: anObject as! NSManagedObject)
        case .Move:
            tableView?.moveRowAtIndexPath(indexPath!, toIndexPath: newIndexPath!)
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
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