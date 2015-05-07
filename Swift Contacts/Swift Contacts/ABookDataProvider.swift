//
//  ABookDataProvider.swift
//  Swift Contacts
//
//  Created by Stephan Kostine on 2014-12-13.
//  Copyright (c) 2014 istra. All rights reserved.
//
//  Data model for Address Book
//  Loads users from randomuser server
//  Data Source for Master Tabveview

import UIKit

class ABookDataProvider: NSObject, NSURLConnectionDataDelegate, UITableViewDataSource {
    private let numberOfUsers = 30      // class variables are not supported by compiler now
    private let sizeOfUserData = 1000   // class variables are not supported by compiler now
    private var responseData: NSMutableData?
    
    // primitive data model
    // best implementation can be provided using SQLlite
    private var users: [Dictionary<String, AnyObject>] = Array()
    
    private weak var tableView: UITableView?
    
    override init(){
        super.init()
        responseData = NSMutableData(capacity: (numberOfUsers*sizeOfUserData))
        let request = NSURLRequest(URL: NSURL(scheme: "http", host: "api.randomuser.me", path: "/?results=\(numberOfUsers)")!)
        let connection = NSURLConnection(request: request, delegate: self)

    }
    // MARK: - Accessors
    private var count: Int{
        return users.count
    }
    
    var isDataLoaded: Bool {return responseData == nil}
    
    func getUserName(index: Int) -> String{
        if (users.count <= index){
            return ""
        }
        if let username = users[index]["name"] as? [String: String] {
            var result = String()
            if let first = username["first"] {
                result += convertFirstToUppercase(first)
            }
            if let last = username["last"] {
                result += " " + convertFirstToUppercase(last)
            }
            return result
        }
        return ""
    }
    
    private func convertFirstToUppercase(str: String) ->String{
        let ind = advance(str.startIndex, 1)
        return str.substringToIndex(ind).uppercaseString + str.substringFromIndex(ind)
    }
    
    private func getValue(index: Int, forKey key:String) -> String{
        if (users.count <= index || key.isEmpty){
            return ""
        }
        if let result = users[index][key] as? String {
            return result;
        }
        return ""
    }
    // MARK: - Operations
    private func sortUsers(){
        users.sort{ (o1:[String: AnyObject], o2:[String: AnyObject]) -> Bool in
            var s1 = ""
            if let name = o1["name"] as? [String: String] {
                if let last = name["last"] {
                    s1 += last
                }
            }
            var s2 = ""
            if let name = o2["name"] as? [String: String] {
                if let last = name["last"] {
                    s2 += last
                }
            }
            return s1 < s2
        }
    }
    
    private func reportError(details: String, releaseData: Bool = true){
        let alert = UIAlertView(title: "JSON Data Provider", message: details, delegate: nil, cancelButtonTitle: "OK")
        alert.show()
        if releaseData {responseData = nil;}
    }
    
    // MARK: - NSURLConnectionDataDelegate Protocol
    
    func connection(_ connection: NSURLConnection, didReceiveResponse response: NSURLResponse){
        self.responseData?.length = 0
    }
    
    func connection(_ connection: NSURLConnection, didReceiveData data: NSData) {
        self.responseData?.appendData(data)
    }
    
    func connection(_ connection: NSURLConnection, didFailWithError error: NSError) {
        reportError(error.description)
    }
    
    func connectionDidFinishLoading(_ connection: NSURLConnection) {
        assert(responseData != nil && responseData!.length != 0, "Data buffer empty")
        var error: NSError?
        // extract users into users array
        let result: AnyObject? = NSJSONSerialization.JSONObjectWithData(responseData!, options: NSJSONReadingOptions.MutableContainers, error: &error)
        if result == nil {reportError(error!.description);return}
        // unwrap {results:[*]}
        let dResult = result as? [String: AnyObject]
        if dResult == nil {reportError("Data format is not supported");return}
        for (keyResult, valueResults) in dResult!{
            if keyResult != "results"{
                reportError("Data Server is out of order")
                return
            }
            //  process array of user/seed dictionaries
            let userArray = valueResults as? [NSDictionary]
            if userArray == nil {reportError("Data Format error"); return}
            for user in userArray!{
                let dUser = user as? [String: AnyObject]
                if dUser == nil {reportError("Data Format error"); return}
                // unwrap user dictionary
                for (keyUser, valueUser) in dUser!{
                    if keyUser != "user" {
                        // this should be "seed" element, omit it
                        continue
                    }
                    if let userDictionary = valueUser as? [String: AnyObject]{
                        users.append(userDictionary)
                        if getUserName(users.count-1).isEmpty{
                            users.removeLast()
                        }
                    }
                }// end user loop
            }// end array loop
        }// end results loop
        responseData = nil  //release
        if users.count == 0 {
            reportError("Random User server did not provide any data.", releaseData: false)
        }
        else{
            sortUsers()
            tableView?.reloadData()
        }
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.tableView = tableView
        return self.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as! UITableViewCell
        
        cell.textLabel!.text = self.getUserName(indexPath.row)
        cell.detailTextLabel!.text = "cell: " + getValue(indexPath.row, forKey: "cell") + "\temail: " + getValue(indexPath.row, forKey: "email")
        
        return cell
    }
    

}