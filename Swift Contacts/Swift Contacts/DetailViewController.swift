//
//  DetailViewController.swift
//  Swift Contacts
//
//  Created by Stephan Kostine on 2014-12-13.
//  Copyright (c) 2014 istra. All rights reserved.
//

import UIKit

class DetailViewController: UIViewController {

    @IBOutlet weak var detailDescriptionLabel: UILabel!


    var detailItem: AnyObject? {
        didSet {
            // Update the view.
            self.configureView()
        }
    }

    func configureView() {
        // Update the user interface for the detail item.
        if let detail = self.detailItem {
            if let label = self.detailDescriptionLabel {
                var name = String()
                if let title = (detail.value(forKey: "title") as AnyObject).description {
                    name += title
                }
                if let first = (detail.value(forKey: "firstname") as AnyObject).description {
                    name += " " + first
                }
                if let last = (detail.value(forKey: "lastname") as AnyObject).description {
                    name += " " + last
                }
                label.text = "TODO: show details for user: " + name
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.configureView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

