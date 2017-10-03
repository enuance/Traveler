//
//  TravelMapViewController.swift
//  Traveler
//
//  Created by Stephen Martinez on 5/13/17.
//  Copyright © 2017 Stephen Martinez. All rights reserved.
//

import UIKit
import MapKit

class TravelMapViewController: UIViewController{

    @IBOutlet weak var entryView: UIView!
    @IBOutlet weak var traveledPlacesView: UIView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var rightMessage: UILabel!
    @IBOutlet weak var leftMessage: UILabel!
    @IBOutlet weak var bottomTray: UIView!
    
    var deleteMode: Bool = false
    var viewFirstLoaded = true
    var selectedPin: PinAnnotation!
    var albumDataForSelectedPin: AlbumData!
    
    override func viewDidLoad() {super.viewDidLoad()
        UIApplication.shared.statusBarStyle = .lightContent
        setupTouchSenitivity()
    }

    override func viewDidAppear(_ animated: Bool) {super.viewDidAppear(animated)
        addDataBasePins(to: mapView)
        showBottomTray()
    }
    
    override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated)
        viewFirstLoaded = false
        mapView.removeAnnotations(mapView.annotations)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {super.prepare(for: segue, sender: sender)
        guard let identifier = segue.identifier else{return}
        if identifier == "ShowAlbumViewController"{
            if let AlbumVC = segue.destination as? AlbumViewController{
                AlbumVC.selectedPin = selectedPin
                AlbumVC.albumData = albumDataForSelectedPin
            }
        }
    }

    @IBAction func editPins(_ sender: UIButton) {switchDeleteMode()}
    
    @IBAction func enterButton(_ sender: UIButton) {
        UIView.transition(
            from: entryView,
            to: traveledPlacesView,
            duration: 0.75,
            options: [.transitionCurlUp, .showHideTransitionViews],
            completion: {transitioned in
                if !self.viewFirstLoaded{
                    self.showBottomTray()
                    self.addDataBasePins(to: self.mapView)}
                Traveler.shouldShowIntroMessageIn(self)}
        )
    }
    
    @IBAction func backToEntry(_ sender: UIButton) {
        viewFirstLoaded = false
        lowerBottomTray(){
            UIView.transition(
                from: self.traveledPlacesView,
                to: self.entryView,
                duration: 0.75,
                options: [.transitionCurlDown, .showHideTransitionViews],
                completion: {transitioned in
                    let allPins = self.mapView.annotations
                    self.mapView.removeAnnotations(allPins)
            })
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseId = "TravelerPin"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
        if pinView == nil {pinView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)}
        else {pinView?.annotation = annotation}
        pinView?.image = UIImage(named:"TravelerPin")
        pinView?.centerOffset.y = -20
        pinView?.centerOffset.x = 4
        return pinView
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let pinAnnotation = view.annotation as? PinAnnotation else{return}
        let uniqueID = pinAnnotation.uniqueIdentifier
        print("pin \(uniqueID) Selected")
        guard pinAnnotation.isSelectable == true else{
            SendToDisplay.error(self,
                                errorType: "Pin not accessible!",
                                errorMessage: DatabaseError.operationInProgress.localizedDescription,
                                assignment: {mapView.deselectAnnotation(pinAnnotation, animated: false)})
            return}
        selectedPin = pinAnnotation
        if deleteMode{ PinData.requestPinDeletion(uniqueID){ error in
            guard error == nil else{
                SendToDisplay.error(self,
                                    errorType: "DataBase Error",
                                    errorMessage: error!.localizedDescription,
                                    assignment: {mapView.deselectAnnotation(pinAnnotation, animated: false)})
                return}
            mapView.removeAnnotation(view.annotation!)
            self.switchDeleteMode()}}
        else{goToLocationAlbum()}
    }
    
    func addDataBasePins(to map: MKMapView){
        PinData.requestAllPins(){ pinList, error in
            guard error == nil else{
                SendToDisplay.error( self,
                                     errorType: "Database Error",
                                     errorMessage: error!.localizedDescription,
                                     assignment: nil)
                return}
            guard let pinList = pinList else{print("No Pins to add to map") ;return}
            map.addAnnotations(pinList)
            print("Added \(pinList.count) Pins to Map")
        }
    }
    
    func addTravelerPin(gestureRecognizer: UIGestureRecognizer){
        guard gestureRecognizer.state == .began else{return}
        let touch = gestureRecognizer.location(in: mapView)
        let selectedPoint = mapView.convert(touch, toCoordinateFrom: mapView)
        let uniqueID = UUID().uuidString
        let annotation = PinAnnotation(coordinate: selectedPoint, uniqueIdentifier: uniqueID)
        annotation.isSelectable = false
        mapView.addAnnotation(annotation)
        PinData.requestPinSave(annotation){error in
            guard error == nil else{ switch error!{
            case let gError as GeneralError:
                SendToDisplay.error(self,
                                    errorType: "No Photos Found",
                                    errorMessage: gError.localizedDescription,
                                    assignment: {self.mapView.removeAnnotation(annotation)})
            case let dbError as DatabaseError:
                SendToDisplay.error(self,
                                    errorType: "Database Error",
                                    errorMessage: dbError.localizedDescription,
                                    assignment: {/*Code if Needed*/})
            case let netError as NetworkError:
                SendToDisplay.error(self,
                                    errorType: "Network Error",
                                    errorMessage: netError.localizedDescription,
                                    assignment: {/*Code if Needed*/})
            default: print("Error is not an expected one in addTravelerPin(:_)")}
                return
            }
            print("Pin successfully Framed and Saved!")
            annotation.isSelectable = true
        }
    }
    
}






extension TravelMapViewController: MKMapViewDelegate{
    
    func setupTouchSenitivity(){
        let touchSenitivity = UILongPressGestureRecognizer(target: self, action: #selector(addTravelerPin))
        touchSenitivity.minimumPressDuration = 0.8
        touchSenitivity.allowableMovement = 2
        mapView.addGestureRecognizer(touchSenitivity)
    }
    
    func switchDeleteMode(){
        switch deleteMode{
        case true: deleteMode = false; animateMessage(show: false)
        case false: deleteMode = true ; animateMessage(show: true)
        }
    }
    
}













