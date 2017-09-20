//
//  AlbumData.swift
//  Traveler
//
//  Created by Stephen Martinez on 9/18/17.
//  Copyright © 2017 Stephen Martinez. All rights reserved.
//

import UIKit
import CoreData

class AlbumData{
    
    let albumPin: Pin
    var latitude: String{get{return String(albumPin.latitude)}}
    var longitude: String{get{return String(albumPin.longitude)}}
    var frameCount: Int{ get{
        guard let albumFrames = albumPin.albumFrames?.allObjects as? [PhotoFrame] else{return 0}
        return albumFrames.count}}
    
    init?(pinID: String){
        let searchForPin: NSFetchRequest<Pin> = Pin.fetchRequest()
        let pinSearchCriteria = NSPredicate(format: "uniqueID = %@", pinID)
        searchForPin.predicate = pinSearchCriteria
        var pinFound: Pin! = nil
        do{ pinFound  = try Traveler.shared.backgroundContext.fetch(searchForPin).first}
        catch{return nil}
        guard let thePin = pinFound else{return nil}
        //The Pin must have PhotoFrames from point of initialization, otherwise it's useless!!!
        guard let albumFrames = thePin.albumFrames?.allObjects as? [PhotoFrame], albumFrames.count != 0 else{return nil}
        self.albumPin = thePin
    }
    
    
    
    
    func requestPhotoFor(_ albumLocation: Int, _ completion: @escaping () -> Void){
        let searchForPhotoFrame: NSFetchRequest<PhotoFrame> = PhotoFrame.fetchRequest()
        let searchCriteria = NSPredicate(format: "albumLocation = %@ AND myLocation.uniqueID = %@", Int16(albumLocation), albumPin.uniqueID!)
        
        
        
        
        
        
        
        
    }
    
    
    
    
    
    func requestDeletePhotoFor(_ albumLocation: Int){
        
    }
    
}
