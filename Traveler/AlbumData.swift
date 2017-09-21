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
        var pinFound: Pin? = nil
        do{ pinFound  = try Traveler.shared.backgroundContext.fetch(searchForPin).first}
        catch{return nil}
        guard let thePin = pinFound else{return nil}
        //The Pin must have PhotoFrames from point of initialization, otherwise it's useless!!!
        guard let albumFrames = thePin.albumFrames?.allObjects as? [PhotoFrame], albumFrames.count != 0 else{return nil}
        self.albumPin = thePin
    }
    
    //Does the fetch/network call on a background queue and returns a closure onto the main queue
    func requestPhotoFor(_ albumLocation: Int, _ completion: @escaping (_ photo: TravelerPhoto?, _ error: LocalizedError?) -> Void){
        //Enter into the background serial queue for this task
        DispatchQueue.global(qos: .userInteractive).sync { [weak self] in
            //Check that this object still exists otherwise ignore the call to the method
            guard let albumID = self?.albumPin.uniqueID else{return}
            //Set the search criteria for a Photo frame that matches the location ID and the Frame's location within the Album.
            let searchForPhotoFrame: NSFetchRequest<PhotoFrame> = PhotoFrame.fetchRequest()
            let searchCriteria = NSPredicate(format: "albumLocation = %@ AND myLocation.uniqueID = %@", Int16(albumLocation), albumID)
            searchForPhotoFrame.predicate = searchCriteria
            //Execute the search and check for the resulting entity returned from the Database
            var frameFound: PhotoFrame?
            do{frameFound = try Traveler.shared.backgroundContext.fetch(searchForPhotoFrame).first}
            catch{ DispatchQueue.main.async{completion(nil, DatabaseError.general(dbDescription: error.localizedDescription))}; return}
            //If the frame is not found for the Pin and Album location, then something is wrong and we should return an error.
            guard let frame = frameFound else{ DispatchQueue.main.async {
                completion(nil, DatabaseError.general(dbDescription: "The Photo is missing from the DataBase"))}; return}
            //Otherwise we should see if a photo exists within the Frame and return it if so.
            if let photoFound = frame.myPhoto, let thumbnail = photoFound.thumbnail, let fullSize = photoFound.fullSize{
                let requestedPhoto = TravelerPhoto(thumbnail: thumbnail, fullsize: fullSize, photoID: frame.uniqueID!)
                DispatchQueue.main.async {completion(requestedPhoto, nil)}
                return
            }else{
                //If no Photo exists, then start pulling the info for retrieving the photo on the network
                guard let thumbnailString = frame.thumbnailURL, let thumbnailURL = URL(string: thumbnailString),
                    let fullSizeString = frame.fullSizeURL, let fullSizeURL = URL(string: fullSizeString) else{
                        DispatchQueue.main.async {completion(nil, DatabaseError.general(dbDescription: "The URLs are missing from the Database"))}
                        return}
                //Make the network call with the Frame's URL info
                flickrClient.getPhotoFor(thumbnailURL: thumbnailURL, fullSizeURL: fullSizeURL){ networkImage, error in
                    guard error == nil else{DispatchQueue.main.async {completion(nil, error!)};return}
                    guard let networkImage = networkImage, let networkThumb = networkImage.thumbnail, let networkFullSize = networkImage.fullSize else{
                        DispatchQueue.main.async {completion(nil, GeneralError.invalidURL)}; return}
                    //Start formating the Database Photo entity with the retrieved network data
                    let photoToSave = Photo(context: Traveler.shared.backgroundContext)
                    photoToSave.myFrame = frame
                    photoToSave.thumbnail = NSData(data: networkThumb)
                    photoToSave.fullSize = NSData(data: networkFullSize)
                    frame.myPhoto = photoToSave
                    //Commit the Photo data to the persistent container and return the image to the caller.
                    do{try Traveler.shared.backgroundContext.save()}
                    catch{DispatchQueue.main.async{completion(nil, DatabaseError.general(dbDescription: error.localizedDescription))}; return}
                    let requestedPhoto = TravelerPhoto(thumbnail: NSData(data: networkThumb), fullsize: NSData(data: networkFullSize), photoID: albumID)
                    DispatchQueue.main.async {completion(requestedPhoto, nil)}
                }
            }
        }
    }
    
    func requestRenewAlbum(_ completion: @escaping(_ error: LocalizedError?)->Void){
        //Enter into the background serial queue for this task
        DispatchQueue.global(qos: .userInteractive).sync { [weak self] in
            //Check that this object still exists otherwise ignore the call to the method
            guard let albumPin = self?.albumPin else{return}
            //Check to see if there are album frames existing and remove all if so.
            if let albumFrames = self?.albumPin.albumFrames{self?.albumPin.removeFromAlbumFrames(albumFrames)}
            //request frames saves upon completion. Add all the frames and save the changes.
            PinData.requestFramesFor(albumPin){ error in DispatchQueue.main.async {completion(error)}}
        }
    }
    
    
    func requestDeletePhotoFor(_ albumLocation: Int){
        
    }
    
    
    
    
    
    
    
    
    
    
}
