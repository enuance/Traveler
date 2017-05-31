//
//  flickrClient.swift
//  Traveler
//
//  Created by Stephen Martinez on 5/11/17.
//  Copyright © 2017 Stephen Martinez. All rights reserved.
//

import Foundation

class flickrClient{
    
    
    //Work on Client!!!!!!
    
    
    private func photosForLocation(
        page: String? = nil,
        latitude: String,
        longitude: String,
        completion: @escaping(_ photoList: [(thumbnail: URL, fullSize: URL, photoID: String)]?, _ error: NetworkError? )-> Void){
        
        let domain = "photosForLocation(:_)"
        let parameters = FlickrCnst.methodParametersWith(latitude, longitude, page)
        let request = URLRequest(url: FlickrCnst.URLwith(parameters))
        print(FlickrCnst.URLwith(parameters))
        
        let task = Traveler.shared.session.dataTask(with: request){ data, response, error in
            guard (error == nil) else{return completion(nil, NetworkError.general)}
            //Allow only OK status to continue
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299
                else{ return completion(nil, NetworkError.nonOKHTTP(status: (response as! HTTPURLResponse).statusCode))}
            //Exit method if no data is present.
            guard let data = data else{return completion(nil, NetworkError.noDataReturned(domain: domain))}
            //Convert the data into Swift's AnyObject Type
            let results = TravelerCnst.convertToSwift(with: data)
            //Exit the method if the conversion returns a conversion error
            guard let resultsObject = results.swiftObject else {return completion(nil, results.error)}
            //Validate the expected object to be recieved as a dictionary
            guard let resultDictionary = resultsObject[FlickrCnst.ResponseKeys.Photos] as? [String: Any]
                else{return completion(nil, NetworkError.invalidAPIPath(domain: domain))}
            //Validate that total and pages in the dictionary can be casted as an integer.
            guard let numOfPhotos = resultDictionary[FlickrCnst.ResponseKeys.Total] as? Int, let numOfPages = resultDictionary[FlickrCnst.ResponseKeys.Pages] as? Int
                else{return completion(nil, NetworkError.invalidAPIPath(domain: domain))}
            
            let perPage = FlickrCnst.Prefered.PhotosPerPage
            
            switch numOfPhotos{
            case 0: return completion([(URL, URL, String)](), nil)
            case let x  where x > perPage :
                
                
                
                break
                
            case let x where x <= perPage: break
                
                
            default: break
            }
            
            //Start parsing here!
            
            
            
            
        }
        task.resume()
    }
    
    
    // Compare Photo ID - Reject the results if photos returned matched the photo IDs in the photo ID exclusion list.
    
    
    
    private func infoForPhotosAtLocation(
        latitude: String,
        longitude: String,
        completion: @escaping(_ totalPhotos: Int?, _ totalPages: Int?, _ error: NetworkError? )-> Void){
        
        let domain = "infoForPhotosAtLocation(:_)"
        let parameters = FlickrCnst.methodParametersWith(latitude, longitude)
        let request = URLRequest(url: FlickrCnst.URLwith(parameters))
        print(FlickrCnst.URLwith(parameters))
        
        let task = Traveler.shared.session.dataTask(with: request){ data, response, error in
            guard (error == nil) else{return completion(nil, nil, NetworkError.general)}
            //Allow only OK status to continue
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299
                else{ return completion(nil, nil, NetworkError.nonOKHTTP(status: (response as! HTTPURLResponse).statusCode))}
            //Exit method if no data is present.
            guard let data = data else{return completion(nil, nil, NetworkError.noDataReturned(domain: domain))}
            //Convert the data into Swift's AnyObject Type
            let results = TravelerCnst.convertToSwift(with: data)
            //Exit the method if the conversion returns a conversion error
            guard let resultsObject = results.swiftObject else {return completion(nil, nil, results.error)}
            //Validate the expected object to be recieved as a dictionary
            guard let resultDictionary = resultsObject[FlickrCnst.ResponseKeys.Photos] as? [String: Any]
                else{return completion(nil, nil, NetworkError.invalidAPIPath(domain: domain))}
            //Validate that total and pages in the dictionary can be casted as an integer.
            guard let numOfPhotos = resultDictionary[FlickrCnst.ResponseKeys.Total] as? Int,
                let numOfPages = resultDictionary[FlickrCnst.ResponseKeys.Pages] as? Int
                else{return completion(nil, nil, NetworkError.invalidAPIPath(domain: domain))}
            return completion(numOfPhotos, numOfPages, nil)
        }
        task.resume()
    }
    
    
    
    
    func randomPhotoSelections(photos: Int, pages: Int, perPage: Int) -> (pageNum: Int, listIndex: [Int]){
     
        
        
        
        return (0, [0])
    }
    
    
    
    
    
}
