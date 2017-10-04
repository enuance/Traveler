//
//  PinData.swift
//  Traveler
//
//  Created by Stephen Martinez on 9/18/17.
//  Copyright © 2017 Stephen Martinez. All rights reserved.
//

import UIKit
import CoreData

class PinData{
    
    //Caution: This Method Returns it's completion on a Concurrent Queue (Not the Main Queue).
    //Forcing this method onto the Main Queue will cause unexpected errors, potentially fatal.
    static func requestAlbumData(with pinID: String, _ completion: @escaping (_ pins: AlbumData?, _ error: DatabaseError?) -> Void){
        Traveler.shared.backgroundContext.performAndWait {
            let requestPin: NSFetchRequest<Pin> = Pin.fetchRequest()
            let requestFrameCount: NSFetchRequest<PhotoFrame> = PhotoFrame.fetchRequest()
            let pinSearchCriteria = NSPredicate(format: "uniqueID = %@", pinID)
             let frameSearchCriteria = NSPredicate(format: "myLocation.uniqueID = %@", pinID)
            requestPin.predicate = pinSearchCriteria
            requestFrameCount.predicate = frameSearchCriteria
            var returnedPin: Pin?
            do{returnedPin = try Traveler.shared.backgroundContext.fetch(requestPin).first}
            catch{completion(nil, DatabaseError.general(dbDescription: error.localizedDescription));return}
            guard let verifiedPin = returnedPin else{completion(nil, DatabaseError.objectReturnedNil(object: "Pin"));return}
            var countOfFrames: Int?
            countOfFrames = try? Traveler.shared.backgroundContext.count(for: requestFrameCount)
            let numberOfFrames = countOfFrames ?? 0
            let albumData = AlbumData(pin: verifiedPin, frameCount: numberOfFrames)
            completion(albumData, nil)
        }
    }
    
    static func requestAllPins( _ completion: @escaping (_ pins: [PinAnnotation]?, _ error: DatabaseError?) -> Void){
        Traveler.shared.backgroundContext.performAndWait {
            let requestForPins: NSFetchRequest<Pin> = Pin.fetchRequest()
            do{ let returnedPins = try Traveler.shared.backgroundContext.fetch(requestForPins)
                //Create an empty list for collecting annotations
                var returnedAnnotations = [PinAnnotation]()
                //Start looping through and converting all returned pins into annotations
                for pin in returnedPins{
                    //Convert the returned Pin into an annotation
                    let possiblePin = TravelerCnst.convertToPinAnnotation(with: pin)
                    //Check for proper conversion to pin annotation
                    guard let verifiedPin = possiblePin.pinAnnotation else{
                        //Return the error to the main queue
                        DispatchQueue.main.async {completion(nil, DatabaseError.inconvertableObject(object: "PinAnnotation"))}
                        return} //Start collecting the annotations in a list
                    returnedAnnotations.append(verifiedPin)}
                //Return the list of annotations through the completion call in the main queue
                DispatchQueue.main.async {completion(returnedAnnotations, nil)}
                return}
            catch{ //Getting here means an error was caught and should be handed to the caller
                DispatchQueue.main.async {completion(nil, DatabaseError.general(dbDescription: error.localizedDescription))}
                return
            }
        }
    }
    
    static func requestPinDeletion(_ uniqueID: String, _ completion: @escaping (_ error: DatabaseError?) -> Void ){
        //Enter into background Serial queue
       Traveler.shared.backgroundContext.performAndWait {
            let requestPinToDelete: NSFetchRequest<Pin> = Pin.fetchRequest()
            //Search criteia should bring the one Pin that has the Unique ID
            let searchCriteria = NSPredicate(format: "uniqueID = %@", uniqueID)
            requestPinToDelete.predicate = searchCriteria
            //Fetch the requested Pin
            var pinToDelete: Pin! = nil
            do{pinToDelete = try Traveler.shared.backgroundContext.fetch(requestPinToDelete).first}
            catch{DispatchQueue.main.async {
                completion(DatabaseError.general(dbDescription: error.localizedDescription))}
                return}
            //Check to see if a Pin was retrieved or not.
            if let aPinToDelete = pinToDelete{
                //Check if the Pin is still being worked on by another task before conflicting with it
                if aPinToDelete.hasChanges{
                    DispatchQueue.main.async {completion(DatabaseError.operationInProgress)};return}
                //If not other tasks are operating on it then procede with deletion
                Traveler.shared.backgroundContext.delete(aPinToDelete)
                print("A Pin with ID \(uniqueID) has been deleted")
                //Once it's deleted we need to save the context!
                do{try Traveler.shared.backgroundContext.save()}
                catch{DispatchQueue.main.async {completion(DatabaseError.general(dbDescription: error.localizedDescription))};return}}
            //Getting to this point means the task has successfully completed.
            DispatchQueue.main.async {completion(nil)}
            return
        }
    }
    
    static func requestPinSave(_ pin: PinAnnotation, _ completion: @escaping (_ error: LocalizedError?) -> Void){
        Traveler.shared.backgroundContext.performAndWait {
            //Create a Pin entity and start setting it's attributes
            let pinToAdd = Pin(context: Traveler.shared.backgroundContext)
            pinToAdd.uniqueID = pin.uniqueIdentifier
            pinToAdd.latitude = pin.coordinate.latitude
            pinToAdd.longitude = pin.coordinate.longitude
            //Load up all the Photo frames for the Pin and return whether or not there was an error
            requestFramesFor(pinToAdd, true){ error in DispatchQueue.main.async {completion(error)}}
        }
    }

