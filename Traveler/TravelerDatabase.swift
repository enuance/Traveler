//
//  TravelerDatabase.swift
//  Traveler
//
//  Created by Stephen Martinez on 9/1/17.
//  Copyright © 2017 Stephen Martinez. All rights reserved.
//

import UIKit
import CoreData

//DataBase Methods for Pins
extension Traveler{
    
    //Adds a pin to the DataBase
    static func addToDatabase(_ pin: PinAnnotation) -> DatabaseError?{
        guard let uniqueID = pin.uniqueIdentifier else{return DatabaseError.nonUniqueEntry}
        let pinToAdd = Pin(context: Traveler.shared.context)
        pinToAdd.uniqueID = uniqueID
        pinToAdd.latitude = pin.coordinate.latitude
        pinToAdd.longitude = pin.coordinate.longitude
        do{
            try Traveler.shared.context.save()}
        catch{
            return DatabaseError.general(dbDescription: error.localizedDescription)}
        return nil
    }
    
    
    //Marked For Deletion!!!
    //Retrieves Pins from the DataBase
    static func retrievePinsFromDataBase()-> (pins: [PinAnnotation]?, error: DatabaseError?){
        let requestForPins: NSFetchRequest<Pin> = Pin.fetchRequest()
        do{
            let returnedPins = try Traveler.shared.context.fetch(requestForPins)
            var returnedAnnotations = [PinAnnotation]()
            for pin in returnedPins{
                let possiblePin = TravelerCnst.convertToPinAnnotation(with: pin)
                guard let verifiedPin = possiblePin.pinAnnotation else{return (nil, DatabaseError.inconvertableObject(object: "PinAnnotation"))}
                returnedAnnotations.append(verifiedPin)}
            return (returnedAnnotations, nil)}
        catch{
            return (nil, DatabaseError.general(dbDescription: error.localizedDescription))}
    }
    
    
    
    //Marked For Deletion!!!
    static func deletePinFromDataBase(uniqueID: String) -> DatabaseError?{
        let requestPinToDelete: NSFetchRequest<Pin> = Pin.fetchRequest()
        //Search criteia should bring the one Pin that has the Unique ID
        let searchCriteria = NSPredicate(format: "uniqueID = %@", uniqueID)
        requestPinToDelete.predicate = searchCriteria
        var pinToDelete: Pin! = nil
        do{pinToDelete = try Traveler.shared.context.fetch(requestPinToDelete).first}
        catch{return DatabaseError.general(dbDescription: error.localizedDescription)}
        
        if let aPinToDelete = pinToDelete{
            Traveler.shared.context.delete(aPinToDelete)
            print("A Pin with ID \(uniqueID) has been deleted")
            //Once it's deleted we need to save the context!
            do{try Traveler.shared.context.save()}
            catch{return DatabaseError.general(dbDescription: error.localizedDescription)}
        }
        return nil
    }
    
    
}







