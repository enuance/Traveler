//
//  TravelMapViewController.swift
//  Traveler
//
//  Created by Stephen Martinez on 5/13/17.
//  Copyright © 2017 Stephen Martinez. All rights reserved.
//

import UIKit
import MapKit

class TravelMapViewController: UIViewController, MKMapViewDelegate {

    @IBOutlet weak var entryView: UIView!
    @IBOutlet weak var traveledPlacesView: UIView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var rightMessage: UILabel!
    @IBOutlet weak var leftMessage: UILabel!
    @IBOutlet weak var bottomTray: UIView!
    
    var deleteMode: Bool = false
    var selectedPin: PinAnnotation!
    
    override func viewDidLoad() {super.viewDidLoad()
        UIApplication.shared.statusBarStyle = .lightContent
        setupTouchSenitivity()
    }

    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated)}
    
    override func viewDidAppear(_ animated: Bool) {super.viewDidAppear(animated)
        addDataBasePins(to: mapView)
        showBottomTray()
    }

    override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated)
        mapView.removeAnnotations(mapView.annotations)
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
    
    func setupTouchSenitivity(){
        let touchSenitivity = UILongPressGestureRecognizer(target: self, action: #selector(addTravelerPin))
        touchSenitivity.minimumPressDuration = 0.8
        touchSenitivity.allowableMovement = 2
        mapView.addGestureRecognizer(touchSenitivity)
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let pinAnnotation = view.annotation as? PinAnnotation else{return}
        let uniqueID = pinAnnotation.uniqueIdentifier
        print("pin \(uniqueID) Selected")
        guard pinAnnotation.isSelectable == true else{
            SendToDisplay.error(self,
                                errorType: "Pin is not accessible yet",
                                errorMessage: DatabaseError.operationInProgress.localizedDescription,
                                assignment: nil)
            return}
        selectedPin = pinAnnotation
        if deleteMode{ PinData.requestPinDeletion(uniqueID){ error in
            guard error == nil else{
                SendToDisplay.error(self,
                                    errorType: "DataBase Error",
                                    errorMessage: error!.localizedDescription,
                                    assignment: nil)
                return}
            mapView.removeAnnotation(view.annotation!)
            self.switchDeleteMode()}}
        else{goToLocationAlbum()}
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {super.prepare(for: segue, sender: sender)
        guard let identifier = segue.identifier else{return}
        if identifier == "ShowAlbumViewController"{
            if let AlbumVC = segue.destination as? AlbumViewController{
                guard let theAlbumData = AlbumData(pinID: selectedPin.uniqueIdentifier) else{print("Couldnt Initialize AlbumData!!!");return}
                AlbumVC.selectedPin = selectedPin
                AlbumVC.albumData = theAlbumData
            }
        }
    }
    
    
    @IBAction func enterButton(_ sender: UIButton) {
        UIView.transition(
            from: entryView,
            to: traveledPlacesView,
            duration: 0.75,
            options: [.transitionCurlUp, .showHideTransitionViews],
            completion: {transitioned in Traveler.shouldShowIntroMessageIn(self)}
        )
    }
    
    @IBAction func backToEntry(_ sender: UIButton) {
                UIView.transition(
                    from: traveledPlacesView,
                    to: entryView,
                    duration: 0.75,
                    options: [.transitionCurlDown, .showHideTransitionViews],
                    completion: {transitioned in /*Enter Code if Needed*/}
        )
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
                                    assignment: {/*May Need to enter some clean up code here*/})
            case let netError as NetworkError:
                SendToDisplay.error(self,
                                    errorType: "Network Error",
                                    errorMessage: netError.localizedDescription,
                                    assignment: {/*May Need to enter some clean up code here*/})
            default: print("Error is not an expected one in addTravelerPin(:_)")}
                return
            }
            print("Pin successfully Framed and Saved!")
            annotation.isSelectable = true
        }
    }
    
    @IBAction func editPins(_ sender: UIButton) {switchDeleteMode()}
    
    func switchDeleteMode(){
        switch deleteMode{
        case true: deleteMode = false; animateMessage(show: false)
        case false: deleteMode = true ; animateMessage(show: true)
        }
    }
    
}
















