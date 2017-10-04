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
    
    private let albumPin: Pin
    //Only this class is allowed to update this frameCount
    private(set) var frameCount: Int
 
    //Instantiates with associated Pin and Initial FrameCount that will need to be updated with changes
    init(pin: Pin, frameCount: Int){
        self.albumPin = pin
        self.frameCount = frameCount
    }
    
    func updateFrameCount(){
        //Enter into the background serial queue for this task
        Traveler.shared.backgroundContext.performAndWait {[weak self] in
            //Check that this object still exists otherwise ignore the call to the method
            guard let albumID = self?.albumPin.uniqueID else{return}
            //Set the search criteria for a Photo frames that match the Unique ID of this location.
            let searchForPhotoFrames: NSFetchRequest<PhotoFrame> = PhotoFrame.fetchRequest()
            let searchCriteria = NSPredicate(format: "myLocation.uniqueID = %@", albumID)
            searchForPhotoFrames.predicate = searchCriteria
            var countOfFrames: Int?
            //Ask the database to run the query in SQL and bring back the result
            countOfFrames = try? Traveler.shared.backgroundContext.count(for: searchForPhotoFrames)
            //Return the resulting number of frames or default to zero if an error has occured
            self?.frameCount = countOfFrames ?? 0
        }
    }
    
    func requestPhotoFor(_ albumLocation: Int, _ completion: @escaping (_ photo: TravelerPhoto?, _ freshLoad: Bool?, _ error: LocalizedError?) -> Void){
        //Enter into the background serial queue for this task
        Traveler.shared.backgroundContext.performAndWait {[weak self] in
            //Check that this object still exists otherwise ignore the call to the method
            guard let albumID = self?.albumPin.uniqueID else{return}
            //Set the search criteria for a Photo frame that matches the location ID and the Frame's location within the Album.
            let searchForPhotoFrame: NSFetchRequest<PhotoFrame> = PhotoFrame.fetchRequest()
            let location = NSNumber(value: albumLocation)
            let searchCriteriaOne = NSPredicate(format: "albumLocation = %@", location)
            let searchCriteriaTwo = NSPredicate(format: "myLocation.uniqueID = %@", albumID)
            let compoundCriteria = NSCompoundPredicate(type: NSCompoundPredicate.LogicalType.and, subpredicates: [searchCriteriaOne, searchCriteriaTwo])
            searchForPhotoFrame.predicate = compoundCriteria
            //Execute the search and check for the resulting entity returned from the Database
            var frameFound: PhotoFrame?
            do{frameFound = try Traveler.shared.backgroundContext.fetch(searchForPhotoFrame).first}
            catch{ DispatchQueue.main.async{completion(nil, nil,DatabaseError.general(dbDescription: error.localizedDescription))}; return}
            //If the frame is not found for the Pin and Album location, then something is wrong and we should return an error.
            guard let frame = frameFound else{ DispatchQueue.main.async {
                completion(nil, nil,DatabaseError.general(dbDescription: "The Photo is missing from the DataBase"))}; return}
            //Otherwise we should see if a photo exists within the Frame and return it if so.
            if let photoFound = frame.myPhoto, let thumbnail = photoFound.thumbnail, let fullSize = photoFound.fullSize{
                let requestedPhoto = TravelerPhoto(thumbnail: thumbnail, fullsize: fullSize, photoID: frame.uniqueID!)
                DispatchQueue.main.async {completion(requestedPhoto, false, nil)}
                return
            }else{
                //If no Photo exists, then start pulling the info for retrieving the photo on the network
                guard let thumbnailString = frame.thumbnailURL, let thumbnailURL = URL(string: thumbnailString),
                    let fullSizeString = frame.fullSizeURL, let fullSizeURL = URL(string: fullSizeString) else{
                        DispatchQueue.main.async {completion(nil, nil,DatabaseError.general(dbDescription: "The URLs are missing from the Database"))}
                        return}
                //Make the network call with the Frame's URL info
                FlickrClient.getPhotoFor(thumbnailURL: thumbnailURL, fullSizeURL: fullSizeURL){ networkImage, error in
                    Traveler.shared.backgroundContext.performAndWait {
                        guard error == nil else{DispatchQueue.main.async {completion(nil, nil, error!)};return}
                        guard let networkImage = networkImage, let networkThumb = networkImage.thumbnail, let networkFullSize = networkImage.fullSize else{
                            DispatchQueue.main.async {completion(nil, nil, GeneralError.invalidURL)}; return}
                        //Start formating the Database Photo entity with the retrieved network data
                        let photoToSave = Photo(context: Traveler.shared.backgroundContext)
                        photoToSave.myFrame = frame
                        photoToSave.thumbnail = NSData(data: networkThumb)
                        photoToSave.fullSize = NSData(data: networkFullSize)
                        frame.myPhoto = photoToSave
                        //Commit the Photo data to the persistent container and return the image to the caller.
                        do{try Traveler.shared.backgroundContext.save()}
                        catch{DispatchQueue.main.async{completion(nil, nil, DatabaseError.general(dbDescription: error.localizedDescription))}; return}
                        let requestedPhoto = TravelerPhoto(thumbnail: NSData(data: networkThumb), fullsize: NSData(data: networkFullSize), photoID: albumID)
                        DispatchQueue.main.async {completion(requestedPhoto, true, nil)}
                    }
                }
            }
        }
    }
    
    func requestRenewAlbum(_ completion: @escaping(_ error: LocalizedError?)->Void){
        //Enter into the background serial queue for this task
        Traveler.shared.backgroundContext.performAndWait {[weak self] in
            //Check that this object still exists otherwise ignore the call to the method
            guard let albumPin = self?.albumPin, let albumID = albumPin.uniqueID else{return}
            //Create a Fecth request to pull up all existing PhotoFrames for the Pin
            let searchForPhotoFrames: NSFetchRequest<PhotoFrame> = PhotoFrame.fetchRequest()
            let searchCriteria = NSPredicate(format: "myLocation.uniqueID = %@", albumID)
            searchForPhotoFrames.predicate = searchCriteria
            var potentialFramesToDelete: [PhotoFrame]?
            //Collect all the Frames to delete
            do{potentialFramesToDelete = try Traveler.shared.backgroundContext.fetch(searchForPhotoFrames)}
            catch{DispatchQueue.main.async{completion(DatabaseError.general(dbDescription: error.localizedDescription))}; return}
            if let framesToDelete = potentialFramesToDelete{
                //Ideally A Batch Delete Request would be implemented here, but cant seem to get the context to merge changes,
                //Being that there's less than 30 photos, this will work too.
                for frame in framesToDelete{Traveler.shared.backgroundContext.delete(frame)}}
            //Save the deletion request in the context.
            do{try Traveler.shared.backgroundContext.save()}
            catch{DispatchQueue.main.async{completion(DatabaseError.general(dbDescription: error.localizedDescription))}; return}
            //Update the frameCount for PhotoData / Should be Zero at this point
            self?.updateFrameCount()
            //request frames saves upon completion. Add all the frames and save the changes.
            PinData.requestFramesFor(albumPin, false){ error in
                Traveler.shared.backgroundContext.performAndWait {[weak self] in
                    //Update the frameCount for PhotoData / Should be the amount of frames brought back at this point
                    self?.updateFrameCount()
                    //Send result through completion onto the main Queue
                    DispatchQueue.main.async {completion(error)}}}
            //Delete any Dangling Photos that have escaped the Cascading Delete Rule on PhotoFrame Entity
            PinData.requestDeleteNullPhotos()
        }
    }
    
    func requestRefillAlbum(_ completion: @escaping(_ albumLocations: [Int]?, _ error: LocalizedError?)->Void){
        //Enter into the background serial queue for this task
        Traveler.shared.backgroundContext.performAndWait {[weak self] in
            //Check that this object still exists otherwise ignore the call to the method
            guard let albumPin = self?.albumPin else{return}
            //request frames saves upon completion. Add all the frames and save the changes.
            PinData.requestRemainingFramesFor(albumPin){ aLocs, error in
                Traveler.shared.backgroundContext.performAndWait {[weak self] in
                    //Update the frameCount for PhotoData / Should be the amount of frames brought back plus existing
                    self?.updateFrameCount()
                    //Send result through completion onto the main Queue
                    DispatchQueue.main.async {completion(aLocs, error)}
                }
            }
        }
    }
    
    func requestDeletePhotoFor(_ albumLocation: Int, completion: @escaping(_ error: DatabaseError?)->Void){
        //Enter into the background serial queue for this task
        Traveler.shared.backgroundContext.performAndWait {[weak self] in
            //Check that this object still exists otherwise ignore the call to the method
            guard let albumID = self?.albumPin.uniqueID else{return}
            //Set the search criteria for Photo frames that are = to or > than the frame's location within the Album and matches the Album ID.
            let searchForPhotoFrames: NSFetchRequest<PhotoFrame> = PhotoFrame.fetchRequest()
            let location = NSNumber(value: albumLocation)
            let searchCriteriaOne = NSPredicate(format: "albumLocation >= %@", location)
            let searchCriteriaTwo = NSPredicate(format: "myLocation.uniqueID = %@", albumID)
            let compoundCriteria = NSCompoundPredicate(type: NSCompoundPredicate.LogicalType.and, subpredicates: [searchCriteriaOne, searchCriteriaTwo])
            //Set the sorting rules for the returned entities
            let sortByLocation = NSSortDescriptor(key: "albumLocation", ascending: true)
            searchForPhotoFrames.predicate = compoundCriteria
            searchForPhotoFrames.sortDescriptors = [sortByLocation]
            //Retrieve the requested PhotoFrames in the order requested
            var framesToUpdate: [PhotoFrame]?
            do{framesToUpdate = try Traveler.shared.backgroundContext.fetch(searchForPhotoFrames)}
            catch{DispatchQueue.main.async {completion(DatabaseError.general(dbDescription: error.localizedDescription))};return}
            //Check to see if anything was returned
            guard var orderedFrames = framesToUpdate
                else{DispatchQueue.main.async {completion(DatabaseError.general(dbDescription: "No PhotoFrame was found to delete"))}; return}
            //Pull out the PhotoFrame to delete, then delete it from the DataBase
            let frameToDelete = orderedFrames.removeFirst()
            print("Frame with \(String(describing: frameToDelete.uniqueID!)) is prepared for deletion")
            Traveler.shared.backgroundContext.delete(frameToDelete)
            //Then update the remaining Frame's locations inside the album by decrementing each of them by one.
            for frame in orderedFrames{
                print("Frame # \(String(describing: frame.albumLocation)) is being updated to:")
                frame.albumLocation -= 1
                print("# \(String(describing: frame.albumLocation))")
            }
            // Save the changes in the database
            do{try Traveler.shared.backgroundContext.save()}
            catch{DispatchQueue.main.async {completion(DatabaseError.general(dbDescription: error.localizedDescription))}}
            //Reaching this point means the changes were succefully saved. Update the frameCount now.
            self?.updateFrameCount()
            //Return the completion onto the main queue
            DispatchQueue.main.async {completion(nil)}
        }
    }
    
}
