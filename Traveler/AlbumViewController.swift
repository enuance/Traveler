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
    @IBOutlet weak var collectionTray: UIView!
    var trayRemovalFlag: Bool = false
    var selectedPin: PinAnnotation!
    var downloadList = [(thumbnail: URL, fullSize: URL, photoID: String)]()
    var dbTravelerPhotoList = [Int : TravelerPhoto]()
    
    override func viewDidLoad() {super.viewDidLoad()
        moveTrayDown(animated: false, completionHandler: nil)
        albumCollection.backgroundColor = UIColor.clear
        initialPinCheck()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        moveTrayUp()
        layoutSetter()
    }
    
    @IBAction func newAlbum(_ sender: UIButton) {}
    
    @IBAction func back(_ sender: Any) {
        moveTrayDown( animated: true, completionHandler: {
            TravelerCnst.imageCache.removeAllObjects()
            self.navigationController?.popViewController(animated: true)})
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return selectedPin.isEmpty ?
            downloadList.count :
            dbTravelerPhotoList.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let albumCell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "AlbumCollectionCell",
            for: indexPath) as! AlbumCollectionCell
        //Ste the cells corners to be rounded.
        albumCell.layer.cornerRadius = 5
        //If the pin is empty then ste cell image from cache, otherwise use images in database.
        return selectedPin.isEmpty ?
            updateFromCache(albumCell, using: indexPath) :
            updateFromDBList(albumCell, using: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("Selected")
        //let selectedCell = collectionView.cellForItem(at: indexPath) as! AlbumCollectionCell
    }
    
    //Enables a cell to show that it is in the process of loading.
    func loadingStatusFor(_ cell: AlbumCollectionCell, isLoading: Bool){
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







extension AlbumViewController: UICollectionViewDelegate, UICollectionViewDataSource{
    func layoutSetter(){
        let spaceSize: CGFloat = 9.0
        let width: CGFloat = albumCollection.frame.size.width
        let cellInRowCount: CGFloat = 3
        let spaceCount: CGFloat = cellInRowCount - 1
        let dimension: CGFloat = (width - (spaceCount * spaceSize)) / cellInRowCount
        albumLayout.minimumInteritemSpacing = spaceSize
        albumLayout.minimumLineSpacing = spaceSize
        albumLayout.itemSize = CGSize(width: dimension, height: dimension)
    }
    
    func initialPinCheck(){
        guard let selectedPin = selectedPin else{
            SendToDisplay.question(self,
                                   QTitle: "Pin Not Found",
                                   QMessage: "An unexpected error has occured with the location you have selected",
                                   assignments: ["Dismiss": {self.back(self)}])
            return}
        selectedPin.isEmpty ?
            initialPhotosFromWebAndBackgroundDBUpload() :
            initialPhotosFromDB()
    }
    
/*
     Helper Method for the initialPinCheck(:_) method. This pulls photo URL's from the network and loads them
     into an Download List (To Be Downloaded by the cell image setter), concurrently this method loops through
     the Download list, Converts the URLs into Photo Data (NSData) and uploads the DataBase with the photo
     info with the associated location.
*/
    func initialPhotosFromWebAndBackgroundDBUpload(){
        print("No Photo's found in DB for pin location")
        let lat = String(selectedPin.coordinate.latitude)
        let lon = String(selectedPin.coordinate.longitude)
        flickrClient.photosForLocation(latitude: lat, longitude: lon){ photoList, error in
            guard (error == nil) else{
                SendToDisplay.error(self,
                                    errorType: "Network Error",
                                    errorMessage: "There was a network error in retreiving your photos for the location given: \(error!.localizedDescription)",
                                    assignment: {self.back(self)})
                return}
            guard let verifiedPhotoList = photoList else{return}
            if verifiedPhotoList.isEmpty{
                self.trayRemovalFlag = true
                SendToDisplay.question(self,
                                       QTitle: "No Photos",
                                       QMessage: "There were no photos found this time for the given location",
                                       assignments: ["Dismiss": {self.back(self)}])
                return}
            else{
                //Run Background DB Upload of verfiedPhotoList here:
                for (index, photo) in verifiedPhotoList.enumerated(){
                    //Begin the loop off main thread
                    flickrClient.getPhotoFor(thumbnailURL: photo.thumbnail, fullSizeURL: photo.fullSize){ imageSet , error in
                        guard (error == nil) else{
                            SendToDisplay.error(self,
                                                errorType: "Network Error While Retrieving Photo",
                                                errorMessage: error!.localizedDescription,
                                                assignment: {self.back(self)})
                            return}
                        guard let imageSet = imageSet, let thumbnail = imageSet.thumbnail, let fullPhoto = imageSet.fullSize else{
                            SendToDisplay.error(self,
                                                errorType: "Network Error",
                                                errorMessage: "The photo was not able to be converted to a viewable format",
                                                assignment: {self.back(self)})
                            return}
                        let retrievedPhoto = TravelerPhoto(thumbnail: thumbnail, fullsize: fullPhoto, photoID: photo.photoID)
                        self.dbTravelerPhotoList[index] = retrievedPhoto
                        if let dbError = Traveler.checkAndSave(retrievedPhoto, pinID: self.selectedPin.uniqueIdentifier!, concurrent: true){
                            SendToDisplay.error(self,
                                                errorType: "DataBase Error",
                                                errorMessage: dbError.localizedDescription,
                                                assignment: nil)
                        };print("Successfully Saved photo to DB and loaded DBPhotoList with photo")
                    }
                }
                DispatchQueue.main.async {
                    self.downloadList = verifiedPhotoList
                    print("\(self.downloadList.count) photos have been loaded from flickr!")
                    self.albumCollection.reloadData()
                }
            }
        }
    }
    
    func initialPhotosFromDB(){
        //If the Pin is not empty: Load up the dbTravelerPhotoList from the DataBase and use
        guard let locationID = selectedPin.uniqueIdentifier else{
            SendToDisplay.question(self,
                                   QTitle: "Pin Location Not Found",
                                   QMessage: "An unexpected error has occured with the location you have selected",
                                   assignments: ["Dismiss": {self.back(self)}])
            return
        }
        let dbPhotos = Traveler.retrievePhotosFromDataBase(pinUniqueID: locationID, concurrent: true)
        guard (dbPhotos.error == nil), let photosFromDB = dbPhotos.photos?.enumerated() else{
            SendToDisplay.error(self,
                                errorType: "DataBase Error",
                                errorMessage: "An unexpected error has occured while retieving your album photos from the DataBase!",
                                assignment: {self.back(self)})
            
            return}
        for (photoIndex, dbPhoto) in photosFromDB{dbTravelerPhotoList[photoIndex] = dbPhoto}
    }
    
    func updateFromDBList(_ cell: AlbumCollectionCell, using iPath: IndexPath) -> AlbumCollectionCell{
        //Set loading indicator
        loadingStatusFor(cell, isLoading: true)
        guard let thumbnail = dbTravelerPhotoList[iPath.row]?.thumbnailImage else{
            SendToDisplay.error(self,
                                errorType: "Database Error",
                                errorMessage: "Was not able to pull photo from the list generated by the Database!",
                                assignment: {self.back(self)})
            return cell}
        cell.cellThumbnail.image = thumbnail
        loadingStatusFor(cell, isLoading: false)
        return cell
    }
    
    func updateFromCache(_ cell: AlbumCollectionCell, using iPath: IndexPath) -> AlbumCollectionCell{
        //Set loading indicator
        loadingStatusFor(cell, isLoading: true)
        //Pull the appropriate URL for the photo in the download list
        let thumbnailURL = downloadList[iPath.row].thumbnail
        //Check to see if image has been loaded to the cache, if so then set cell and exit method through return
        if let imageFromCache = TravelerCnst.imageCache.object(forKey: iPath.row as AnyObject) as? UIImage{
            cell.cellThumbnail.image = imageFromCache
            loadingStatusFor(cell, isLoading: false)
            return cell}
        //If no image has been cached, then download from Network
        flickrClient.getPhotoFor(url: thumbnailURL){ thumbnail, error in
            guard (error == nil) else{ SendToDisplay.error(self,
                                                           errorType: "Network Error While Retrieving Photo",
                                                           errorMessage: error!.localizedDescription,
                                                           assignment: {self.back(self)})
                return}
            guard let thumbnail = thumbnail else{ SendToDisplay.error(self,
                                                                      errorType: "Network Error",
                                                                      errorMessage: "The retrieved photo came back invalid",
                                                                      assignment: {self.back(self)})
                return}
            DispatchQueue.main.async {
                //Once image has been downloaded, upload into the image cache, retrievable by cell location
                TravelerCnst.imageCache.setObject(thumbnail, forKey: iPath.row as AnyObject)
                //After image has been cached, inform the Collection View to reload that particular cell with the image
                self.albumCollection.reloadItems(at: [iPath])
            }
        }
        return cell
    }
    
    
}

