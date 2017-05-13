//
//  Constants.swift
//  Traveler
//
//  Created by Stephen Martinez on 5/11/17.
//  Copyright © 2017 Stephen Martinez. All rights reserved.
//

import Foundation

struct FlickrCnst {
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
        static let OKStatus = "ok"
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
    
    static func URLwith(_ parameters: [String: AnyObject]) -> URL {
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
            FlickrCnst.ParameterKeys.Extras : FlickrCnst.ParameterValues.ExtrasList
        ]
        if let pageNumber = withPage{methodParameters[FlickrCnst.ParameterKeys.Page] = pageNumber}
        return methodParameters
    }
    
    private init (){}
}

struct GlobalCnst {
    
    static func pageNoRand(_ pages: Int) -> Int{
        let firstTry = pages == 0 ? 0 : Int(arc4random_uniform(UInt32(pages))) + 1
        let Second = pages == 0 ? 0 : Int(arc4random_uniform(UInt32(pages))) + 1
        return min(firstTry, Second)
    }
    
    static func indexListRand(_ countOfList: Int, _ maxResults: Int) -> [Int]{
        guard (countOfList != 0), (maxResults != 0) else{return [Int]()}
        let variableMaxResult = min(maxResults, countOfList)
        var indexList = [Int]()
        for _ in 1...variableMaxResult{
            var indexToEnter = Int(arc4random_uniform(UInt32(countOfList)))
            while indexList.contains(indexToEnter){
                indexToEnter = Int(arc4random_uniform(UInt32(countOfList)))
            }
            indexList.append(indexToEnter)
        }
        return indexList
    }
    
}









