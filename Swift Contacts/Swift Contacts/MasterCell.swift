//
//  MasterCell.swift
//  Swift Contacts
//
//  Created by Stephan Kostine on 2017-05-15.
//  Copyright © 2017 istra. All rights reserved.
//
//  Cell for Master View
//  Downloads, caches and shows required image

import UIKit
import CoreData

class MasterCell: UITableViewCell, URLSessionDownloadDelegate {
    // MARK: - properties
    @IBOutlet weak var imgView:UIImageView?
    @IBOutlet weak var lblMaster:UILabel?
    @IBOutlet weak var lblDetail:UILabel?
    var backgroundSession: URLSession?
    var destinationURLForFile:URL?
    
    weak var object: NSManagedObject?{
        didSet{
            var name = String()
            if let first = (object?.value(forKey: "firstname") as? String)?.description {
                name += first
            }
            if let last = (object?.value(forKey: "lastname") as? String)?.description {
                name += " " + last
            }
            self.lblMaster?.text = name
            if let phone = (object?.value(forKey: "cell") as? String)?.description {
                self.lblDetail?.text = "cell: \(phone)"
            }
            if let img = (object?.value(forKey: "thumbnail") as? String)?.description, let url = URL(string: img){
                let components = url.pathComponents
                if components.count > 2 {
                    let filename = components.suffix(3).joined(separator: ".")
                    if let d = showCachedImage(filename){
                        // There is no cached image presented if we are here
                        // Download one
                        destinationURLForFile = d
                        let backgroundSessionConfiguration = URLSessionConfiguration.background(withIdentifier: "\(filename).\(Date().timeIntervalSince1970)")
                        backgroundSession = URLSession(configuration: backgroundSessionConfiguration, delegate: self, delegateQueue: OperationQueue.main)
                        let downloadTask = backgroundSession?.downloadTask(with: url)
                        downloadTask?.resume()
                    }
                }
            }
        }
    }
    // MARK: - overrides
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    override func prepareForReuse() {
        lblMaster?.text = nil
        lblDetail?.text = nil
        imgView?.image = nil
    }
    // MARK: - private methods
    private func setImage(_ url:URL){
        do {
            let data = try Data(contentsOf: url, options:[])
            imgView?.image = UIImage(data: data)
        }
        catch let error as NSError {
            NSLog(error.localizedDescription)
        }
        
    }
    private func showCachedImage(_ file:String?) -> URL?{
        // if failed returns destination url to download file to
        if file == nil || file?.isEmpty == true {
            return nil
        }
        let path = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        let documentDirectoryPath:String = path[0]
        let destinationURLForFile = URL(fileURLWithPath: documentDirectoryPath.appendingFormat("/" + file!))
        let fileManager = FileManager()
        if fileManager.fileExists(atPath: destinationURLForFile.path){
            setImage(destinationURLForFile)
            return nil
        }
        return destinationURLForFile
    }
    // MARK: - URLSessionDownloadDelegate protocol
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL){
        if let d = self.destinationURLForFile {
            let fileManager = FileManager()
            do {
                try fileManager.moveItem(at: location, to: d)
            }catch{
                // do nothing
                // if few persons have the same image, moveItem can be failed
                //NSLog("Duplicated Image - \(d.absoluteString)")
            }
            // show file
            setImage(d)
        }
        self.backgroundSession?.finishTasksAndInvalidate()
        self.backgroundSession = nil
    }
}
