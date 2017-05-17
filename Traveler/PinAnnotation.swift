//
//  PinAnnotation.swift
//  Traveler
//
//  Created by Stephen Martinez on 5/15/17.
//  Copyright © 2017 Stephen Martinez. All rights reserved.
//

import Foundation
import MapKit

class PinAnnotation: NSObject, MKAnnotation{
    
    var coordinate: CLLocationCoordinate2D
    var uniqueIdentifier: String?
    var needsDrop: Bool = true
    
    init(coordinate: CLLocationCoordinate2D, uniqueIdentifier: String?){
        self.coordinate = coordinate
        self.uniqueIdentifier = uniqueIdentifier
    }
}
