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
                    completion: nil
                )
                
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
    
    
}
