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
    private let numberOfUsers = 30
    private let sizeOfUserData = 1000
    private var connection:NSURLConnection?
    private var responseData: NSMutableData?
    
    // primitive data model
    // best implementation can be provided using SQLlite or Core Data
    private var users: [Dictionary<String, AnyObject>] = Array()
    
    private weak var tableView: UITableView?
    
    override init(){
        super.init()
        responseData = NSMutableData(capacity: (numberOfUsers*sizeOfUserData))
        let request = NSURLRequest(URL: NSURL(scheme: "https", host: "randomuser.me/api", path: "/?results=\(numberOfUsers)")!)
        connection = NSURLConnection(request: request, delegate: self)
        
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
        if str.isEmpty {return str}
        let ind = str.startIndex.advancedBy(1)
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
        users.sortInPlace{ (o1:[String: AnyObject], o2:[String: AnyObject]) -> Bool in
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
                    if getUserName(users.count-1).isEmpty{
                        users.removeLast()
                    }// end user loop
                }// end array of users loop
            }// end if statement
        }// end keys loop
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
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as UITableViewCell
        
        cell.textLabel!.text = self.getUserName(indexPath.row)
        cell.detailTextLabel!.text = "cell: " + getValue(indexPath.row, forKey: "cell") + "\temail: " + getValue(indexPath.row, forKey: "email")
        
        return cell
    }
    
}