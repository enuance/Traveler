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
    var selectedPinID: String!
    
    override func viewDidLoad() {super.viewDidLoad()
        UIApplication.shared.statusBarStyle = .lightContent
        setupTouchSenitivity()
        addDataBasePins(to: mapView)
    }


    override func viewWillAppear(_ animated: Bool) {super.viewWillAppear(animated)
        
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
        let pins = Traveler.retrievePinsFromDataBase()
        guard pins.error == nil else{
            SendToDisplay.error(self,
                                errorType: "DataBase Error",
                                errorMessage: pins.error!.localizedDescription,
                                assignment: nil);return
        }
        guard let pinsList = pins.pins else{print("No pins to add to map");return}
        map.addAnnotations(pinsList)
        print("Added Pins to Map")
    }
    
    func setupTouchSenitivity(){
        let touchSenitivity = UILongPressGestureRecognizer(target: self, action: #selector(addTravelerPin))
        touchSenitivity.minimumPressDuration = 0.8
        touchSenitivity.allowableMovement = 2
        mapView.addGestureRecognizer(touchSenitivity)
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let pinAnnotation = view.annotation as? PinAnnotation else{return}
        let uniqueID = pinAnnotation.uniqueIdentifier!
        print("pin \(uniqueID) Selected")
        selectedPinID = uniqueID
        if deleteMode{
            if let error = Traveler.deletePinFromDataBase(uniqueID: uniqueID){
                SendToDisplay.error(self,
                                    errorType: "DataBase Error",
                                    errorMessage: error.localizedDescription,
                                    assignment: nil)
            };mapView.removeAnnotation(view.annotation!)
            switchDeleteMode()
        }else{
            
            goToLocationAlbum()
            
            
            
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {super.prepare(for: segue, sender: sender)
        guard let identifier = segue.identifier else{return}
        if identifier == "ShowAlbumViewController"{
            if let AlbumVC = segue.destination as? AlbumViewController{
                AlbumVC.pinUniqueID = selectedPinID
            }
        }
    }
    
    func goToLocationAlbum(){
        UIView.animate(
            withDuration: 0.5,
            animations: {
                self.bottomTray.transform = CGAffineTransform(
                        translationX: self.bottomTray.frame.origin.x,
                        y: self.bottomTray.frame.height)
        }, completion: {
                completed in self.performSegue(withIdentifier: "ShowAlbumViewController", sender: self)
        })
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
        if let error = Traveler.addToDatabase(annotation){
            SendToDisplay.error(self,
                                errorType: "DataBase Error",
                                errorMessage: error.localizedDescription,
                                assignment: nil)
        }
        mapView.addAnnotation(annotation)
        print("pinAdded!")
    }
    
    @IBAction func editPins(_ sender: UIButton) {switchDeleteMode()}
    
    func switchDeleteMode(){
        switch deleteMode{
        case true: deleteMode = false; animateMessage(show: false)
        case false: deleteMode = true ; animateMessage(show: true)
        }
    }
    

    
    
}


















