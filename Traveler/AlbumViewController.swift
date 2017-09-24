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
    var selectedPin: PinAnnotation!
    var albumData: AlbumData!
    var selectedPhoto: IndexPath!
    
    var fillMode = FillMode.new
    
    override func viewDidLoad() {super.viewDidLoad()
        fvBlur?.effect = nil
        fullViewPhoto?.layer.cornerRadius = 5
        TravelerCnst.map.zoomTarget = locateZoomTarget()
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
    
    @IBAction func fullViewDelete(_ sender: Any) {
        albumData.requestDeletePhotoFor(selectedPhoto.row){ [weak self] error in
            guard error == nil else{print("Error with deletion!!!"); return}
            guard let selectedPhoto = self?.selectedPhoto else{return}
            self?.albumCollection.deleteItems(at: [selectedPhoto])
            self?.fullViewPhoto.image = TravelerCnst.clearPlaceholder
            self?.animateRemoveFullView()
        }
    }
    
    @IBAction func newAlbum(_ sender: UIButton) {}
    
    func refillAlbum(){}
    
    @IBAction func back(_ sender: Any) {
            moveTrayDown( animated: true, completionHandler: {
                self.navigationController?.popViewController(animated: true)})
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return albumData.albumPin.albumFrames?.count ?? 0
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let albumCell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCollectionCell",for: indexPath) as! AlbumCollectionCell
        albumCell.layer.cornerRadius = 5
        loadingStatusFor(albumCell, isLoading: true)
        albumData.requestPhotoFor(indexPath.row){ [weak self] albumPhoto, freshLoad, error in
            guard error == nil else{print("Errrrorrr!!!!"); return}
            guard let albumPhoto = albumPhoto, let freshLoad = freshLoad else{print("PHOTO is NILLLLLLLL!!!!"); return}
            if freshLoad{
                collectionView.reloadItems(at: [indexPath])
            }else{
                self?.loadingStatusFor(albumCell, isLoading: false)
                albumCell.cellThumbnail.image = albumPhoto.thumbnailImage
            }
            

        }
        return albumCell
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.selectedPhoto = indexPath
        animateFullView()
        fvSpinner.startAnimating()
        albumData.requestPhotoFor(indexPath.row){ [weak self] albumPhoto, freshLoad, error in
            guard error == nil else{print("Errrrorrr!!!!"); return}
            guard let albumPhoto = albumPhoto, let freshLoad = freshLoad else{print("PHOTO is NILLLLLLLL!!!!"); return}
            self?.fvSpinner.stopAnimating()
            self?.fullViewPhoto.image = albumPhoto.fullsizeImage
        }
    }
 
    
    deinit{print("The AlbumViewController Has been deinitialized!")}
    
    
}











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
    
}




/*
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
        
        if thumbnail.isEqual(TravelerCnst.clearPlaceholder){
            print("Found Placeholder thumbnail in DB list. Returning celling in the loading state")
            return cell
        }
        
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
            print("Setting image from cache!!!!!!!!!!!!!!!!!!!!!!!!...................XXXXXXXXXXXX")
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
    


*/
