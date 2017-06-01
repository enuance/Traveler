//
//  flickrClient.swift
//  Traveler
//
//  Created by Stephen Martinez on 5/11/17.
//  Copyright © 2017 Stephen Martinez. All rights reserved.
//

import Foundation

class flickrClient{
    
    //Test this
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
    
    //Test this
    private func photosForLocation(
        latitude: String,
        longitude: String,
        completion: @escaping(_ photoList: [(thumbnail: URL, fullSize: URL, photoID: String)]?, _ error: NetworkError? )-> Void){
        
        infoForPhotosAtLocation(latitude: latitude, longitude: longitude){ totalPhotos, totalPages, error in
            guard (error == nil) else{return completion(nil, error)}
            guard let photosReturned = totalPhotos, photosReturned != 0 else{return completion( [(URL, URL, String)](),nil)}
            guard let pagesReturned = totalPages, pagesReturned != 0 else{return completion( [(URL, URL, String)](),nil)}
            
            let photoInfo = TravelerCnst.randomPhotoSelections(
                photos: photosReturned,
                pages: pagesReturned,
                perPage: FlickrCnst.Prefered.PhotosPerPage)
            
            let pageNumber = String(photoInfo.pageNum)
            let photoIndexList = photoInfo.listIndex
            let domain = "photosForLocation(:_)"
            let parameters = FlickrCnst.methodParametersWith(latitude, longitude, pageNumber)
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
                //Validate the expected photo dictionary as a dictionary
                guard let photoDictionary = resultDictionary[FlickrCnst.ResponseKeys.Photo] as? [[String: Any]]
                    else{return completion(nil, NetworkError.invalidAPIPath(domain: domain))}
                
                var photosToReturn = [(thumbnail: URL, fullSize: URL, photoID: String)]()
                
                for indexer in photoIndexList{
                    let returnedPhoto = photoDictionary[indexer]
                    guard let thumbnail = returnedPhoto[FlickrCnst.ResponseKeys.SquareURL] as? URL,
                        let fullImage = returnedPhoto[FlickrCnst.ResponseKeys.MediumURL] as? URL,
                        let photoID = returnedPhoto[FlickrCnst.ResponseKeys.PhotoID] as? String
                        else{return completion(nil, NetworkError.invalidAPIPath(domain: domain))}
                    photosToReturn.append(thumbnail: thumbnail, fullSize: fullImage, photoID: photoID)
                }
                return completion(photosToReturn, nil)
            }
            task.resume()
        }
    }
    
}
