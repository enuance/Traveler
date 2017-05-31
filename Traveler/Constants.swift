//
//  Constants.swift
//  Traveler
//
//  Created by Stephen Martinez on 5/11/17.
//  Copyright © 2017 Stephen Martinez. All rights reserved.
//

import UIKit
import MapKit

struct FlickrCnst {
    struct Prefered {
        static let PhotosPerPage = 15
        private init(){}
    }
    
    struct API {
        static let Scheme = "https"
        static let Host = "api.flickr.com"
        static let Path = "/services/rest"
        private init (){}
    }
    
    struct ParameterKeys {
        static let Method = "method"
        static let APIKey = "api_key"
        static let Extras = "extras"
        static let Format = "format"
        static let NoJSONCallback = "nojsoncallback"
        static let SafeSearch = "safe_search"
        static let Page = "page"
        static let PerPage = "per_page"
        static let Radius = "radius"
        static let UnitOfMeasure = "radius_units"
        static let ContentType = "content_type"
        static let Latitude = "lat"
        static let Longitude = "lon"
        private init (){}
    }
    
    struct ParameterValues {
        static let SearchMethod = "flickr.photos.search"
        static let APIKey = "9215bde1ab1104b17d0008d70ddf92c4"
        static let ResponseFormat = "json"
        static let DisableJSONCallback = JSONCallback.Yes
        static let MediumURL = "url_z"
        static let SquareURL = "url_q"
        static let ExtrasList = extrasList(ParameterValues.MediumURL, ParameterValues.SquareURL)
        static let UseSafeSearch = SafeSearch.Safe
        static let Radius = "10"
        static let Miles = "mi"
        static let PhotosOnly = "1"
        static let PhotosPerPage = "\(Prefered.PhotosPerPage)"
        static func extrasList(_ extras: String...)-> String{return extras.joined(separator: ",")}
        private init (){}
    }
    
    struct ResponseKeys {
        static let Status = "stat"
        static let Photos = "photos"
        static let Photo = "photo"
        static let Title = "title"
        static let MediumURL = "url_z"
        static let SquareURL = "url_q"
        static let Pages = "pages"
        static let Total = "total"
        private init (){}
    }
    
    struct ResponseValues {
        static let statusOK = "ok"
        static let statusFail = "fail"
        private init (){}
    }
    
    struct JSONCallback {
        static let No = "0"
        static let Yes = "1"
        private init (){}
    }
    
    struct SafeSearch {
        static let Safe = "1"
        static let Moderate = "2"
        static let Restricted = "3"
        private init (){}
    }
    
    static func URLwith(_ parameters: [String: Any]) -> URL {
        var components = URLComponents()
        components.scheme = FlickrCnst.API.Scheme
        components.host = FlickrCnst.API.Host
        components.path = FlickrCnst.API.Path
        components.queryItems = [URLQueryItem]()
        for (key, value) in parameters {
            let queryItem = URLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        return components.url!
    }
    
    static func methodParametersWith(_ lat: String, _ lon: String, _ withPage: String? = nil ) -> [String : Any] {
        var methodParameters: [String: Any] = [
            FlickrCnst.ParameterKeys.Method : FlickrCnst.ParameterValues.SearchMethod,
            FlickrCnst.ParameterKeys.APIKey : FlickrCnst.ParameterValues.APIKey,
            FlickrCnst.ParameterKeys.Format : FlickrCnst.ParameterValues.ResponseFormat,
            FlickrCnst.ParameterKeys.NoJSONCallback : FlickrCnst.ParameterValues.DisableJSONCallback,
            FlickrCnst.ParameterKeys.Latitude : lat,
            FlickrCnst.ParameterKeys.Longitude : lon,
            FlickrCnst.ParameterKeys.Radius : FlickrCnst.ParameterValues.Radius,
            FlickrCnst.ParameterKeys.UnitOfMeasure : FlickrCnst.ParameterValues.Miles,
            FlickrCnst.ParameterKeys.ContentType : FlickrCnst.ParameterValues.PhotosOnly,
            FlickrCnst.ParameterKeys.SafeSearch : FlickrCnst.ParameterValues.UseSafeSearch,
            FlickrCnst.ParameterKeys.PerPage : FlickrCnst.ParameterValues.PhotosPerPage,
            FlickrCnst.ParameterKeys.Extras : FlickrCnst.ParameterValues.ExtrasList
        ]
        if let pageNumber = withPage{methodParameters[FlickrCnst.ParameterKeys.Page] = pageNumber}
        return methodParameters
    }
    
    private init (){}
}

struct TravelerCnst {
    //Use this method to create a random page number
    static func pageNoRand(_ pages: Int) -> Int{
        let firstTry = pages == 0 ? 0 : Int(arc4random_uniform(UInt32(pages))) + 1
        let Second = pages == 0 ? 0 : Int(arc4random_uniform(UInt32(pages))) + 1
        return min(firstTry, Second)
    }
    
