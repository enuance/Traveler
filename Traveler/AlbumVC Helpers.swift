//
//  AlbumVC Helpers.swift
//  Traveler
//
//  Created by Stephen Martinez on 9/12/17.
//  Copyright © 2017 Stephen Martinez. All rights reserved.
//

import UIKit
import MapKit
import CoreData

extension AlbumViewController: UICollectionViewDelegate, UICollectionViewDataSource, MKMapViewDelegate{
    
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
        print("No Photos found in DB for pin location")
        backButton.isEnabled = false
        newButton.isEnabled = false
        //fvDeleteButton?.isEnabled = false
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
                
                if self.albumDeletionFlag{
                    //Enter any setup needed
                    print("Deletion Flag: Download List has been stopped from being set")
                    return
                }
                
                
                //self.backgroundUploadLoopToDB(verifiedPhotoList)
                
                self.ExperimentalBGLoop(verifiedPhotoList){ success in
                    //Completed BGLoop task here
                }
                
                
                DispatchQueue.main.async {
                    self.downloadList = verifiedPhotoList
                    print("\(self.downloadList.count) photos have been loaded from flickr!")
                    self.albumCollection.reloadData()
                }
                
                
                
                
                
                
            }
        }
    }
    
    
    //Begins the background fetch loop for photos on the background context
    func backgroundUploadLoopToDB(_ verifiedPhotoList: [(thumbnail: URL, fullSize: URL, photoID: String)]){
        
        //Run Background DB Upload of verfiedPhotoList here:
        for (index, photo) in verifiedPhotoList.enumerated(){
            //Check in each iteration if a deletion of the album is requested.
            if albumDeletionFlag{
                //Enter any setup needed
                print("Deletion Flag: Background DB loop has been Stopped")
                break}
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
                                        assignment: {self.back(self)})
                    return}
                
                self.dbFinishedUploading = (verifiedPhotoList.count == (index + 1))
                if self.dbFinishedUploading{DispatchQueue.main.async {
                    self.backButton?.isEnabled = true
                    self.newButton?.isEnabled = true
                    //self.fvDeleteButton?.isEnabled = true
                    print("Successfully Saved photos to DB and loaded DBPhotoList with photos")
                    }
                }
            }
        }
    }
    
    
    
    //Begins the background fetch loop for photos on the background context
    func ExperimentalBGLoop(_ verifiedPhotoList: [(thumbnail: URL, fullSize: URL, photoID: String)], _ completionHandler: @escaping (_ success: Bool) -> Void){
        let totalLoops = verifiedPhotoList.count
        var currentLoop = 0
        var onFinalLoop = false
        //Run Background DB Upload of verfiedPhotoList here:
        for (index, photo) in verifiedPhotoList.enumerated(){
            
            //Check in each iteration if a deletion of the album is requested.
            if albumDeletionFlag{
                //Enter any setup needed
                print("Deletion Flag: Background DB loop has been Stopped")
                completionHandler(false)
                return
            }
            //Begin the loop off main thread
            flickrClient.getPhotoFor(thumbnailURL: photo.thumbnail, fullSizeURL: photo.fullSize){ imageSet , error in
                guard (error == nil) else{
                    SendToDisplay.error(self,
                                        errorType: "Network Error While Retrieving Photo",
                                        errorMessage: error!.localizedDescription,
                                        assignment: {self.back(self)})
                    completionHandler(false)
                    return}
                guard let imageSet = imageSet, let thumbnail = imageSet.thumbnail, let fullPhoto = imageSet.fullSize else{
                    SendToDisplay.error(self,
                                        errorType: "Network Error",
                                        errorMessage: "The photo was not able to be converted to a viewable format",
                                        assignment: {self.back(self)})
                    completionHandler(false)
                    return}
                let retrievedPhoto = TravelerPhoto(thumbnail: thumbnail, fullsize: fullPhoto, photoID: photo.photoID)
                
                
                
                Traveler.ExperimentBGSave(retrievedPhoto, pinID: self.selectedPin.uniqueIdentifier!){
                    status, error in
                    //Placed here because it's the furthest completionHandler
                    currentLoop += 1
                    
                    onFinalLoop = currentLoop == totalLoops
                    //Check for errors
                    guard (error == nil) else{
                        SendToDisplay.error(self,
                                            errorType: "Database Error",
                                            errorMessage: error!.localizedDescription,
                                            assignment: {self.back(self)})
                        completionHandler(false)
                        return}
                    
                    switch status{
                    case .SuccessfullSave:
                        print("Photo \(retrievedPhoto.photoID) was succesfully saved")
                    case .PhotoAlreadyExists:
                        print("Photo already exists in data base")
                    default: print("There was a Database error")
                    }
                    

                    
                    
                    
                    print("On Loop #\(currentLoop) out of \(totalLoops)")
                    print("Loop \(onFinalLoop ? "is" : "is not") finished")
                    
                    self.dbTravelerPhotoList[index] = retrievedPhoto
                    self.dbFinishedUploading = onFinalLoop
                    
                    if self.dbFinishedUploading{DispatchQueue.main.async {
                        self.backButton?.isEnabled = true
                        self.newButton?.isEnabled = true
                        print("Successfully Saved all photos to DB and loaded DBPhotoList with photos")
                        completionHandler(true)
                        }
                    }
                }
            }
        }
    }
    

    
    
    

    
    
    
    
    
    func initialPhotosFromDB(){
        //If the Pin is not empty: Load up the dbTravelerPhotoList from the DataBase and use
        dbFinishedUploading = true
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
    
    
    //Methods for inserting images into the collection view cells
    
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
    
    //Used to Refresh the entire photo album
    func createNewAlbum(){
        albumDeletionFlag = true
        selectedPin.isEmpty = true
        backButton.isEnabled = false
        newButton.isEnabled = false
        animateTrayRefill(){
            self.downloadList = [(thumbnail: URL, fullSize: URL, photoID: String)]()
            self.dbTravelerPhotoList = [Int : TravelerPhoto]()
            TravelerCnst.imageCache.removeAllObjects()
            self.albumCollection.reloadData()
            Traveler.deleteAllPhotosFor(self.selectedPin.uniqueIdentifier!){ status, error in
                guard error == nil else {
                    SendToDisplay.error(self,
                                        errorType: "Database Error",
                                        errorMessage: error!.localizedDescription,
                                        assignment: nil)
                    return
                }
                
                switch status{
                case .SuccessfullDeletion:
                    //Reset the deletion flag and refill the collectionView
                    self.albumDeletionFlag = false
                    self.initialPhotosFromWebAndBackgroundDBUpload()
                case .UnsavedChanges:
                    SendToDisplay.question(self,
                                           QTitle: "Deletion Failed",
                                           QMessage: "The Database was in the middle of completing task and could not complete your request. Would you like to try again?",
                                           assignments: ["Yes":{self.createNewAlbum()}, "No":{self.back(self)}])
                    return
                case .PhotoSetNotFound:
                    SendToDisplay.error(self,
                                        errorType: "No Photos Found",
                                        errorMessage: "The Photos for this album could not be found!",
                                        assignment: {self.back(self)})
                    
                default: return
                }
            }
        }
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
    
    
    
    
    func setFullImage(using iPath: IndexPath){
        //Get the Photo ID
        let theSelectedPhotoID: String! =
            selectedPin.isEmpty ? downloadList[iPath.row].photoID:
                dbTravelerPhotoList[iPath.row]?.photoID
        
        print("The pin is empty: \(selectedPin.isEmpty)")
        
        //Unwrap the PhotoID
        guard let photoID = theSelectedPhotoID else{
            SendToDisplay.error(self,
                                errorType: "UI Error",
                                errorMessage: GeneralError.UIConnection.localizedDescription,
                                assignment: {self.animateRemoveFullView()})
            return}
        //Set the Class' selectedPhoto property for the rest of the VC to use
        self.selectedPhoto = (iPath , photoID)
        animateFullView()
        fvSpinner.startAnimating()
        //Request the selected photo and see what we get back from the DB.
        let photoResult = Traveler.retrievePhotoFromDataBase(photoID: photoID)
        if let error = photoResult.error{
            SendToDisplay.error(self,
                                errorType: "Database Error",
                                errorMessage: error.localizedDescription,
                                assignment: {self.animateRemoveFullView()})}
        //If no error then unwrap the photo.
        if let dbPhoto = photoResult.photo{
            fvSpinner.stopAnimating()
            //Set the full size image and stop the spinner.
            fullViewPhoto.image = dbPhoto.fullsizeImage}
            //If the photo doesn't exist in the DB, then pull from network
        else{
            print("The downloadlist count is \(downloadList.count)")
            print("The indexer set is \(iPath.row)")
            //If the pin is full, but the dbPhoto returned nil then ignore the selection.
            //Indexing the downloadList, which would be empty if the pin is full, will cause
            //an index out of bounds exception.
            if !selectedPin.isEmpty{
                print("Caught the indexing exception!!!")
                return}
            
            let selectedURL = downloadList[iPath.row].fullSize
            flickrClient.getPhotoFor(url: selectedURL){ netPhoto, error in
                guard error == nil else{
                    SendToDisplay.error(self,
                                        errorType: "Network Error",
                                        errorMessage: error!.localizedDescription,
                                        assignment: {DispatchQueue.main.async {self.animateRemoveFullView()}})
                    return}
                //Unwrap the photo from the network.
                guard let netPhoto = netPhoto else{
                    SendToDisplay.error(self,
                                        errorType: "Network Error",
                                        errorMessage: "Image returned nil from the network!",
                                        assignment: {DispatchQueue.main.async {self.animateRemoveFullView()}})
                    return}
                //Go back to the main queue and set the full image with the retrieved photo
                DispatchQueue.main.async {
                    self.fvSpinner.stopAnimating()
                    self.fullViewPhoto.image = netPhoto
                }
            }
        }
    }
    
    func deletePhotoAndUpdateUI(_ selectedPhoto: (index: IndexPath, id: String)?){
        guard let selectedPhoto = selectedPhoto else{return}
        let deletePhoto = Traveler.deletePhotoFromDataBase(uniqueID: selectedPhoto.id)
        if let error = deletePhoto.error{
            SendToDisplay.error(self,
                                errorType: "Database Error",
                                errorMessage: error.localizedDescription,
                                assignment: nil)}
        //Check if the deletion of the photo failed
        if !deletePhoto.success{
            SendToDisplay.question(self,
                                   QTitle: "Deletion Failed!",
                                   QMessage: "The Database was unable to locate the photo to delete. Would you like to try again?",
                                   assignments: [
                                    "Yes": {self.fullViewDelete(self)},
                                    "No":{}])}
            //If it was a success, then update the intermediate Data Sources and UI
        else{
            //Update the intermediate Data Sources
            TravelerCnst.removeAndUpdate(&self.dbTravelerPhotoList, at: selectedPhoto.index.row)
            TravelerCnst.removeAndUpdate(&TravelerCnst.imageCache, at: selectedPhoto.index.row)
            if !self.downloadList.isEmpty{self.downloadList.remove(at: selectedPhoto.index.row)}
            //Update the Collection view here!
            self.albumCollection.deleteItems(at: [selectedPhoto.index])
            self.animateRemoveFullView()
        }
        
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseId = "TravelerPin"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
        if pinView == nil {pinView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)}
        else {pinView?.annotation = annotation}
        
        pinView?.image = UIImage(named:"TravelerPin")
        pinView?.centerOffset.y = -20
        pinView?.centerOffset.x = 4
        return pinView
    }
    
    //Use this method to acquire the zoom coordinates while the map is not visable yet (viewDidLoad).
    func locateZoomTarget() -> CLLocationCoordinate2D{
        //Save the original region so we can reset back to it
        let originalRegion = albumLocationMap.region
        //Zoom down to the selected location for the album
        let zoomTo = MKCoordinateRegionMakeWithDistance(
            selectedPin.coordinate,
            TravelerCnst.map.regionSize,
            TravelerCnst.map.regionSize
        )
        albumLocationMap.setRegion(zoomTo, animated: false)
        //Use the anchorView in the story board in order to determine a new point over the map
        var aim = mapAnchoringView.center
        aim.y -= mapAnchoringView.frame.height/4
        //Convert the point from the anchorView into a coordinate on the map
        let newCenter = albumLocationMap.convert(aim, toCoordinateFrom: albumLocationMap)
        //Set up the region to zoom in with same pin location again but this time adjust the latitude by the difference in latitude between the original point and the one made by using the anchorView
        var adjust = MKCoordinateRegionMakeWithDistance(
            selectedPin.coordinate,
            TravelerCnst.map.regionSize,
            TravelerCnst.map.regionSize
        )
        adjust.center.latitude -= (newCenter.latitude - selectedPin.coordinate.latitude)
        //Store the adjusted coordinates
        let targetedZoomPoint = adjust.center
        //Set the map back to its original region settings
        albumLocationMap.setRegion(originalRegion, animated: false)
        //Return the stored adjusted coordinates
        return targetedZoomPoint
    }
    
    //Produces an exclusion list composed of Unique identifiers built from either the Web list or the database list
    func photoExclusionsGen(emptyPin: Bool) -> [String]{
        var exclusionList = [String]()
        if emptyPin{if downloadList.count == 0{return exclusionList}
            for download in downloadList{exclusionList.append(download.photoID)}
            return exclusionList}
        else{if dbTravelerPhotoList.count == 0{return exclusionList}
            for (_, tPhoto) in dbTravelerPhotoList{ exclusionList.append(tPhoto.photoID)}
            return exclusionList}
    }

}