    //Note: Only use this method on a queue provided by Traveler.shared.backGroundContext.
    static func requestFramesFor(_ pin: Pin, _ deleteIfNoPhotos: Bool, completion: @escaping (_ error: LocalizedError?)->Void){
        Traveler.shared.backgroundContext.performAndWait {
        //Set up the longitude and latitude and start the network call for the Frames
        let lat = String(pin.latitude); let lon = String(pin.longitude)
        FlickrClient.photosForLocation(latitude: lat, longitude: lon){photoFrameList, error in
            Traveler.shared.backgroundContext.performAndWait {
            guard error == nil else{completion(error);return}
            //If there are no photos produced in the search then return the no results error.
            guard let photoFrameList = photoFrameList, photoFrameList.count != 0 else{
                //Send a deletion call for the pin for the next time the context is saved
                if deleteIfNoPhotos{Traveler.shared.backgroundContext.delete(pin)}
                completion(GeneralError.PhotoSearchYieldedNoResults)
                return}
            //Start adding the PhotoFrames to the Pin
            for (position, frame) in photoFrameList.enumerated(){
                let frameToAdd = PhotoFrame(context: Traveler.shared.backgroundContext)
                frameToAdd.albumLocation = Int16(position)
                frameToAdd.thumbnailURL = frame.thumbnail.absoluteString
                frameToAdd.fullSizeURL = frame.fullSize.absoluteString
                frameToAdd.uniqueID = frame.photoID
                pin.addToAlbumFrames(frameToAdd)}
            print("There are \(photoFrameList.count) Frames that need to be saved")
            //Once everything is added, attempt the save and return the completion closure.
            do{try Traveler.shared.backgroundContext.save()}
            catch{completion(DatabaseError.general(dbDescription: error.localizedDescription)); return}
            completion(nil)
            }
            }
        }
    }
    
    //Method for deleting Photos that have escaped the cascading delete rule on PhotoFrame
    static func requestDeleteNullPhotos(){
        Traveler.shared.backgroundContext.perform {
            let requestPhotosToDelete: NSFetchRequest<Photo> = Photo.fetchRequest()
            //Search for all Photos that are dangling in Disk Space
            let searchCriteria = NSPredicate(format: "myFrame = NULL")
            requestPhotosToDelete.predicate = searchCriteria
            //Create an array for those dangling photos
            var photosToDelete: [Photo]?
            do{photosToDelete = try Traveler.shared.backgroundContext.fetch(requestPhotosToDelete)}
            catch{print("Error in retrieving NULL photos in DataBase");return}
            guard let foundNullPhotos = photosToDelete else{print("Found No Null Photos");return}
            print("Found \(foundNullPhotos.count) null photos!")
            //Send a call to delete all of those photos in the context
            for photoToDelete in foundNullPhotos{Traveler.shared.backgroundContext.delete(photoToDelete)}
            //Save the deletion or simply ignore
            try? Traveler.shared.backgroundContext.save()
        }
    }
    
    //Note: Only use this method on a queue provided by Traveler.shared.backGroundContext.
    static func requestRemainingFramesFor(_ pin: Pin, completion: @escaping (_ newLocations: [Int]?, _ error: LocalizedError?)->Void){
        Traveler.shared.backgroundContext.performAndWait {
            //Set up the longitude and latitude and start the network call for the Frames
            let lat = String(pin.latitude); let lon = String(pin.longitude)
            //Retrieve the PhotoFrames already associated with the pin.
            guard let currentFrames = pin.albumFrames?.allObjects as? [PhotoFrame]
                else{ completion(nil, DatabaseError.objectReturnedNil(object: "Frames"));return}
            let existingFrameCount = currentFrames.count
            //Calculate the amount of photo's needed
            let amountToRetrieve = FlickrCnst.Prefered.PhotosPerPage - existingFrameCount
            //Build up a exclusion list that contains the existing frames' unique IDs.
            var exclusionList = [String]()
            for frame in currentFrames{ guard let frameID = frame.uniqueID
                else{completion(nil, DatabaseError.objectReturnedNil(object: "Frame's Unique ID"));return}
                exclusionList.append(frameID)}
            //Start the network call for the remaining frames
            FlickrClient.photosForLocation(
            withQuota: amountToRetrieve, IDExclusionList: exclusionList, latitude: lat, longitude: lon){ photoFrameList, networkError in
                Traveler.shared.backgroundContext.performAndWait {
                    guard networkError == nil else{completion(nil, networkError);return}
                    //If there are no photos produced in the search then return the no results error.
                    guard let photoFrameList = photoFrameList, photoFrameList.count != 0 else{
                        completion(nil, GeneralError.PhotoSearchYieldedNoResults)
                        return}
                    var newAlbumLocations = [Int]()
                    //Start adding the PhotoFrames to the Pin
                    for (position, frame) in photoFrameList.enumerated(){
                        let frameToAdd = PhotoFrame(context: Traveler.shared.backgroundContext)
                        let destinedAlbumLocation = position + existingFrameCount
                        print("Insterting New Frame at albumLocation #\(destinedAlbumLocation)")
                        newAlbumLocations.append(destinedAlbumLocation)
                        frameToAdd.albumLocation = Int16(destinedAlbumLocation)
                        frameToAdd.thumbnailURL = frame.thumbnail.absoluteString
                        frameToAdd.fullSizeURL = frame.fullSize.absoluteString
                        frameToAdd.uniqueID = frame.photoID
                        pin.addToAlbumFrames(frameToAdd)}
                    print("There are \(photoFrameList.count) Frames that need to be saved")
                    //Once everything is added, attempt the save and return the completion closure.
                    do{try Traveler.shared.backgroundContext.save()}
                    catch{completion(nil, DatabaseError.general(dbDescription: error.localizedDescription)); return}
                    completion(newAlbumLocations, nil)
                }
            }
        }
    }
    
}
