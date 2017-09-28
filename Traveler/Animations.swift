//
//  Animations.swift
//  Traveler
//
//  Created by Stephen Martinez on 5/16/17.
//  Copyright © 2017 Stephen Martinez. All rights reserved.
//

import UIKit
import MapKit

extension TravelMapViewController{
    
    //Animates a Pin-Drop for newly made pins or when map opens for first time.
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        for pinView in views{
            if let pin = pinView.annotation as? PinAnnotation, pin.needsDrop{
                pin.needsDrop = false
                let landingLocation = pinView.frame
                pinView.frame = CGRect(
                    x: pinView.frame.origin.x,
                    y: pinView.frame.origin.y - self.view.frame.size.height,
                    width: pinView.frame.size.width,
                    height: pinView.frame.size.height)
                UIView.animate(
                    withDuration: 0.5, delay: 0,
                    usingSpringWithDamping: 0.5,
                    initialSpringVelocity: 2,
                    options: .curveLinear,
                    animations: ({pinView.frame = landingLocation}),
                    completion: nil)
            }
        }
    }
    
    func animateMessage(show: Bool){
        switch show{
        case true: UIView.animate(withDuration: 0.5, animations:
        {success in self.leftMessage.alpha = 1; self.rightMessage.alpha = 1})
        case false: UIView.animate(withDuration: 0.5, animations:
        {success in self.leftMessage.alpha = 0; self.rightMessage.alpha = 0})
        }
    }
    
    func goToLocationAlbum(){
        UIView.animate(withDuration: 0.2, animations:{
            self.bottomTray.transform = CGAffineTransform(
                translationX: self.bottomTray.frame.origin.x,
                y: self.bottomTray.frame.height)}, completion: {completed in
                    self.performSegue(withIdentifier: "ShowAlbumViewController", sender: self)})
    }
    
    func lowerBottomTray(completionHandler: (()-> Void)?){
        UIView.animate(withDuration: 0.2, animations:{
            self.bottomTray.transform = CGAffineTransform(
                translationX: self.bottomTray.frame.origin.x,
                y: self.bottomTray.frame.height)},
                       completion: {completed in if let handler = completionHandler{handler()}})
    }
    
    func showBottomTray(){
        UIView.animate(withDuration: 0.4, animations:
            {self.bottomTray.transform = .identity})
    }
}



extension AlbumViewController{
    
    func moveTrayDown(animated: Bool, completionHandler: (()-> Void)?){
        let centered = self.collectionTray.frame.origin.x
        let lowered = self.collectionTray.frame.height
        if animated{
            UIView.animate( withDuration: 0.5,
                            animations: {self.collectionTray.transform = CGAffineTransform(translationX: centered, y: lowered)},
                            completion:{completed in if let handler = completionHandler{handler()}})}
        else{
            self.collectionTray.transform = CGAffineTransform(translationX: centered, y: lowered)
            if let handler = completionHandler{handler()}
        }
    }
    
    func moveTrayUp(){
        if trayRemovalFlag{return}
        UIView.animate(withDuration: 0.5,
                       animations: {self.collectionTray.transform = .identity},
                       completion: {completed in if self.trayRemovalFlag{
                        self.moveTrayDown(animated: true, completionHandler: nil)}})
    }
    
    func animateTrayRefill(_ actionWhileTrayDown: (()->Void)?){
        moveTrayDown(animated: true, completionHandler: {
            if let action = actionWhileTrayDown{action()}
            self.moveTrayUp()
        })
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
    
    //Use this method to zoom the map on the target location (in viewDidAppear)
    func zoomMapToTarget(){
        //Acquire the zoom target to make the region we'll zoom in on
        guard let zoomTarget = TravelerCnst.map.zoomTarget else{print("The zoom target was nil");return}
        let zoomRegion = MKCoordinateRegionMakeWithDistance( zoomTarget,
            TravelerCnst.map.regionSize,
            TravelerCnst.map.regionSize)
        //Zoom onto the region
        albumLocationMap.setRegion(zoomRegion, animated: true)
        //Drop the pin onto the location we're viewing
        albumLocationMap.addAnnotation(selectedPin)
    }
    
    
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        for pinView in views{
            if let pin = pinView.annotation as? PinAnnotation, pin.needsDrop{
                pin.needsDrop = false
                let landingLocation = pinView.frame
                pinView.frame = CGRect(
                    x: pinView.frame.origin.x,
                    y: pinView.frame.origin.y - self.view.frame.size.height,
                    width: pinView.frame.size.width,
                    height: pinView.frame.size.height)
                UIView.animate(
                    withDuration: 0.5, delay: 0,
                    usingSpringWithDamping: 0.5,
                    initialSpringVelocity: 2,
                    options: .curveLinear,
                    animations: ({pinView.frame = landingLocation}),
                    completion: nil)
            }
        }
    }
    
    
    func changeButton(refill: Bool){
        if refill{
            if fillMode != .refill{
            UIView.animate( withDuration: 0.5, animations:{self.newButton?.setImage(UIImage(named: "World Refill"), for: .normal)})
            fillMode = .refill
            }
        }
        else{
            if fillMode != .new{
            UIView.animate(withDuration: 0.5, animations:{self.newButton?.setImage(UIImage(named: "World New"), for: .normal)})
            fillMode = .new
            }
        }
    }
    
    
    func animateFullView(){
        fullView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(fullView)
        NSLayoutConstraint.activate([
            fullView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0),
            fullView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            fullView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0),
            fullView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0),
            fullView.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0),
            fullView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 0)
            ])
        UIView.animate(withDuration: 0.7, delay: 0.3, options: .curveEaseIn, animations: {
            self.fvBackButton.alpha = 1
            self.fvDeleteButton.alpha = 1
        }, completion: nil)
        UIView.animate(withDuration: 0.3, animations:{
            self.fvBlur.effect = UIBlurEffect(style: .regular)
        }){completed in
            UIView.animate(withDuration: 0.6, animations: {
                self.fvGrayBackground.alpha = 1
                self.fullViewPhoto.alpha = 1
            })
        }
    }
    
    
    func animateRemoveFullView(){
        UIView.animate(withDuration: 0.3, animations: {
            self.fvSpinner.stopAnimating()
            self.fvBackButton.alpha = 0
            self.fvDeleteButton.alpha = 0
            self.fullViewPhoto.alpha = 0
            self.fvGrayBackground.alpha = 0
            self.fvBlur.effect = nil
        }, completion: {completion in
            self.fullViewPhoto.image = nil
            self.fullView.removeFromSuperview()
        })
    }
    
    
}


