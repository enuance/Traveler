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
    let backgroundContext =
        (UIApplication.shared.delegate as! AppDelegate).persistentContainer.newBackgroundContext()
    
    
    
    //For Appwide updates on DataBaseStatus
    var dbStatus: DatabaseStatus = .Starting{
        didSet{print("DB status has been changed from \(oldValue) to \(dbStatus)")}
    }
    
    static func shouldShowIntroMessageIn(_ viewController: UIViewController){

        if UserDefaults.standard.bool(forKey: "isFirstAppLaunch"){
        SendToDisplay.error(viewController,
                            errorType: "Go Travel!",
                            errorMessage: "To travel the World, add pins to the map by holding your finger on the location you would like to see. Select the pin to view that location's photo album.",
                            assignment: {UserDefaults.standard.set(false, forKey: "isFirstAppLaunch")}
            )
        }
    }
    
}
