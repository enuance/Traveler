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
    @IBOutlet weak var fvBlur: UIVisualEffectView!
    @IBOutlet weak var fvGrayBackground: UIImageView!
    @IBOutlet weak var fullViewPhoto: UIImageView!
    @IBOutlet weak var fvBackButton: UIButton!
    @IBOutlet weak var fvDeleteButton: UIButton!
    @IBOutlet weak var fvSpinner: UIActivityIndicatorView!
    
    var trayRemovalFlag = false
    var albumDeletionFlag = false
    var selectedPin: PinAnnotation!
    var albumData: AlbumData!
    var selectedPhoto: IndexPath!
    var fillMode = FillMode.new
    var showingTopView: Bool = true
    
    //Moves Right Through Photo Array
    func fullViewSwipeLeft(){
        //Check if we're already at the begining of the Album
        let endOfAlbum = albumData.requestCount() - 1
        guard selectedPhoto.row < endOfAlbum else{print("Already at the End");return}
        fullViewPhoto?.image = TravelerCnst.clearPlaceholder
        fvSpinner?.startAnimating()
        selectedPhoto.row += 1
        let newSelectedPhoto = selectedPhoto.row
        albumData.requestPhotoFor(newSelectedPhoto){ [weak self] travelerPhoto, freshLoad, error in
            guard let currentlyRequestedPhoto = self?.selectedPhoto?.row else{return}
            guard self != nil else{return}
            guard newSelectedPhoto == currentlyRequestedPhoto else{print("User No longer wants this photo");return}
            guard error == nil else{ switch error!{
            case let gError as GeneralError:
                SendToDisplay.error(self!, errorType: "Error", errorMessage: gError.localizedDescription,
                                    assignment: {self?.animateRemoveFullView()})
            case let dbError as DatabaseError:
                SendToDisplay.error(self!, errorType: "Database Error", errorMessage: dbError.localizedDescription,
                                    assignment: {self?.animateRemoveFullView()})
            case let netError as NetworkError:
                SendToDisplay.error(self!, errorType: "Network Error", errorMessage: netError.localizedDescription,
                                    assignment: {self?.animateRemoveFullView()})
            default: print("Unexpected Error from this type of call")}
                return}
            guard let albumPhoto = travelerPhoto else{
                SendToDisplay.error(self!, errorType: "Error", errorMessage: GeneralError.AccessingNil.localizedDescription,
                                    assignment: {self?.animateRemoveFullView()})
                print("AlbumPhoto is nil");return}
            self?.fvSpinner.stopAnimating()
            self?.fullViewPhoto.image = albumPhoto.fullsizeImage
        }
    }
    
    //Moves Left through the Photo Array
    func fullViewSwipeRight(){
        //Check if we're already at the begining of the Album
        guard selectedPhoto.row > 0 else{print("Already at the beginning");return}
        fullViewPhoto?.image = TravelerCnst.clearPlaceholder
        fvSpinner?.startAnimating()
        selectedPhoto.row -= 1
        let newSelectedPhoto = selectedPhoto.row
        albumData.requestPhotoFor(newSelectedPhoto){ [weak self] travelerPhoto, freshLoad, error in
            guard let currentlyRequestedPhoto = self?.selectedPhoto?.row else{return}
            guard self != nil else{return}
            guard newSelectedPhoto == currentlyRequestedPhoto else{print("User No longer wants this photo");return}
            guard error == nil else{ switch error!{
            case let gError as GeneralError:
                SendToDisplay.error(self!, errorType: "Error", errorMessage: gError.localizedDescription,
                                    assignment: {self?.animateRemoveFullView()})
            case let dbError as DatabaseError:
                SendToDisplay.error(self!, errorType: "Database Error", errorMessage: dbError.localizedDescription,
                                    assignment: {self?.animateRemoveFullView()})
            case let netError as NetworkError:
                SendToDisplay.error(self!, errorType: "Network Error", errorMessage: netError.localizedDescription,
                                    assignment: {self?.animateRemoveFullView()})
            default: print("Unexpected Error from this type of call")}
                return}
            guard let albumPhoto = travelerPhoto else{
                SendToDisplay.error(self!, errorType: "Error", errorMessage: GeneralError.AccessingNil.localizedDescription,
                                    assignment: {self?.animateRemoveFullView()})
                print("AlbumPhoto is nil");return}
            self?.fvSpinner.stopAnimating()
            self?.fullViewPhoto.image = albumPhoto.fullsizeImage
        }
    }
    
    override func viewDidLoad() {super.viewDidLoad()
        fvBlur?.effect = nil
        fullViewPhoto?.layer.cornerRadius = 5
        TravelerCnst.map.zoomTarget = locateZoomTarget()
        albumLocationMap?.isUserInteractionEnabled = false
        moveTrayDown(animated: false, completionHandler: nil)
        albumCollection?.backgroundColor = UIColor.clear
        updateFillModeAndButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {super.viewDidAppear(animated)
        zoomMapToTarget()
        moveTrayUp()
        layoutSetter()
        setGestures()
    }
    
    @IBAction func fullViewBack(_ sender: Any) {animateRemoveFullView()}
    
    @IBAction func fullViewDelete(_ sender: Any) {
        albumData.requestDeletePhotoFor(selectedPhoto.row){ [weak self] error in
            guard error == nil else{print("Error with deletion!!!"); return}
            guard let selectedPhoto = self?.selectedPhoto else{return}
            self?.albumCollection.deleteItems(at: [selectedPhoto])
            self?.fullViewPhoto.image = TravelerCnst.clearPlaceholder
            self?.updateFillModeAndButton()
            self?.animateRemoveFullView()
        }
    }
    
    @IBAction func newAlbum(_ sender: UIButton) {
        switch fillMode {
        case .new: renewAlbum()
        case .refill: refillAlbum()
        }
    }
    
    //If the photoSearchYields no results error is thrown, then a deletion call to the context is made. Make sure
    //to check for this error in the renew album so that it can be handled properly
    func renewAlbum(){
        newButton.isEnabled = false
        moveTrayDown(animated: true){ [weak self] in
            self?.albumData.requestRenewAlbum(){  error in
                guard error == nil else{ print("Error in Renewing the Album!!!");
                    self?.albumCollection.reloadData()
                    self?.moveTrayUp()
                    self?.newButton.isEnabled = true
                    return}
                self?.albumCollection.reloadData()
                self?.updateFillModeAndButton()
                self?.moveTrayUp()
                self?.newButton.isEnabled = true
            }
        }
    }
    
    func refillAlbum(){
        newButton.isEnabled = false
        self.albumData.requestRefillAlbum(){[weak self] albumLocs, error in
            guard error == nil, let albumLocs = albumLocs else{
                print("Error in Refilling the Album!!!")
                switch error!{
                case let gError as GeneralError:
                    print("\(gError.localizedDescription)")
                default: print("Not a GeneralError")
                }
                
                self?.albumCollection.reloadData()
                self?.newButton.isEnabled = true
                return}
            let pathsNeedingInsertion = TravelerCnst.createIndexPathsFor(section: 0, albumLocs)
            self?.albumCollection.insertItems(at: pathsNeedingInsertion)
            self?.updateFillModeAndButton()
            self?.newButton.isEnabled = true
        }
        
    }
    
    @IBAction func back(_ sender: Any) {
            moveTrayDown( animated: true, completionHandler: {
                self.navigationController?.popViewController(animated: true)})
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return albumData.requestCount()
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let albumCell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCollectionCell",for: indexPath) as! AlbumCollectionCell
        albumCell.layer.cornerRadius = 5
        loadingStatusFor(albumCell, isLoading: true)
        albumData.requestPhotoFor(indexPath.row){ [weak self] albumPhoto, freshLoad, error in
            guard error == nil else{print("Error in CollectionView: \(error!.localizedDescription)!!!!"); return}
            guard let frameCount = self?.albumData.requestCount() else{return}
            guard indexPath.row <= (frameCount - 1) else{ print("Frame Count has changed and is no longer usable for this call");return}
            guard let albumPhoto = albumPhoto, let freshLoad = freshLoad else{print("PHOTO is NILLLLLLLL!!!!"); return}
            if freshLoad{collectionView.reloadItems(at: [indexPath])}
            else{
                self?.loadingStatusFor(albumCell, isLoading: false)
                albumCell.cellThumbnail.image = albumPhoto.thumbnailImage
            }
        }
        return albumCell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedPhoto = indexPath
        animateFullView()
        fvSpinner.startAnimating()
        albumData.requestPhotoFor(indexPath.row){ [weak self] albumPhoto, _, error in
            guard error == nil else{print("Errrrorrr!!!!"); return}
            guard let albumPhoto = albumPhoto else{print("PHOTO is NILLLLLLLL!!!!"); return}
            self?.fvSpinner.stopAnimating()
            self?.fullViewPhoto.image = albumPhoto.fullsizeImage
        }
    }
    
    
    let topView = UIImageView()
    let bottomView = UIImageView()
    
    
    func transitionWithoutAnimating(_ settingImage: UIImage){
        UIView.performWithoutAnimation{[weak self] in
            self?.transitionFullViewImageTo(settingImage)
        }
    }
    
    func transitionFullViewImageTo(_ settingImage: UIImage){
        topView.isUserInteractionEnabled = false
        bottomView.isUserInteractionEnabled = false
        if showingTopView{bottomView.image = settingImage}
        else{topView.image = settingImage}
        UIView.transition(
            from: showingTopView ? topView : bottomView,
            to: showingTopView ? bottomView : topView,
            duration: 0.7,
            options: [.showHideTransitionViews, .transitionCrossDissolve],
            completion: {[weak self] transitioned in
                self?.topView.isUserInteractionEnabled = true
                self?.bottomView.isUserInteractionEnabled = true
        })
        
        
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
    
    
// Need to configure this further.
    func setGestures(){
        let swipeRightRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(fullViewSwipeRight))
        swipeRightRecognizer.numberOfTouchesRequired = 1
        swipeRightRecognizer.direction = UISwipeGestureRecognizerDirection.right
        let swipeLeftRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(fullViewSwipeLeft))
        swipeLeftRecognizer.numberOfTouchesRequired = 1
        swipeLeftRecognizer.direction = UISwipeGestureRecognizerDirection.left
        fullViewPhoto?.addGestureRecognizer(swipeLeftRecognizer)
        fullViewPhoto?.addGestureRecognizer(swipeRightRecognizer)
        fullViewPhoto?.isUserInteractionEnabled = true
    }
    
    func updateFillModeAndButton(){
        guard let frames = albumData?.albumPin.albumFrames?.count else{return}
        guard let refillImage = UIImage(named: "World Refill"), let newImage = UIImage(named: "World New") else{return}
        if frames < FlickrCnst.Prefered.PhotosPerPage{
            fillMode = .refill
            newButton.setImage(refillImage, for: .normal)}
        else{ fillMode = .new
            newButton.setImage(newImage, for: .normal)}
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
