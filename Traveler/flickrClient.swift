//
//  flickrClient.swift
//  Traveler
//
//  Created by Stephen Martinez on 5/11/17.
//  Copyright © 2017 Stephen Martinez. All rights reserved.
//

import UIKit

class flickrClient{
    
    static func infoForPhotosAtLocation(
        latitude: String,
        longitude: String,
        completion: @escaping(_ totalPhotos: Int?, _ totalPages: Int?, _ error: NetworkError? )-> Void){
        
        let domain = "infoForPhotosAtLocation(:_)"
        let parameters = FlickrCnst.methodParametersWith(latitude, longitude)
        let request = URLRequest(url: FlickrCnst.URLwith(parameters))
        
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
            guard let resultsObject = results.swiftObject as? [String : Any] else {return completion(nil, nil, results.error)}
            //Validate the expected object to be recieved as a dictionary
            guard let resultDictionary = resultsObject[FlickrCnst.ResponseKeys.Photos] as? [String: Any]
                else{return completion(nil, nil, NetworkError.invalidAPIPath(domain: domain))}
            //Validate that "total" and "pages" in the dictionary can be casted as an integer.
            //The "total" photos comes back as a string when deserialized from JSON! Need to further convert it into an Int.
            guard let numberOfPhotos = resultDictionary[FlickrCnst.ResponseKeys.Total] as? String, let numOfPhotos = Int(numberOfPhotos),
                let numOfPages = resultDictionary[FlickrCnst.ResponseKeys.Pages] as? Int else{
                    return completion(nil, nil, NetworkError.invalidAPIPath(domain: domain))
            }
            return completion(numOfPhotos, numOfPages, nil)
        }
        task.resume()
    }
    
    static func photosForLocation(
        latitude: String,
        longitude: String,
        completion: @escaping(_ photoList: [(thumbnail: URL, fullSize: URL, photoID: String)]?, _ error: NetworkError? )-> Void){
        
        infoForPhotosAtLocation(latitude: latitude, longitude: longitude){ totalPhotos, totalPages, error in
            guard (error == nil) else{ return completion(nil, error)}
            
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
                guard let resultsObject = results.swiftObject as? [String : Any] else {return completion(nil, results.error)}
                //Validate the expected object to be recieved as a dictionary
                guard let resultDictionary = resultsObject[FlickrCnst.ResponseKeys.Photos] as? [String: Any]
                    else{return completion(nil, NetworkError.invalidAPIPath(domain: domain))}
                //Validate the expected photo dictionary as a dictionary
                guard let photoDictionary = resultDictionary[FlickrCnst.ResponseKeys.Photo] as? [[String: Any]]
                    else{return completion(nil, NetworkError.invalidAPIPath(domain: domain))}
                
                var photosToReturn = [(thumbnail: URL, fullSize: URL, photoID: String)]()
                
                for indexer in photoIndexList{
                    let returnedPhoto = photoDictionary[indexer]
                    guard let thumbnailString = returnedPhoto[FlickrCnst.ResponseKeys.SquareURL] as? String,
                        let thumbnail = URL(string: thumbnailString),
                        let fullImageString = returnedPhoto[FlickrCnst.ResponseKeys.MediumURL] as? String,
                        let fullImage = URL(string: fullImageString),
                        let photoID = returnedPhoto[FlickrCnst.ResponseKeys.PhotoID] as? String
                        else{ print("Photo excluded during the loop is \(photoDictionary[indexer])"); continue}
                    photosToReturn.append(thumbnail: thumbnail, fullSize: fullImage, photoID: photoID)
                }
                return completion(photosToReturn, nil)
            }
            task.resume()
        }
    }
    
    static func photosForLocation(
        withQuota: Int,
        IDExclusionList: [String],
        latitude: String,
        longitude: String,
        completion: @escaping(_ photoList: [(thumbnail: URL, fullSize: URL, photoID: String)]?, _ error: NetworkError? )-> Void){
        
        guard (withQuota <= FlickrCnst.Prefered.PhotosPerPage) else{return completion(nil, NetworkError.general) }
        guard (withQuota > 0) else{return completion( [(URL, URL, String)](),nil)}
        
        infoForPhotosAtLocation(latitude: latitude, longitude: longitude){ totalPhotos, totalPages, error in
            guard (error == nil) else{ return completion(nil, error)}
            guard let photosReturned = totalPhotos, photosReturned != 0 else{return completion( [(URL, URL, String)](),nil)}
            guard let pagesReturned = totalPages, pagesReturned != 0 else{return completion( [(URL, URL, String)](),nil)}
            
            let photoInfo = TravelerCnst.randomPhotoSelections(
                photos: photosReturned,
                pages: pagesReturned,
                perPage: FlickrCnst.Prefered.PhotosPerPage)
            
            let pageNumber = String(photoInfo.pageNum)
            let photoIndexList = photoInfo.listIndex
            let domain = "photosForLocation(withQuota:_, IDExclusionList:_)"
            let parameters = FlickrCnst.methodParametersWith(latitude, longitude, pageNumber)
            let request = URLRequest(url: FlickrCnst.URLwith(parameters))
            
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
                guard let resultsObject = results.swiftObject as? [String : Any] else {return completion(nil, results.error)}
                //Validate the expected object to be recieved as a dictionary
                guard let resultDictionary = resultsObject[FlickrCnst.ResponseKeys.Photos] as? [String: Any]
                    else{return completion(nil, NetworkError.invalidAPIPath(domain: domain))}
                //Validate the expected photo dictionary as a dictionary
                guard let photoDictionary = resultDictionary[FlickrCnst.ResponseKeys.Photo] as? [[String: Any]]
                    else{return completion(nil, NetworkError.invalidAPIPath(domain: domain))}
                
                var photosToReturn = [(thumbnail: URL, fullSize: URL, photoID: String)]()
                var countToMeetQuota = 0
                
                for indexer in photoIndexList{
                    let returnedPhoto = photoDictionary[indexer]
                    guard let thumbnailString = returnedPhoto[FlickrCnst.ResponseKeys.SquareURL] as? String,
                        let thumbnail = URL(string: thumbnailString),
                        let fullImageString = returnedPhoto[FlickrCnst.ResponseKeys.MediumURL] as? String,
                        let fullImage = URL(string: fullImageString),
                        let photoID = returnedPhoto[FlickrCnst.ResponseKeys.PhotoID] as? String,
                        !IDExclusionList.contains(photoID)
                        else{ print("Photo excluded during the loop is \(photoDictionary[indexer])"); continue}
                    photosToReturn.append(thumbnail: thumbnail, fullSize: fullImage, photoID: photoID)
                    countToMeetQuota += 1; if countToMeetQuota == withQuota{break}
                }
                return completion(photosToReturn, nil)
            }
            task.resume()
        }
    }

    static func getPhotoFor(url: URL, completion: @escaping(_ image: UIImage?, _ error: NetworkError?) -> Void  ){
        let domain = "getPhotoFor(:_)"
        let task = Traveler.shared.session.dataTask(with: url){ data, response, error in
            guard (error == nil) else{return completion(nil, NetworkError.general)}
            //Allow only OK status to continue
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299
                else{ return completion(nil, NetworkError.nonOKHTTP(status: (response as! HTTPURLResponse).statusCode))}
            //Exit method if no data is present.
            guard let data = data else{return completion(nil, NetworkError.noDataReturned(domain: domain))}
            //Convert the data into Swift's AnyObject Type
            let results = UIImage(data: data)
            //Exit the method if the conversion returns a conversion error
            guard let photo = results else {return completion(nil, NetworkError.general)}
            return completion(photo, nil)
        }
        task.resume()
    }
    
    
}
