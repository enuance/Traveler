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
}
