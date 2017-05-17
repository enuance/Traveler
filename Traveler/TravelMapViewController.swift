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
    
    
    
    
    
    override func viewDidLoad() {super.viewDidLoad()
        UIApplication.shared.statusBarStyle = .lightContent
        setupTouchSenitivity()
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
    
    func setupTouchSenitivity(){
        let touchSenitivity = UILongPressGestureRecognizer(target: self, action: #selector(addTravelerPin))
        touchSenitivity.minimumPressDuration = 0.8
        touchSenitivity.allowableMovement = 2
        mapView.addGestureRecognizer(touchSenitivity)
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        print("pin Selected")
    }
    
    @IBAction func enterButton(_ sender: UIButton) {
        UIView.transition(
            from: entryView,
            to: traveledPlacesView,
            duration: 0.75,
            options: [.transitionCurlUp, .showHideTransitionViews],
            completion: {transitioned in /*Enter Code if Needed*/}
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
        guard gestureRecognizer.state == .ended else{return}
        let touch = gestureRecognizer.location(in: mapView)
        let selectedPoint = mapView.convert(touch, toCoordinateFrom: mapView)
        let uniqueID = UUID().uuidString
        let annotation = PinAnnotation(coordinate: selectedPoint, uniqueIdentifier: uniqueID)
        Traveler.addToDatabase(annotation, completion: {
            _ , error in
            guard (error == nil) else{
                SendToDisplay.error(self,
                                    errorType: "DataBase Error",
                                    errorMessage: error!.localizedDescription,
                                    assignment: nil)
                return}
            mapView.addAnnotation(annotation)
            print("pinAdded!")
        })
    }
    
}


















