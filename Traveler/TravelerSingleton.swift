//
//  TravelerSingleton.swift
//  Traveler
//
//  Created by Stephen Martinez on 5/12/17.
//  Copyright © 2017 Stephen Martinez. All rights reserved.
//

import UIKit
import CoreData


class Traveler{
    
    //Singleton for App!

    private init(){}
    static let shared = Traveler()
    let session = URLSession.shared
    //For DB Main Queue Use
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    //For getting background queue DB tasks
    let container = (UIApplication.shared.delegate as! AppDelegate).persistentContainer
    
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
        //Search criteia should bring the one meme that has the Unique ID
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
