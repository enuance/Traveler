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
    static func addToDatabase(_ pin: PinAnnotation, completion: (_ success: Bool?, _ error: DatabaseError?)->Void){
        guard let uniqueID = pin.uniqueIdentifier else{return completion(false, DatabaseError.nonUniqueEntry)}
        let pinToAdd = Pin(context: Traveler.shared.context)
        pinToAdd.uniqueID = uniqueID
        pinToAdd.latitude = pin.coordinate.latitude
        pinToAdd.longitude = pin.coordinate.longitude
        do{try Traveler.shared.context.save()}
        catch{return completion(false, DatabaseError.general(dbDescription: error.localizedDescription))}
        return completion(true, nil)
    }
}
