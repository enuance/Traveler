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
    @IBOutlet weak var fVTopPhoto: UIImageView!
    @IBOutlet weak var fVBottomPhoto: UIImageView!
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
    
    override func viewDidLoad() {super.viewDidLoad()
        fvBlur?.effect = nil
        fVTopPhoto?.layer.cornerRadius = 6
        fVBottomPhoto?.layer.cornerRadius = 6
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
    
    @IBAction func back(_ sender: Any) {
        moveTrayDown( animated: true, completionHandler: {
            //Delete Any Dangling Photos that have escaped from the Cascading Deletion rule on PhotoFrame
            PinData.requestDeleteNullPhotos()
            //Pop off the Nav Stack
            self.navigationController?.popViewController(animated: true)})
    }
    
    @IBAction func newAlbum(_ sender: UIButton) {
        switch fillMode {
        case .new: renewAlbum()
        case .refill: refillAlbum()
        }
    }
    
    @IBAction func fullViewBack(_ sender: Any) {animateRemoveFullView()}
    
    @IBAction func fullViewDelete(_ sender: Any) {
        albumData.requestDeletePhotoFor(selectedPhoto.row){ [weak self] error in
            guard let selectedPhoto = self?.selectedPhoto else{return}
            guard error == nil else{
                SendToDisplay.error(self!,
                                    errorType: "Database Error",
                                    errorMessage: error!.localizedDescription,
                                    assignment: {self?.animateRemoveFullView()})
                return}
            self?.albumCollection.deleteItems(at: [selectedPhoto])
            self?.fVTopPhoto.image = TravelerCnst.clearPlaceholder
            self?.fVBottomPhoto.image = TravelerCnst.clearPlaceholder
            self?.updateFillModeAndButton()
            self?.animateRemoveFullView()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return albumData.frameCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let albumCell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCollectionCell",for: indexPath) as! AlbumCollectionCell
        albumCell.layer.cornerRadius = 5
        loadingStatusFor(albumCell, isLoading: true)
        albumData.requestPhotoFor(indexPath.row){ [weak self] albumPhoto, freshLoad, error in
            guard error == nil else{self?.errorHandlerForCollectionView(error!); return}
            guard let frameCount = self?.albumData.frameCount else{return}
            //Check to see if the FrameCount has changed and therefore no longer useable for this
            guard indexPath.row <= (frameCount - 1) else{return}
            //Check to see if the photo and freshLoad flag are Nil
            guard let albumPhoto = albumPhoto, let freshLoad = freshLoad else{ return}
            //If the photo was freshly loaded from a network call then reload the individual cell item's location
            if freshLoad{collectionView.reloadItems(at: [indexPath])}
            //Otherwise set the cell's image directly
            else{self?.loadingStatusFor(albumCell, isLoading: false)
                albumCell.cellThumbnail.image = albumPhoto.thumbnailImage}
        }
        return albumCell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedPhoto = indexPath
        animateFullView()
        fvSpinner.startAnimating()
        albumData.requestPhotoFor(indexPath.row){ [weak self] albumPhoto, _, error in
            guard error == nil else{self?.errorHandlerForFullView(error!); return}
            guard let albumPhoto = albumPhoto else{return}
            self?.fvSpinner.stopAnimating()
            self?.fVTopPhoto.image = albumPhoto.fullsizeImage
            self?.fVBottomPhoto.image = albumPhoto.fullsizeImage
        }
    }
    
    func renewAlbum(){
        newButton.isEnabled = false
        moveTrayDown(animated: true){ [weak self] in
            self?.albumData.requestRenewAlbum(){  error in
                guard error == nil else{
                    self?.errorHandlerForAlbumFill(.new, error!)
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
                self?.errorHandlerForAlbumFill(.refill, error!)
                return}
            let pathsNeedingInsertion = TravelerCnst.createIndexPathsFor(section: 0, albumLocs)
            self?.albumCollection.insertItems(at: pathsNeedingInsertion)
            self?.updateFillModeAndButton()
            self?.newButton.isEnabled = true
        }
    }
    
    //Moves Right Through Photo Array
    func fullViewSwipeLeft(){
        //Check if we're already at the begining of the Album
        let endOfAlbum = albumData.frameCount - 1
        guard selectedPhoto.row < endOfAlbum else{print("Already at the End");return}
        transitionFullViewImageTo(TravelerCnst.clearPlaceholder, duration: 0.3)
        fvSpinner?.startAnimating()
        selectedPhoto.row += 1
        let newSelectedPhoto = selectedPhoto.row
        albumData.requestPhotoFor(newSelectedPhoto){ [weak self] travelerPhoto, freshLoad, error in
            guard let currentlyRequestedPhoto = self?.selectedPhoto?.row else{return}
            guard self != nil else{return}
            guard newSelectedPhoto == currentlyRequestedPhoto else{print("User No longer wants this photo");return}
            guard error == nil else{ self?.errorHandlerForFullView(error!); return}
            guard let albumPhoto = travelerPhoto else{
                SendToDisplay.error(self!,
                                    errorType: "Error",
                                    errorMessage: GeneralError.AccessingNil.localizedDescription,
                                    assignment: {self?.animateRemoveFullView()})
                print("AlbumPhoto is nil");return}
            self?.fvSpinner.stopAnimating()
            self?.transitionFullViewImageTo(albumPhoto.fullsizeImage, duration: 0.6)
        }
    }
    
    //Moves Left through the Photo Array
    func fullViewSwipeRight(){
        //Check if we're already at the begining of the Album
        guard selectedPhoto.row > 0 else{print("Already at the beginning");return}
        transitionFullViewImageTo(TravelerCnst.clearPlaceholder, duration: 0.3)
        fvSpinner?.startAnimating()
        selectedPhoto.row -= 1
        let newSelectedPhoto = selectedPhoto.row
        albumData.requestPhotoFor(newSelectedPhoto){ [weak self] travelerPhoto, freshLoad, error in
            guard let currentlyRequestedPhoto = self?.selectedPhoto?.row else{return}
            guard self != nil else{return}
            guard newSelectedPhoto == currentlyRequestedPhoto else{print("User No longer wants this photo");return}
            guard error == nil else{ self?.errorHandlerForFullView(error!) ;return}
            guard let albumPhoto = travelerPhoto else{
                SendToDisplay.error(self!,
                                    errorType: "Error",
                                    errorMessage: GeneralError.AccessingNil.localizedDescription,
                                    assignment: {self?.animateRemoveFullView()})
                print("AlbumPhoto is nil");return}
            self?.fvSpinner.stopAnimating()
            self?.transitionFullViewImageTo(albumPhoto.fullsizeImage, duration: 0.6)
        }
    }
    
}






extension AlbumViewController: UICollectionViewDelegate, UICollectionViewDataSource, MKMapViewDelegate{
    
    //Sets the layout of the CollectionView
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
    
    //Sets the Swiping Gesture recognitions for the FullView Pop up
    func setGestures(){
        let swipeRightRecognizerTop = UISwipeGestureRecognizer(target: self, action: #selector(fullViewSwipeRight))
        swipeRightRecognizerTop.numberOfTouchesRequired = 1
        swipeRightRecognizerTop.direction = UISwipeGestureRecognizerDirection.right
        let swipeLeftRecognizerTop = UISwipeGestureRecognizer(target: self, action: #selector(fullViewSwipeLeft))
        swipeLeftRecognizerTop.numberOfTouchesRequired = 1
        swipeLeftRecognizerTop.direction = UISwipeGestureRecognizerDirection.left
        let swipeRightRecognizerBottom = UISwipeGestureRecognizer(target: self, action: #selector(fullViewSwipeRight))
        swipeRightRecognizerBottom.numberOfTouchesRequired = 1
        swipeRightRecognizerBottom.direction = UISwipeGestureRecognizerDirection.right
        let swipeLeftRecognizerBottom = UISwipeGestureRecognizer(target: self, action: #selector(fullViewSwipeLeft))
        swipeLeftRecognizerBottom.numberOfTouchesRequired = 1
        swipeLeftRecognizerBottom.direction = UISwipeGestureRecognizerDirection.left
        fVTopPhoto?.addGestureRecognizer(swipeLeftRecognizerTop)
        fVTopPhoto?.addGestureRecognizer(swipeRightRecognizerTop)
        fVTopPhoto?.isUserInteractionEnabled = true
        fVBottomPhoto?.addGestureRecognizer(swipeLeftRecognizerBottom)
        fVBottomPhoto?.addGestureRecognizer(swipeRightRecognizerBottom)
        fVBottomPhoto?.isUserInteractionEnabled = true
    }
    
    //Updates the Mode of the renew/refill button on the album
    func updateFillModeAndButton(){
        guard let frames = albumData?.frameCount else{return}
        guard let refillImage = UIImage(named: "World Refill"), let newImage = UIImage(named: "World New") else{return}
        if frames < FlickrCnst.Prefered.PhotosPerPage{
            fillMode = .refill
            newButton.setImage(refillImage, for: .normal)}
        else{ fillMode = .new
            newButton.setImage(newImage, for: .normal)}
    }
    
    //Sets the map in the background to provide contect for the location of the album
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
    
    //........................................................................................
    //         Section For Error Handling Specific to this ViewController
    //........................................................................................
    func errorHandlerForCollectionView(_ error: LocalizedError){
        switch error{
        case let gError as GeneralError:
            SendToDisplay.error(self,
                                errorType: "Error",
                                errorMessage: gError.localizedDescription,
                                assignment: {self.navigationController?.popViewController(animated: true)})
        case let dbError as DatabaseError:
            SendToDisplay.error(self,
                                errorType: "Database Error",
                                errorMessage: dbError.localizedDescription,
                                assignment: {self.navigationController?.popViewController(animated: true)})
        case let netError as NetworkError:
            SendToDisplay.error(self,
                                errorType: "Network Error",
                                errorMessage: netError.localizedDescription,
                                assignment: {self.navigationController?.popViewController(animated: true)})
        default: print("Unexpected Error from this type of call")}
    }
    
    func errorHandlerForAlbumFill(_ type: FillMode ,_ error: LocalizedError){
        switch error{
        case let gError as GeneralError:
            SendToDisplay.error(self,
                                errorType: "No Photos Found",
                                errorMessage: gError.localizedDescription,
                                assignment: { switch type{
                                case .new:
                                    self.albumCollection.reloadData()
                                    self.moveTrayUp()
                                    self.newButton.isEnabled = true
                                case .refill:
                                    self.newButton.isEnabled = true}})
        case let dbError as DatabaseError:
            SendToDisplay.error(self,
                                errorType: "Database Error",
                                errorMessage: dbError.localizedDescription,
                                assignment: {self.navigationController?.popViewController(animated: true)})
        case let netError as NetworkError:
            SendToDisplay.error(self,
                                errorType: "Network Error",
                                errorMessage: netError.localizedDescription,
                                assignment: {self.navigationController?.popViewController(animated: true)})
        default: print("Unexpected Error from this type of call")}
    }
    
    func errorHandlerForFullView(_ error: LocalizedError){
        switch error{
        case let gError as GeneralError:
            SendToDisplay.error(self,
                                errorType: "Error",
                                errorMessage: gError.localizedDescription,
                                assignment: {self.animateRemoveFullView()})
        case let dbError as DatabaseError:
            SendToDisplay.error(self,
                                errorType: "Database Error",
                                errorMessage: dbError.localizedDescription,
                                assignment: {self.animateRemoveFullView()})
        case let netError as NetworkError:
            SendToDisplay.error(self,
                                errorType: "Network Error",
                                errorMessage: netError.localizedDescription,
                                assignment: {self.animateRemoveFullView()})
        default: print("Unexpected Error from this type of call")}
    }
    
}