    //Use this method to create a list of random indexing integers
    static func indexListRand(_ countOfList: Int) -> [Int]{
        guard (countOfList != 0) else{return [Int]()}
        var indexList = [Int](); var remainingList = Array(0..<countOfList)
        var indexer: Int{get{return Int(arc4random_uniform(UInt32(remainingList.count)))}}
        for _ in 1...countOfList{
            let index = indexer
            let indexToEnter = remainingList[index]
            remainingList.remove(at: index)
            indexList.append(indexToEnter)
        }
        return indexList
    }
    
    //Use This Method when sending Data to a server
    static func convertToJSON(with object: AnyObject) -> (JSONObject: Data?, error: NetworkError?){
        var wouldBeJSON: Data? = nil
        do{ wouldBeJSON = try JSONSerialization.data(withJSONObject: object, options: .prettyPrinted)}
        catch{return (wouldBeJSON, NetworkError.JSONToData)}
        return (wouldBeJSON, nil)
    }
    
    //Use this Method when recieving Data from a server
    static func convertToSwift(with JSON: Data) -> (swiftObject: AnyObject?, error: NetworkError?){
        var wouldBeSwift: AnyObject? = nil
        do{ wouldBeSwift = try JSONSerialization.jsonObject(with: JSON, options: .allowFragments) as AnyObject}
        catch{return (wouldBeSwift, NetworkError.DataToJSON)}
        return (wouldBeSwift, nil)
    }
    
    static func convertToPinAnnotation(with DBPin: Pin) -> (pinAnnotation: PinAnnotation?, error: DatabaseError?){
        let coordinates = CLLocationCoordinate2DMake(DBPin.latitude, DBPin.longitude)
        guard let uniqueIdentifier = DBPin.uniqueID else{return (nil, DatabaseError.nonUniqueEntry)}
        return (PinAnnotation(coordinate: coordinates, uniqueIdentifier: uniqueIdentifier), nil)
    }
    
    //Colors for use in accordance with the App's theme.
    static let color = Color()
    struct Color{
        var teal: UIColor{get{return UIColor(red: decimal(50), green: decimal(110), blue: decimal(117), alpha: 1)}}
        var transparentTeal: UIColor{get{return UIColor(red: decimal(50), green: decimal(110), blue: decimal(117), alpha: 0.4)}}
        var lightTeal: UIColor{get{return UIColor(red: decimal(80), green: decimal(176), blue: decimal(187), alpha: 1)}}
        var gold: UIColor{get{return UIColor(red: decimal(176), green: decimal(142), blue: decimal(101), alpha: 1)}}
        var transparentGold: UIColor{get{return UIColor(red: decimal(176), green: decimal(142), blue: decimal(101), alpha: 0.4)}}
        var brownGold: UIColor{get{return UIColor(red: decimal(75), green: decimal(66), blue: decimal(56), alpha: 1)}}
        var white: UIColor{get{return UIColor(red: decimal(255), green: decimal(255), blue: decimal(255), alpha: 1)}}
        var mutedWhite: UIColor{get{return UIColor(red: decimal(185), green: decimal(185), blue: decimal(185), alpha: 1)}}
        var lightGray: UIColor{get{return UIColor(red: decimal(39), green: decimal(47), blue: decimal(51), alpha: 0.8)}}
        var gray: UIColor{get{return UIColor.darkGray}}
        private func decimal(_ rgbValue: Int) -> CGFloat{return CGFloat(rgbValue)/CGFloat(255)}
    }
    
}









