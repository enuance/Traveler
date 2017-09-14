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

class AlbumViewController: UIViewController {
    
    @IBOutlet weak var albumLocationMap: MKMapView!
    @IBOutlet weak var albumCollection: UICollectionView!
    @IBOutlet weak var albumLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var mapAnchoringView: UIView!
    @IBOutlet weak var collectionTray: UIView!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var newButton: UIButton!
    //The below outlets are contained in the fullView popup.............................................
    @IBOutlet var fullView: UIView!
    @IBOutlet weak var fullViewPhoto: UIImageView!
    @IBOutlet weak var fvBlur: UIVisualEffectView!
    @IBOutlet weak var fvGrayBackground: UIImageView!
    @IBOutlet weak var fvBackButton: UIButton!
    @IBOutlet weak var fvDeleteButton: UIButton!
    @IBOutlet weak var fvSpinner: UIActivityIndicatorView!
    
    var trayRemovalFlag = false
    var albumDeletionFlag = false
    var dbFinishedUploading = false
    var selectedPin: PinAnnotation!
    var selectedPhoto: (index: IndexPath, id: String)!
    var downloadList = [(thumbnail: URL, fullSize: URL, photoID: String)]()
    var dbTravelerPhotoList = [Int : TravelerPhoto]()
    var refillList = [(thumbnail: URL, fullSize: URL, photoID: String)]()
    var fillMode = FillMode.new
    
    

    
    
    override func viewDidLoad() {super.viewDidLoad()
        fvBlur?.effect = nil
        fullViewPhoto?.layer.cornerRadius = 5
        TravelerCnst.map.zoomTarget = locateZoomTarget()
        initialPinCheck()
        albumLocationMap?.isUserInteractionEnabled = false
        moveTrayDown(animated: false, completionHandler: nil)
        albumCollection?.backgroundColor = UIColor.clear
    }
    
    override func viewDidAppear(_ animated: Bool) {super.viewDidAppear(animated)
        zoomMapToTarget()
        moveTrayUp()
        layoutSetter()
    }
    
    @IBAction func fullViewBack(_ sender: Any) {animateRemoveFullView()}
    
    @IBAction func fullViewDelete(_ sender: Any) {deletePhotoAndUpdateUI(selectedPhoto)}
    
    @IBAction func newAlbum(_ sender: UIButton) {fillMode == .new ? createNewAlbum() : refillAlbum()}
    
    
    
    //This still needs work: Right now this only feeds the data source coming from the download list, which is only in use when the pin is first dropped. Need to check how to implement if refilling from a point where the data source is pulling from the Database (an established pin)!
    
    func refillAlbum(){
        let imageCount = selectedPin.isEmpty ? downloadList.count : dbTravelerPhotoList.count
        let quota = FlickrCnst.Prefered.PhotosPerPage - imageCount
        let exclusionList = photoExclusionsGen(emptyPin: selectedPin.isEmpty)
        let lat = String(selectedPin.coordinate.latitude)
        let lon = String(selectedPin.coordinate.longitude)
        
        backButton.isEnabled = false
        newButton.isEnabled = false
        
        flickrClient.photosForLocation(
        withQuota: quota, IDExclusionList: exclusionList, latitude: lat, longitude: lon){ photoList, error in
            guard (error == nil) else{
                SendToDisplay.error(self,
                                    errorType: "Network Error",
                                    errorMessage: "There was a network error in retreiving your photos for the location given: \(error!.localizedDescription)",
                                    assignment: {
                        self.backButton.isEnabled = true
                        self.newButton.isEnabled = true})
                
                return}
            guard let verifiedPhotoList = photoList else{return}
            if verifiedPhotoList.isEmpty{
                self.trayRemovalFlag = true
                SendToDisplay.question(self,
                                       QTitle: "No Photos",
                                       QMessage: "There were no photos found this time to add to your album",
                                       assignments: ["Dismiss": {
                                        self.backButton.isEnabled = true
                                        self.newButton.isEnabled = true}])
                return}
            else{
                
                
                
                
                self.backgroundUploadLoopToDB(verifiedPhotoList)
                DispatchQueue.main.async {
                    self.downloadList.append(contentsOf: verifiedPhotoList)
                    print("\(verifiedPhotoList.count) added from flickr!")
                    self.albumCollection.reloadData()
                }
                
                
                
            }
        }
    }
    
    @IBAction func back(_ sender: Any) {
            moveTrayDown( animated: true, completionHandler: {
                TravelerCnst.imageCache.removeAllObjects()
                self.navigationController?.popViewController(animated: true)})
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let imageCount = selectedPin.isEmpty ? downloadList.count : dbTravelerPhotoList.count
        changeButton(refill: (imageCount < FlickrCnst.Prefered.PhotosPerPage))
        return imageCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let albumCell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "AlbumCollectionCell",
            for: indexPath) as! AlbumCollectionCell
        //Set the cells corners to be rounded.
        albumCell.layer.cornerRadius = 5
        //If the pin is empty then set cell image from cache, otherwise use images in database.
        return selectedPin.isEmpty ?
            updateFromCache(albumCell, using: indexPath) :
            updateFromDBList(albumCell, using: indexPath)
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        setFullImage(using: indexPath)
    }
 
    
    deinit{print("The AlbumViewController Has been deinitialized!")}
    
    
}



