//
//  AlbumViewController.swift
//  Traveler
//
//  Created by Stephen Martinez on 5/15/17.
//  Copyright © 2017 Stephen Martinez. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class AlbumViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    
    
    @IBOutlet weak var albumLocationMap: MKMapView!
    @IBOutlet weak var albumCollection: UICollectionView!
    @IBOutlet weak var albumLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var collectionTray: UIView!
    var pinUniqueID: String!
    
    lazy var fetchedResultstController: NSFetchedResultsController = { () -> NSFetchedResultsController<Photo> in
        let fetchRequest = NSFetchRequest<Photo>(entityName: "Photo")
        
        
        let fetchController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: Traveler.shared.context,
            sectionNameKeyPath: nil,
            cacheName: nil)
        return fetchController
    }()
    
    
    override func viewDidLoad() {super.viewDidLoad()
        moveTrayDown(animated: false, completionHandler: nil)
        albumCollection.backgroundColor = UIColor.clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        moveTrayUp()
        layoutSetter()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    @IBAction func newAlbum(_ sender: UIButton) {
    }
    
    @IBAction func back(_ sender: UIButton) {
        moveTrayDown(animated: true, completionHandler: {
            self.navigationController?.popViewController(animated: true)
        })
    }
    
    func layoutSetter(){
        let spaceSize: CGFloat = 10.0
        let width: CGFloat = albumCollection.frame.size.width
        let cellInRowCount: CGFloat = 3
        let spaceCount: CGFloat = cellInRowCount - 1
        let dimension: CGFloat = (width - (spaceCount * spaceSize)) / cellInRowCount
        albumLayout.minimumInteritemSpacing = spaceSize
        albumLayout.minimumLineSpacing = spaceSize
        albumLayout.itemSize = CGSize(width: dimension, height: dimension)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 32
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let protoTesterCell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCollectionCell", for: indexPath) as! AlbumCollectionCell
        
        protoTesterCell.thumbnailToSet = nil
        //protoTesterCell.thumbnailToSet = UIImage(named: "CoverBG")
        
        protoTesterCell.layer.cornerRadius = 5
        albumCollection(protoTesterCell, isLoading: true)
        return protoTesterCell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("Selected")
        //let selectedCell = collectionView.cellForItem(at: indexPath) as! AlbumCollectionCell
        
    }
    
    
    func albumCollection(_ cell: AlbumCollectionCell, isLoading: Bool){
        switch isLoading{
        case true:
            cell.backgroundColor = TravelerCnst.color.transparentTeal
            cell.whiteSpinner.startAnimating()
        case false:
            cell.backgroundColor = UIColor.clear
            cell.whiteSpinner.stopAnimating()
        }
    }
    

}
