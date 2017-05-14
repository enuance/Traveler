//
//  ErrorHandling.swift
//  Traveler
//
//  Created by Stephen Martinez on 5/12/17.
//  Copyright © 2017 Stephen Martinez. All rights reserved.
//

import UIKit

enum NetworkError: LocalizedError{
    case general
    case invalidLogIn
    case JSONToData
    case DataToJSON
    case emptyObject(domain: String)
    case nonOKHTTP(status: Int)
    case noDataReturned(domain: String)
    case invalidAPIPath(domain: String)
    case invalidPostingData(domain: String, data: String)
    case invalidPutData(domain: String, data: String)
    case invalidDeleteData(domain: String, data: String)
    
    var localizedDescription: String{
        switch self{
        case .general:
            return "The task could not be completed due to a Network Request Error"
        case .invalidLogIn:
            return "Invalid Password/Username Combination"
        case .JSONToData:
            return "Error with converting Swift Object to JSON Object (DATA), check values!"
        case .DataToJSON:
            return "Error with converting JSON Object (DATA) to Swift Object, check values!"
        case .emptyObject(domain: let method):
            return "An empty object/No content was returned by \(method)"
        case .nonOKHTTP(status: let statusNumber):
            return "A Non 2XX (OK) HTTP Status code of \(statusNumber) was given"
        case .noDataReturned(domain: let method):
            return "No data was returned from \(method)"
        case .invalidAPIPath(domain: let method):
            return "The API Structure Does not match the expected path traversed in \(method)"
        case .invalidPostingData(domain: let method, data: let description):
            return "The invalid data: \(description) was rejected from \(method)"
        case .invalidPutData(domain: let method, data: let description):
            return "The invalid data: \(description) was rejected from \(method)"
        case .invalidDeleteData(domain: let method, data: let description):
            return "The invalid data: \(description) was rejected from \(method)"
        }
    }
}

enum DatabaseError: LocalizedError{
    case general
    
    var localizedDescription: String{
        switch self{
        case .general:
            return "The task could not be completed due to a DataBase Error"
        }
    }
}

enum GeneralError: String{
    case UIConnection = "User Interface ConnectionError"
    case invalidURL = "Invalid URL"
    
    var description: String{
        switch self{
        case .UIConnection:
            return "This Interface did not get connected properly and is unable to complete the assigned task."
        case .invalidURL:
            return "You have attempted to open an invalid URL"
        }
    }
}


//Allows a way to propogate Error Messages to the User throughout the app

class SendToDisplay{
    class func error(_ displayer: UIViewController, errorType: String, errorMessage: String, assignment: (() -> Void)?) {
        let errorColor = TravelerCnst.color.gold
        let errorTypeString = NSAttributedString(string: errorType, attributes: [
            NSFontAttributeName : UIFont(name: "Futura-Medium", size: CGFloat(24))!,
            NSForegroundColorAttributeName : TravelerCnst.color.teal])
        let messageString = NSAttributedString(string: errorMessage, attributes: [
            NSFontAttributeName : UIFont(name: "AvenirNextCondensed-Regular", size: CGFloat(20))!,
            NSForegroundColorAttributeName : TravelerCnst.color.teal])
        let errorAlert = UIAlertController(title: errorType, message: errorMessage, preferredStyle: .alert)
        errorAlert.setValue(errorTypeString, forKey: "attributedTitle")
        errorAlert.setValue(messageString, forKey: "attributedMessage")
        let dismissError = UIAlertAction(title: "Dismiss", style: .default) { action in
            errorAlert.dismiss(animated: true)
            if let assignment = assignment{assignment()}}
        errorAlert.addAction(dismissError)
        let subview = errorAlert.view.subviews.first! as UIView
        let alertContentView = subview.subviews.first! as UIView
        alertContentView.layer.cornerRadius = 10
        alertContentView.layer.borderWidth = CGFloat(0.6)
        alertContentView.layer.borderColor = errorColor.cgColor
        errorAlert.view.tintColor = errorColor
        displayer.present(errorAlert, animated: true, completion: nil)
    }
    
    //Allows a way to propogate Questions to the User and retrieve their Answers throughout the app. Something to keep in mind is that
    //the assignements parameter accepts a dictionary and so the responses/Answers to the user is displayed in a random order each time the method
    //is called.
    class func question(_ displayer: UIViewController, QTitle: String, QMessage: String, assignments Answers: [String : () -> (Void)]){
        let QAColor = TravelerCnst.color.gold
        let QTitleString = NSAttributedString(string: QTitle, attributes: [
            NSFontAttributeName : UIFont(name: "Futura-Medium", size: CGFloat(24))!,
            NSForegroundColorAttributeName : TravelerCnst.color.teal])
        let messageString = NSAttributedString(string: QMessage, attributes: [
            NSFontAttributeName : UIFont(name: "AvenirNextCondensed-Regular", size: CGFloat(20))!,
            NSForegroundColorAttributeName : TravelerCnst.color.teal])
        let questionAlert = UIAlertController(title: QTitle, message: QMessage, preferredStyle: .alert)
        questionAlert.setValue(QTitleString, forKey: "attributedTitle")
        questionAlert.setValue(messageString, forKey: "attributedMessage")
        for (key, value) in Answers{
            let answerToQuestion = UIAlertAction(title: key, style: .default) { action in
                questionAlert.dismiss(animated: true);value()}
            questionAlert.addAction(answerToQuestion)
        }
        let subview = questionAlert.view.subviews.first! as UIView
        let alertContentView = subview.subviews.first! as UIView
        alertContentView.layer.cornerRadius = 10
        alertContentView.layer.borderWidth = CGFloat(0.6)
        alertContentView.layer.borderColor = QAColor.cgColor
        questionAlert.view.tintColor = QAColor
        displayer.present(questionAlert, animated: true, completion: nil)
    }
}

