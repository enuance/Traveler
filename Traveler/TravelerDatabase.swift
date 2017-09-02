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
        do{try Traveler.shared.context.save()}
        catch{return DatabaseError.general(dbDescription: error.localizedDescription)}
        return nil
    }
    
    //Retrieves Pins from the DataBase
    static func retrievePinsFromDataBase()-> (pins: [PinAnnotation]?, error: DatabaseError?){
        let requestForPins: NSFetchRequest<Pin> = Pin.fetchRequest()
        do{let returnedPins = try Traveler.shared.context.fetch(requestForPins)
            var returnedAnnotations = [PinAnnotation]()
            for pin in returnedPins{
                let possiblePin = TravelerCnst.convertToPinAnnotation(with: pin)
                guard let verifiedPin = possiblePin.pinAnnotation else{return (nil, DatabaseError.inconvertableObject(object: "PinAnnotation"))}
                returnedAnnotations.append(verifiedPin)
            }
            print("\(returnedAnnotations.count) Pins returned from the DataBase")
            return (returnedAnnotations, nil)
        }
        catch{return (nil, DatabaseError.general(dbDescription: error.localizedDescription))}
    }
    
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
        
        print("No Photo was found. Continue to Save photo from web")
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
    
    
    
    static func retrievePhotoFromDataBase(photoID: String)-> (photo: TravelerPhoto?, error: DatabaseError?){
        //Set up a search and the criteria for the photo in question
        let checkForPhoto: NSFetchRequest<Photo> = Photo.fetchRequest()
        let photoSearchCriteria = NSPredicate(format: "uniqueID = %@", photoID)
        checkForPhoto.predicate = photoSearchCriteria
        
        //Conduct the search for the photo
        var photoFound: Photo! = nil
        do{photoFound = try Traveler.shared.context.fetch(checkForPhoto).first}
        catch{return (nil,DatabaseError.general(dbDescription: error.localizedDescription))}
        
        //If a photo was found, convert to an image and pass it along.
        if let photoFound = photoFound, let thumbnail = photoFound.thumbnail, let fullsize = photoFound.fullSize, let foundID = photoFound.uniqueID{
            print("Photo ID:\(foundID) was found!")
            let photoForUse = TravelerPhoto(thumbnail: thumbnail, fullsize: fullsize, photoID: foundID)
            return (photoForUse, nil)
        }
        //Otherwise exit out of the method with no photos from the data base
        return (nil, nil)
    }
    
    
    
    
    
    
    
    
    
    
    
    
}