//DataBase Methods For Photos
extension Traveler{
    
    
    //Adds a photo to the DataBase using ----- the main or a concurrent queue --------
    static func checkAndSave(_ photo: TravelerPhoto, pinID uniqueID: String, concurrent: Bool) -> DatabaseError?{
        //Assign the chosen context for the DataBase Tasks
        let assignedContext = concurrent ? Traveler.shared.backgroundContext : Traveler.shared.context
        
        //Set up a search and the criteria for the photo in question
        let checkForPhoto: NSFetchRequest<Photo> = Photo.fetchRequest()
        let photoSearchCriteria = NSPredicate(format: "uniqueID = %@", photo.photoID)
        checkForPhoto.predicate = photoSearchCriteria
        
        //Conduct the search for the photo
        var photoFound: Photo! = nil
        
        do{ photoFound  = try assignedContext.fetch(checkForPhoto).first}
        catch{return DatabaseError.general(dbDescription: error.localizedDescription)}
        
        //Exit out of method if a photo already exists in DB
        if photoFound != nil {print("Photo ID:\(photo.photoID) was found!");return nil}
        
        print("Photo: \(photo.photoID) not in DataBase. Uploading into DB...")
        //Otherwise, set up search for the associated Pin to add the photo to
        let requestPinToSavePhoto: NSFetchRequest<Pin> = Pin.fetchRequest()
        let searchCriteria = NSPredicate(format: "uniqueID = %@", uniqueID)
        requestPinToSavePhoto.predicate = searchCriteria
        
        //Conduct the search for the Pin
        var pinToSavePhoto: Pin! = nil
        
        do{ pinToSavePhoto = try assignedContext.fetch(requestPinToSavePhoto).first}
        catch{return DatabaseError.general(dbDescription: error.localizedDescription)}
        
        //Once Pin is located, create a DataBase Photo Entity to add to the located Pin
        if let aPinToSavePhoto = pinToSavePhoto, let fullsizeData = photo.fullsizeData, let thumbnailData = photo.thumbnailData {
            let photoToAdd = Photo(context: assignedContext)
            photoToAdd.thumbnail = thumbnailData
            photoToAdd.fullSize = fullsizeData
            photoToAdd.uniqueID = photo.photoID
            
            //Add the Data Photo to the assocaited Pin
            aPinToSavePhoto.addToAlbumPhotos(photoToAdd)
            
            //Save the DataBase Changes and exit the method.
            do{try assignedContext.save()}
            catch{return DatabaseError.general(dbDescription: error.localizedDescription)}
        }
        return nil
    }
    
    
    
    
    //Operates in the Background Context. Brings back a specified list of photos from the database.
    static func ExperimentalPhotoRetrieve(_ pinID: String, _ photoIDS: [String], _ completionHandler: @escaping (_ photos: [TravelerPhoto]?, _ status: DatabaseStatus, _ error: DatabaseError?) -> Void){
        //Assign the chosen context for the DataBase Tasks
        let assignedContext = Traveler.shared.backgroundContext
        //Set up a search and the criteria for the photo in question
        let searchForPin: NSFetchRequest<Pin> = Pin.fetchRequest()
        let pinSearchCriteria = NSPredicate(format: "uniqueID = %@", pinID)
        searchForPin.predicate = pinSearchCriteria
        //Conduct the search for the photo
        var pinFound: Pin! = nil
        do{ pinFound  = try assignedContext.fetch(searchForPin).first}
        catch{completionHandler(nil, DatabaseStatus.TaskFailure, DatabaseError.general(dbDescription: error.localizedDescription));return}
        //Exit out of method if a photo already exists in DB
        
        guard let thePin = pinFound else{
            completionHandler(nil, DatabaseStatus.PinNotFound, DatabaseError.general(dbDescription: "The Pin was not found in the Database"))
            return
        }
        
        guard let allPhotos = thePin.albumPhotos?.allObjects as? [Photo] else{
            completionHandler(nil, DatabaseStatus.PhotoNotFound, DatabaseError.general(dbDescription: "The Photos were not found in the Database"))
            return
        }
        
        var travelerPhotos = [TravelerPhoto]()
        
        for picture in allPhotos{
            guard let  pictureID = picture.uniqueID, let pictureThumbnail = picture.thumbnail, let pictureFullSize = picture.fullSize else{
                completionHandler(nil, DatabaseStatus.PhotoNotFound, DatabaseError.general(dbDescription: "The Photo in the Database did not have an ID"))
                return}
            if photoIDS.contains(pictureID){
                let pictureToAdd = TravelerPhoto(thumbnail: pictureThumbnail, fullsize: pictureFullSize, photoID: pictureID)
                travelerPhotos.append(pictureToAdd)
            }
        }
        guard travelerPhotos.count == photoIDS.count else{
            completionHandler(nil, DatabaseStatus.PhotoNotFound, DatabaseError.general(dbDescription: "Some of the photos in the list were not found"))
            return
        }
        completionHandler(travelerPhotos, DatabaseStatus.SuccessfullRetrieval, nil)
    }
    
    
    
    
    
    
    //Adds a photo to the DataBase using ----- the main or a concurrent queue --------
    static func ExperimentBGSave(_ photo: TravelerPhoto, pinID uniqueID: String, _ completionHandler: @escaping (_ status: DatabaseStatus, _ error: DatabaseError? ) ->Void){
        //Assign the chosen context for the DataBase Tasks
        let assignedContext = Traveler.shared.backgroundContext
        //Set up a search and the criteria for the photo in question
        let checkForPhoto: NSFetchRequest<Photo> = Photo.fetchRequest()
        let photoSearchCriteria = NSPredicate(format: "uniqueID = %@", photo.photoID)
        checkForPhoto.predicate = photoSearchCriteria
        //Conduct the search for the photo
        var photoFound: Photo! = nil
        do{ photoFound  = try assignedContext.fetch(checkForPhoto).first}
        catch{
            completionHandler(DatabaseStatus.TaskFailure, DatabaseError.general(dbDescription: error.localizedDescription))
            return
        }
        //Exit out of method if a photo already exists in DB
        if photoFound != nil {
            completionHandler(DatabaseStatus.PhotoAlreadyExists, nil)
            return
        }
        //Otherwise, set up search for the associated Pin to add the photo to
        let requestPinToSavePhoto: NSFetchRequest<Pin> = Pin.fetchRequest()
        let searchCriteria = NSPredicate(format: "uniqueID = %@", uniqueID)
        requestPinToSavePhoto.predicate = searchCriteria
        //Conduct the search for the Pin
        var pinToSavePhoto: Pin! = nil
        do{ pinToSavePhoto = try assignedContext.fetch(requestPinToSavePhoto).first}
        catch{
            completionHandler(DatabaseStatus.TaskFailure, DatabaseError.general(dbDescription: error.localizedDescription))
            return
        }
        //Once Pin is located, create a DataBase Photo Entity to add to the located Pin
        if let aPinToSavePhoto = pinToSavePhoto, let fullsizeData = photo.fullsizeData, let thumbnailData = photo.thumbnailData {
            let photoToAdd = Photo(context: assignedContext)
            photoToAdd.thumbnail = thumbnailData
            photoToAdd.fullSize = fullsizeData
            photoToAdd.uniqueID = photo.photoID
            //Add the Data Photo to the assocaited Pin
            aPinToSavePhoto.addToAlbumPhotos(photoToAdd)
            //Save the DataBase Changes and exit the method.
            do{try assignedContext.save()}
            catch{
                completionHandler(DatabaseStatus.TaskFailure, DatabaseError.general(dbDescription: error.localizedDescription))
                return
            }
            //If we get here it means the save was successful
            completionHandler(DatabaseStatus.SuccessfullSave, nil)
            return // return statement not needed unless more is added
        }else{
            completionHandler(DatabaseStatus.PinNotFound, DatabaseError.associatedValueNotFound)
            return
        }

    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    static func retrievePhotoFromDataBase(photoID: String)-> (photo: TravelerPhoto?, error: DatabaseError?){
        //Set up a search and the criteria for the photo in question
        let checkForPhoto: NSFetchRequest<Photo> = Photo.fetchRequest()
        let photoSearchCriteria = NSPredicate(format: "uniqueID = %@", photoID)
        checkForPhoto.predicate = photoSearchCriteria
        
        //Conduct the search for the photo
        var photoFound: Photo! = nil
        do{
            photoFound = try Traveler.shared.context.fetch(checkForPhoto).first}
        catch{
            return (nil,DatabaseError.general(dbDescription: error.localizedDescription))}
        //If a photo was found, convert to an image and pass it along.
        if let photoFound = photoFound, let thumbnail = photoFound.thumbnail, let fullsize = photoFound.fullSize, let foundID = photoFound.uniqueID{
            print("Photo ID:\(foundID) was found!")
            let photoForUse = TravelerPhoto(thumbnail: thumbnail, fullsize: fullsize, photoID: foundID)
            return (photoForUse, nil)
        }
        //Otherwise exit out of the method with no photos from the data base
        return (nil, nil)
    }
    
    //Retrieve Photos from the data base
    static func retrievePhotosFromDataBase(pinUniqueID: String, concurrent: Bool)-> (photos: [TravelerPhoto]?, error: DatabaseError?){
        let assignedContext = concurrent ? Traveler.shared.backgroundContext : Traveler.shared.context
        
        let requestedPin: NSFetchRequest<Pin> = Pin.fetchRequest()
        //Search criteia should bring the one Pin that has the Unique ID
        let searchCriteria = NSPredicate(format: "uniqueID = %@", pinUniqueID)
        requestedPin.predicate = searchCriteria
        var pinToRetrieve: Pin! = nil
        do{
            pinToRetrieve = try assignedContext.fetch(requestedPin).first}
        catch{
            return (nil , DatabaseError.general(dbDescription: error.localizedDescription))}
        
        var travelerAlbum = [TravelerPhoto]()
        
        if let pinFound = pinToRetrieve,
            let unknownAlbum = pinFound.albumPhotos?.allObjects,
            let photoAlbum = unknownAlbum as? [Photo]{
            for aPhoto in photoAlbum{
                if let smallData = aPhoto.thumbnail, let largeData = aPhoto.fullSize, let photoID = aPhoto.uniqueID{
                    let convertedPhoto = TravelerPhoto(thumbnail: smallData, fullsize: largeData, photoID: photoID)
                    travelerAlbum.append(convertedPhoto)
                }else{shared.dbStatus = .Completed("Failed to download photos from DB")
                    return(nil, DatabaseError.inconvertableObject(object: "Photo from pin location"))
                }
            }
            return (travelerAlbum, nil)
        }
        return (nil, DatabaseError.general(dbDescription: "The Unique ID for the location could not produce a photo album from the DataBase"))
    }
    
    
    static func deleteAllPhotosFor(_ pinUniqueID: String, _ completionHandler: @escaping (_ status: DatabaseStatus, _ error: DatabaseError?) -> Void){
        let requestedLocationToClear: NSFetchRequest<Pin> = Pin.fetchRequest()
        let searchCriteria = NSPredicate(format: "uniqueID = %@", pinUniqueID)
        requestedLocationToClear.predicate = searchCriteria
        
        var locationRetrieved: Pin! = nil
        do{ locationRetrieved = try Traveler.shared.backgroundContext.fetch(requestedLocationToClear).first}
        catch{ completionHandler(.TaskFailure , DatabaseError.general(dbDescription: error.localizedDescription));return}
        
        if let locationToClear = locationRetrieved{
            if locationToClear.hasChanges{
                print("The Album had unsaved changes")
                completionHandler(.UnsavedChanges, nil); return}
            let albumToDelete = locationToClear.albumPhotos
            guard let albumPhotos = albumToDelete else {
                print("The Photo set came back nil")
                completionHandler(.PhotoSetNotFound, nil);return}
            locationToClear.removeFromAlbumPhotos(albumPhotos)
            do{ try Traveler.shared.backgroundContext.save()}
            catch{ completionHandler(.TaskFailure, DatabaseError.general(dbDescription: error.localizedDescription));return}
            
            print("Database successfully deleted album!")
            completionHandler(.SuccessfullDeletion, nil)
        }
        else{
            print("The Location was unable to be found")
            completionHandler(.PinNotFound, nil)}
    }
    
    
    
    
    
    
    
    
    
    
    
    //Done on the background context to avoid conflicts / Images are retrieved on the BG Context
    static func deletePhotoFromDataBase(uniqueID: String) -> (success: Bool, error: DatabaseError?){
        let requestPhotoToDelete: NSFetchRequest<Photo> = Photo.fetchRequest()
        //Search criteia should bring the one Photo that has the Unique ID
        let searchCriteria = NSPredicate(format: "uniqueID = %@", uniqueID)
        requestPhotoToDelete.predicate = searchCriteria
        var photoToDelete: Photo! = nil
        
        do{photoToDelete = try Traveler.shared.backgroundContext.fetch(requestPhotoToDelete).first}
        catch{return (false, DatabaseError.general(dbDescription: error.localizedDescription))}
        
        if let aPhotoToDelete = photoToDelete{
            //Checking for unsaved changes prevents merge conflicts with other threads
            if aPhotoToDelete.hasChanges{return (false, nil)}
            Traveler.shared.backgroundContext.delete(aPhotoToDelete)
            print("A Photo with ID \(uniqueID) has been deleted")
            //Once it's deleted we need to save the context!
            do{try Traveler.shared.backgroundContext.save()}
            catch{return (false, DatabaseError.general(dbDescription: error.localizedDescription))}
            //Reaching this point means we had a sucessful deletion of the photo
            return (true, nil)}
        //Reaching here means that no photo was found and therefore not deleted by this task.
        else{return (false,nil)}
    }
    
    
}

















