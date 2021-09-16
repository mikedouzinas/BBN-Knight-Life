//
//  Maps.swift
//  BBNDaily
//
//  Created by Mike Veson on 9/15/21.
//

import Foundation
import UIKit
import GoogleMaps
import MapKit
//AIzaSyBY5M_mXpnXwCz5-T889VLtkm22HjY8-rw

class MapsVC: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
//        let map = MKMapView(frame: .zero)
//        map.camera = MKMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: 42.37098, longitude: -71.13559), fromDistance: 1000, pitch: 0, heading: 0)
//        map.mapType = .satellite
//        map.translatesAutoresizingMaskIntoConstraints = false
//        view.addSubview(map)
//        map.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
//        map.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
//        map.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
//        map.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        GMSServices.provideAPIKey("AIzaSyBY5M_mXpnXwCz5-T889VLtkm22HjY8-rw")
        let camera = GMSCameraPosition.camera(withLatitude: 42.37098, longitude: -71.13559, zoom: 19)
        let mapView = GMSMapView.map(withFrame: .zero, camera: camera)
        self.view = mapView
        // Creates a marker in the center of the map.
        let marker = GMSMarker()
        marker.position = CLLocationCoordinate2D(latitude: 42.37098, longitude: -71.13559)

        marker.title = "Buckingham Browne & Nichols"
        let backview = GMSPanoramaView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        backview.layer.masksToBounds = true
        backview.backgroundColor = UIColor.red
        backview.layer.cornerRadius = 8
        marker.icon = UIImage(named: "vanguardLogo")
//        marker.iconView = backview
        marker.snippet = "Cambridge, MA"
        marker.map = mapView
        mapView.mapType = .satellite
        mapView.settings.scrollGestures = true
        mapView.settings.zoomGestures = true
        marker.panoramaView?.layer.masksToBounds = true
        marker.panoramaView?.layer.cornerRadius = 8
    }
}
