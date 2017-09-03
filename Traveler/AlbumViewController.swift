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

    override func viewWillAppear(_ animated: Bool) {super.viewWillAppear(animated)}
    
    override func viewWillDisappear(_ animated: Bool) {super.viewWillDisappear(animated)
        TravelerCnst.imageCache.removeAllObjects()
    }
    
    @IBAction func newAlbum(_ sender: UIButton) {}
    
    @IBAction func back(_ sender: Any) {
        moveTrayDown(
            animated: true,
            completionHandler: {self.navigationController?.popViewController(animated: true)}
        )
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let selectedPin = selectedPin else{
            SendToDisplay.question(self,
                                   QTitle: "Pin Not Found",
                                   QMessage: "An unexpected error has occured with the location you have selected",
                                   assignments: ["Dismiss": {self.back(self)}])
            return 0
        }
        return selectedPin.isEmpty ? downloadList.count : dbTravelerPhotoList.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let albumCell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCollectionCell", for: indexPath) as! AlbumCollectionCell
       //Set loading indicator
        loadingStatusFor(albumCell, isLoading: true)
        //Round off corner edges of cells
        albumCell.layer.cornerRadius = 5
        //Pull the appropriate URL for the photo in the download list
        let thumbnailURL = downloadList[indexPath.row].thumbnail
        //Check to see if image has been loaded to the cache, if so then set cell and exit method through return
        if let imageFromCache = TravelerCnst.imageCache.object(forKey: indexPath.row as AnyObject) as? UIImage{
            albumCell.cellThumbnail.image = imageFromCache
            loadingStatusFor(albumCell, isLoading: false)
            return albumCell
        }
        //If no image has been cached, then download from Network
        flickrClient.getPhotoFor(url: thumbnailURL){ thumbnail, error in
            guard (error == nil) else{
                SendToDisplay.error(self,
                                    errorType: "Network Error While Retrieving Photo",
                                    errorMessage: error!.localizedDescription,
                                    assignment: {self.back(self)})
            return
            }
            guard let thumbnail = thumbnail else{
                SendToDisplay.error(self,
                                    errorType: "Network Error",
                                    errorMessage: "The retrieved photo came back invalid",
                                    assignment: {self.back(self)})
                return
            }
            DispatchQueue.main.async {
                //Once image has been downloaded, upload into the image cache, retrievable by cell location
                TravelerCnst.imageCache.setObject(thumbnail, forKey: indexPath.row as AnyObject)
                //After image has been cached, inform the Collection View to reload that particular cell with the image
                self.albumCollection.reloadItems(at: [indexPath])
            }
        }
        return albumCell
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













extension AlbumViewController{
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
        if let selectedPin = selectedPin{
            if selectedPin.isEmpty{
                print("No Photo's found in DB for pin location")
                let lat = String(selectedPin.coordinate.latitude)
                let lon = String(selectedPin.coordinate.longitude)
                
                flickrClient.photosForLocation(latitude: lat, longitude: lon){ photoList, error in
                    guard (error == nil) else{
                        SendToDisplay.error(self,
                                            errorType: "Network Error",
                                            errorMessage: "There was a network error in retreiving your photos for the location given: \(error!.localizedDescription)",
                                            assignment: {self.back(self)})
                        return
                    }
                    guard let verifiedPhotoList = photoList else{return}
                    if verifiedPhotoList.isEmpty{ DispatchQueue.main.async {
                            self.trayRemovalFlag = true
                            SendToDisplay.question(self,
                                                   QTitle: "No Photos",
                                                   QMessage: "There were no photos found this time for the given location",
                                                   assignments: ["Dismiss": {self.back(self)}])
                        }
                        return
                    }
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
                                    return
                                }
                                guard let imageSet = imageSet, let thumbnail = imageSet.thumbnail, let fullPhoto = imageSet.fullSize else{
                                    SendToDisplay.error(self,
                                                        errorType: "Network Error",
                                                        errorMessage: "The photo was not able to be converted to a viewable format",
                                                        assignment: {self.back(self)})
                                    return
                                }
                                let retrievedPhoto = TravelerPhoto(thumbnail: thumbnail, fullsize: fullPhoto, photoID: photo.photoID)
                                self.dbTravelerPhotoList[index] = retrievedPhoto
                                if let dbError = Traveler.checkAndSave(retrievedPhoto, pinID: self.selectedPin.uniqueIdentifier!, concurrent: true){
                                    SendToDisplay.error(self,
                                                        errorType: "DataBase Error",
                                                        errorMessage: dbError.localizedDescription,
                                                        assignment: nil)
                                }
                                print("Successfully Saved photo to DB and loaded DBPhotoList with photo")
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
            else{
                //If the Pin is not empty: Load up the dbTravelerPhotoList from the DataBase and use
                
                
                
            }
        }
    }
    
}





















































/*
func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let protoTesterCell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCollectionCell", for: indexPath) as! AlbumCollectionCell
    
    
    protoTesterCell.cellThumbnail.image = TravelerCnst.createClearPlaceHolder()
    albumCollection(protoTesterCell, isLoading: true)
    let indexToSet = indexPath.row
    
    //Run a search for the image in the DB
    let  photoFoundinDB = Traveler.retrievePhotoFromDataBase(photoID: downloadList[indexPath.row].photoID)
    //Check for DB Error during the search and respond if error is found
    guard photoFoundinDB.error == nil else{
        SendToDisplay.error(self,
                            errorType: "Database Error",
                            errorMessage: photoFoundinDB.error!.localizedDescription,
                            assignment: nil)
        return protoTesterCell
    }
    //If a photo is found, then set the cell image with the retrieved photo
    if let photoFound = photoFoundinDB.photo{
        self.albumCollection(protoTesterCell, isLoading: false)
        protoTesterCell.cellThumbnail.image = photoFound.thumbnailImage!
        print("Cell Number \(indexPath.row) has been set from DataBase!")
        print(indexPath.row == indexToSet)
    }else{
        //Otherwise retrieve the photo from the network
        let smallURL = downloadList[indexPath.row].thumbnail
        let largeURL = downloadList[indexPath.row].fullSize
        let photoID = downloadList[indexPath.row].photoID
        flickrClient.getPhotoFor(thumbnailURL: smallURL, fullSizeURL: largeURL){images, error in
            //Check for networking errors
            guard (error == nil) else {SendToDisplay.error(self,
                                                           errorType: "Network Error",
                                                           errorMessage: error!.localizedDescription,
                                                           assignment: nil)
                return
            }
            //Check image for nil before using, otherwise exit the method.
            guard let images = images,
                let thumbnail = images.thumbnail,
                let fullSize = images.fullSize else{print("downloaded image returned nil");return}
            //Go back to main thread to save image to DB and set cell with image as well.
            DispatchQueue.main.async{
                let photoToSave = TravelerPhoto(thumbnail: thumbnail, fullsize: fullSize, photoID: photoID)
                if let error = Traveler.checkAndSave(photoToSave, pinID: self.selectedPin.uniqueIdentifier!){
                    SendToDisplay.error(self,
                                        errorType: "DataBase Error",
                                        errorMessage: error.localizedDescription,
                                        assignment: nil)
                }
                print("Photo Successfully Saved to DataBase from Collection View")
                //WE NEED BOTH THUMBNAIL AND FULL SIZE HERE!!!
                //protoTesterCell.thumbnailToSet = thumbnail
                
                let cellsOnScreen = collectionView.visibleCells as! [AlbumCollectionCell]
                if cellsOnScreen .contains(protoTesterCell){
                    print("Proto Tester Cell is on screen")
                    self.albumCollection(protoTesterCell, isLoading: false)
                    protoTesterCell.cellThumbnail.image = thumbnail
                    print("Cell Number \(indexPath.row) has been set!")
                }else{
                    print("ProtoTester Cell is not on screen!!!")
                    print("Did Not set image")
                }
            }
        }
    }
    //Round the corners and display the newly set cell in the collection view.
    protoTesterCell.layer.cornerRadius = 5
    return protoTesterCell
}



 */




