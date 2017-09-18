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
                //self.backgroundUploadLoopToDB(verifiedPhotoList)
                print("The selected Pin \(self.selectedPin.isEmpty ? "is empty":"is not empty")")
               // print("1!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!1")
                self.ExperimentalBGLoop(verifiedPhotoList){ success in
                    //Once the photos have finished loading into the DB load them up into the CollectionView
                    //But first check if we need to load up manually from this point.
                    print("Has entered completion handler of experimental BG loop")
                    if !self.selectedPin.isEmpty{
                        var photoIDList =  [String]()
                        for items in verifiedPhotoList{photoIDList.append(items.photoID)}
                        ///need to implement a different version of this that inserts the downloaded photos in to the existing dbTravelerPhoto list and tells the collectionView to reload at that index.
                        //self.initialPhotosFromDB()
                        Traveler.ExperimentalPhotoRetrieve(self.selectedPin.uniqueIdentifier!, photoIDList){ dbPhotoList, status, error in
                            guard error == nil, let dbPhotoList = dbPhotoList else{
                                print(status)
                                SendToDisplay.error(self, errorType: "Database Error", errorMessage: error!.localizedDescription, assignment: {
                                    DispatchQueue.main.async {
                                    self.initialPhotosFromDB()
                                    self.albumCollection.reloadData()}})
                                return
                            }
                            
                            print("The image count inside the comp handler is \(imageCount)")
                            var indexForAddedPhoto = imageCount
                            for dbPhoto in dbPhotoList{
                                print("Loading the dbTravelerPhotoList at index \(indexForAddedPhoto)")
                                self.dbTravelerPhotoList[indexForAddedPhoto] = dbPhoto
                                indexForAddedPhoto += 1
                            }
                            self.albumCollection.reloadData()
                            //print("2!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!2")
                        }
                        //print("2.5!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!2.5")
                    }
                }
                //print("3!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!3")
                //If the selected pin is not empty, then...
                
                print("The Pin is now\(self.selectedPin.isEmpty ? "empty":"not empty").......................................................!")
                if !self.selectedPin.isEmpty{
                    //Make sure the Download list is empty
                    self.downloadList.removeAll()
                    print("Clear out the download list.................................")
                    
                    var indexForAddedPhoto = imageCount
                    print("4!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!4")
                    print("The image count outside the comp hadler is \(imageCount)")
                    //Fill up the dbTravelerPhotoList with placeholders containing the actual photo ID's.
                    for verifiedPhoto in verifiedPhotoList{
                        //Create the placeholder
                        let placeHoldingPhoto = TravelerPhoto(
                                thumbnail: TravelerCnst.clearPlaceholder,
                                fullsize: TravelerCnst.clearPlaceholder,
                                photoID: verifiedPhoto.photoID)
                        //Add the placeholder to the dbTravelerList for cell setter to detect.
                        self.dbTravelerPhotoList[indexForAddedPhoto] = placeHoldingPhoto
                        print("Updating placeholder cells at index \(indexForAddedPhoto) inside the dbTravelerPhotoList")
                        indexForAddedPhoto += 1
                    }
                    print("5!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!5")
                    //fill up the download list with dummy items until the appropriate verified photolist can be entered
                    for _ in 1...imageCount{
                    self.downloadList.append(verifiedPhotoList.last!)
                    }
                    print("6!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!6")
                    print("The downloadList now contains \(self.downloadList.count) items")
                    //Load up the verified photos list now that the list is filled to the right point
                    self.downloadList.append(contentsOf: verifiedPhotoList)
                    
                    //At this point the dbTravelerPhotoList and the downloadList should have the same amount of items in it
                    print("The dbTravelerPhoto list count is: \(self.dbTravelerPhotoList.count)")
                    print("The downloadList count is: \(self.downloadList.count)")
                    
                    guard self.dbTravelerPhotoList.count == self.downloadList.count else{
                        print("The lists are not the same and a horrible error can occur")
                        return
                    }
                    print("7!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!7")
                    DispatchQueue.main.async {
                        self.albumCollection.reloadData()
                        print("8!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!8")
                    }
                }else{
                    DispatchQueue.main.async {
                        self.downloadList.append(contentsOf: verifiedPhotoList)
                        print("\(verifiedPhotoList.count) added from flickr!")
                        self.albumCollection.reloadData()
                    }
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



