//
//  MasterViewController.swift
//  Swift Contacts
//
//  Created by Stephan Kostine on 2014-12-13.
//  Copyright (c) 2014 istra. All rights reserved.
//

import UIKit

class MasterViewController: UITableViewController, NSURLConnectionDataDelegate {

    var dataProvider: ABookDataProvider?

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        dataProvider = ABookDataProvider()
        //self.navigationItem.leftBarButtonItem = self.editButtonItem()

        //let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "insertNewObject:")
        //self.navigationItem.rightBarButtonItem = addButton
        self.tableView.dataSource = dataProvider
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    // MARK: - Segues

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow {
                let object = dataProvider?.getUserName(indexPath.row)
            (segue.destinationViewController as! DetailViewController).detailItem = object
            }
        }
    }

    // MARK: - Table View

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }


    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return false
    }


    

}

