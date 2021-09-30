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
import ProgressHUD

protocol ResultsViewControllerDelegate: AnyObject {
    func didTapPlace(with classroom: Classroom)
}
class MapsVC: UIViewController, UISearchResultsUpdating, ResultsViewControllerDelegate, CLLocationManagerDelegate {
    @IBAction func moreInfo(_ sender: UIBarButtonItem) {
        ProgressHUD.colorAnimation = UIColor(named: "gold-bright")!
        ProgressHUD.showSucceed("Coming Soon! \n Bus number is (617) 593-0396")
    }
    var locationManager = CLLocationManager()
    func didTapPlace(with classroom: Classroom) {
        self.searchVC.searchBar.text = classroom.name
        self.searchVC.searchBar.resignFirstResponder()
        GMSServices.provideAPIKey("AIzaSyBY5M_mXpnXwCz5-T889VLtkm22HjY8-rw")
        mapView.clear()
        let camera = GMSCameraPosition.camera(withLatitude: classroom.lat, longitude: classroom.lon, zoom: 19)
        let marker = GMSMarker()
        let coord = CLLocationCoordinate2D(latitude: classroom.lat, longitude: classroom.lon)
        marker.position = coord
//        marker.p
        marker.title = "\(classroom.name)"
//        marker.iconView = backview
        marker.snippet = "Upper School"
        marker.icon = UIImage(named: "map-marker")
        marker.map = mapView
        self.mapView.camera = camera
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        guard let query = searchController.searchBar.text, !query.trimmingCharacters(in: .whitespaces).isEmpty, let resultsVC = searchController.searchResultsController as? ResultsVC else {
            ResultsViewController.configureData(with: [Classroom]())
            return
        }
        
        resultsVC.delegate = self
        ResultsViewController.configureData(with: places.filter {c in
            return c.name.lowercased().contains(query.lowercased())
        })
    }
    var ResultsViewController: ResultsVC!
    var searchVC = UISearchController()
    var mapView: GMSMapView!
    override func viewDidLoad() {
        super.viewDidLoad()
//        let map = MKMapView(frame: .zero)
//        map.camera = MKMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: 0, longitude: 0), fromDistance: 1000, pitch: 0, heading: 0)
//        map.mapType = .satellite
//        map.translatesAutoresizingMaskIntoConstraints = false
//        view.addSubview(map)
//        map.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
//        map.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
//        map.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
//        map.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        GMSServices.provideAPIKey("AIzaSyBY5M_mXpnXwCz5-T889VLtkm22HjY8-rw")
        let camera = GMSCameraPosition.camera(withLatitude: 42.37088697136021, longitude: -71.13551938855346, zoom: 19) // 42.37088697136021, -71.13551938855346
        mapView = GMSMapView.map(withFrame: .zero, camera: camera)
        let marker = GMSMarker()
        let coord = CLLocationCoordinate2D(latitude: 42.37088697136021, longitude: -71.13551938855346)
        marker.position = coord
//        marker.p
        marker.title = "Buckingham Browne & Nichols"
//        marker.iconView = backview
        marker.icon = UIImage(named: "map-marker")
        marker.snippet = "Upper School"
        marker.map = mapView
//        mapView.show
        self.view = mapView
        locationManager.requestWhenInUseAuthorization()
//        if(CLLocationManager.authorizationStatus() == .authorizedWhenInUse ||
//        CLLocationManager.authorizationStatus() == .authorizedAlways) {
//           currentLoc = locationManager.location
//           print(currentLoc.coordinate.latitude)
//           print(currentLoc.coordinate.longitude)
//        }
        self.mapView.isMyLocationEnabled = true
        self.locationManager.delegate = self
        self.locationManager.startUpdatingLocation()
        ResultsViewController = ResultsVC()
        createSearchBar()
        mapView.mapType = .satellite
        mapView.settings.scrollGestures = true
        mapView.settings.zoomGestures = true
    }
    func createSearchBar(){
        searchVC = UISearchController(searchResultsController: ResultsViewController)
        self.navigationItem.searchController = searchVC
        searchVC.searchResultsUpdater = self
        searchVC.hidesNavigationBarDuringPresentation = false
        searchVC.searchBar.searchTextField.layer.cornerRadius = 8
        searchVC.searchBar.searchTextField.layer.masksToBounds = true
        searchVC.searchBar.compatibleSearchTextField.backgroundColor = UIColor(named: "blue")?.withAlphaComponent(0.5)
        searchVC.searchBar.tintColor = .systemBlue
        searchVC.obscuresBackgroundDuringPresentation = false
        searchVC.searchBar.placeholder = "Search '112'"
    }
    var filteredPlaces = [Classroom]()
    private var places = [
        Classroom(name: "102", lat: 42.371143090592966, lon: -71.135895064596),
        Classroom(name: "104", lat: 42.371117329758896, lon: -71.13596882534264),
        Classroom(name: "106", lat: 42.37105193682474, lon: -71.13617535543364),
        Classroom(name: "108", lat: 42.37101478171876, lon: -71.13614383947855),
        Classroom(name: "110", lat: 42.371008876783286, lon: -71.13617720481203),
        Classroom(name: "112", lat: 42.37096565563067, lon: -71.13616451475455),
        Classroom(name: "114", lat: 42.37092255405722, lon: -71.13616807208356),
        Classroom(name: "116", lat: 42.370928729748066, lon: -71.13611063447398),
        Classroom(name: "118", lat: 42.37087819227349, lon: -71.13609318549133),
        Classroom(name: "120", lat: 42.37087197659383, lon: -71.13611671230437),
        Classroom(name: "122", lat: 42.37078712146334, lon: -71.13609093818819),
        Classroom(name: "124", lat: 42.370754754736275, lon: -71.13598899590134),
        Classroom(name: "126 Gallery", lat: 42.37070299684498, lon: -71.13595847721366),
        Classroom(name: "131", lat: 42.3706458772055, lon: -71.13586362803443),
        Classroom(name: "131d", lat: 42.37063469018377, lon: -71.13598074112573),
        Classroom(name: "133", lat: 42.370744806032704, lon: -71.13580066093222),
        Classroom(name: "134", lat: 42.3705348642929, lon: -71.13592253614607),
        Classroom(name: "135", lat: 42.37065612517005, lon: -71.13575216760819),
        Classroom(name: "136", lat: 42.37054459092512, lon: -71.13582968534519),
        Classroom(name: "136a", lat: 42.3705584129789, lon: -71.13572574788151),
        Classroom(name: "137", lat: 42.370648151927924, lon: -71.1356945012397),
        Classroom(name: "139", lat: 42.37063838583939, lon: -71.13563720895421),
        Classroom(name: "140a", lat: 42.37056034665353, lon: -71.13569052908025),
        Classroom(name: "140b", lat: 42.37056420076939, lon: -71.13565401209436),
        Classroom(name: "140c", lat: 42.370573336447684, lon: -71.13558104974827),
        Classroom(name: "140d", lat: 42.370578430864484, lon: -71.135540514847),
        Classroom(name: "140e", lat: 42.37058188119343, lon: -71.13548624882092),
        Classroom(name: "141", lat: 42.370648302752606, lon: -71.13555060294942),
        Classroom(name: "143", lat: 42.37069558341592, lon: -71.135568221264),
        Classroom(name: "150 Community Room", lat: 42.37078418003762, lon: -71.13522258742238),
        Classroom(name: "153", lat: 42.371055822407584, lon: -71.1354813543727),
        Classroom(name: "153a", lat: 42.37104422263877, lon: -71.13553131181352),
        Classroom(name: "153b", lat: 42.37111962109817, lon: -71.13543639267418),
        Classroom(name: "154", lat: 42.37100731426951, lon: -71.13529365712897),
        Classroom(name: "158", lat: 42.371066894912545, lon: -71.13526796473083),
        Classroom(name: "160", lat: 42.37111380603348, lon: -71.13523892388154),
        Classroom(name: "162", lat: 42.37114844040946, lon: -71.13522298194543),
        Classroom(name: "159", lat: 42.371167601888644, lon: -71.13539214465516),
        Classroom(name: "161", lat: 42.37117603806779, lon: -71.13533861882573),
        Classroom(name: "164", lat: 42.37119186161864, lon: -71.13519372397114),
        Classroom(name: "171", lat: 42.37128186919665, lon: -71.13529138171313),
        Classroom(name: "170", lat: 42.37125476092494, lon: -71.13518194674272),
        Classroom(name: "172", lat: 42.37130858537956, lon: -71.13517390382283),
        Classroom(name: "173", lat: 42.37136187582344, lon: -71.13526720900462),
        Classroom(name: "174", lat: 42.371362237002565, lon: -71.1351742313013),
        Classroom(name: "175", lat: 42.37135187500068, lon: -71.13530878606328),
        Classroom(name: "176", lat: 42.371436256347785, lon: -71.13517334419076),
        Classroom(name: "177", lat: 42.37140004878434, lon: -71.13526762574014),
        Classroom(name: "179", lat: 42.371402147839746, lon: -71.13531024374129),
        Classroom(name: "178", lat: 42.371457963676285, lon: -71.13519245694023),
        Classroom(name: "178a", lat: 42.371457007903395, lon: -71.13515494919064),
        Classroom(name: "181", lat: 42.37142224641618, lon: -71.1352662932065),
        Classroom(name: "182", lat: 42.37148627367455, lon: -71.13517710000423),
        Classroom(name: "183", lat: 42.37148856356952, lon: -71.13528898962103),
        Classroom(name: "185", lat: 42.37153612174247, lon: -71.13528496630761),
        Classroom(name: "184", lat: 42.37151283805813, lon: -71.13514347978584),
        Classroom(name: "186", lat: 42.371545534293276, lon: -71.13519645341246),
        Classroom(name: "206", lat: 42.371143090592966, lon: -71.135895064596),
        Classroom(name: "204", lat: 42.371117329758896, lon: -71.13596882534264),
        Classroom(name: "210", lat: 42.371008876783286, lon: -71.13617720481203),
        Classroom(name: "212", lat: 42.37092255405722, lon: -71.13616807208356),
        Classroom(name: "214", lat: 42.370754754736275, lon: -71.13598899590134),
        Classroom(name: "216", lat: 42.37078712146334, lon: -71.13609093818819),
        Classroom(name: "218", lat: 42.37074224413571, lon: -71.13611700634371),
        Classroom(name: "220", lat: 42.370749188701595, lon: -71.13608567368556),
        Classroom(name: "222", lat: 42.370755554552986, lon: -71.13604180796412),
        Classroom(name: "226 Gallery", lat: 42.37070299684498, lon: -71.13595847721366),
        Classroom(name: "230", lat: 42.370662690200604, lon: -71.13590008662246),
        Classroom(name: "231", lat: 42.3706458772055, lon: -71.13586362803443),
        Classroom(name: "233", lat: 42.370744806032704, lon: -71.13580066093222),
        Classroom(name: "234", lat: 42.3705348642929, lon: -71.13592253614607),
        Classroom(name: "235", lat: 42.37065612517005, lon: -71.13575216760819),
        Classroom(name: "236", lat: 42.37054459092512, lon: -71.13582968534519),
        Classroom(name: "237", lat: 42.370648302752606, lon: -71.13555060294942),
        Classroom(name: "239", lat: 42.3706563231378, lon: -71.13551970979613),
        Classroom(name: "241", lat: 42.37071898518477, lon: -71.13562661216325),
        Classroom(name: "243", lat: 42.3707252029457, lon: -71.1355639956915),
        Classroom(name: "245", lat: 42.370701484867325, lon: -71.13554473357887),
        Classroom(name: "242", lat: 42.370573336447684, lon: -71.13558104974827),
        Classroom(name: "244", lat: 42.37060367222293, lon: -71.13539998355326),
        Classroom(name: "246", lat: 42.37060813086598, lon: -71.13534499826905),
        Classroom(name: "248", lat: 42.3706116213915, lon: -71.13531077565662),
        Classroom(name: "247 Drama Room", lat: 42.370735987734065, lon: -71.1355087146159),
        Classroom(name: "250 Theatre", lat: 42.37078418003762, lon: -71.13522258742238),
        Classroom(name: "249 Library", lat: 42.3708945717684, lon: -71.13548970300788),
        Classroom(name: "253 Library", lat: 42.37096975250899, lon: -71.13553985663359),
        Classroom(name: "254", lat: 42.37100731426951, lon: -71.13529365712897),
        Classroom(name: "255 Quiet Room", lat: 42.37111962109817, lon: -71.13543639267418),
        Classroom(name: "256", lat: 42.371066894912545, lon: -71.13526796473083),
        Classroom(name: "258", lat: 42.37111380603348, lon: -71.13523892388154),
        Classroom(name: "264", lat: 42.37119186161864, lon: -71.13519372397114),
        Classroom(name: "270", lat: 42.37125476092494, lon: -71.13518194674272),
        Classroom(name: "272", lat: 42.371362237002565, lon: -71.1351742313013),
        Classroom(name: "273", lat: 42.37135187500068, lon: -71.13530878606328),
        Classroom(name: "276", lat: 42.37139976243327, lon: -71.13519029325981),
        Classroom(name: "281", lat: 42.37142224641618, lon: -71.1352662932065),
        Classroom(name: "278a", lat: 42.371423744174066, lon: -71.13519411707188),
        Classroom(name: "278", lat: 42.371457963676285, lon: -71.13519245694023),
        Classroom(name: "280", lat: 42.37148627367455, lon: -71.13517710000423),
        Classroom(name: "282", lat: 42.371545534293276, lon: -71.13519645341246),
        Classroom(name: "285", lat: 42.37153612174247, lon: -71.13528496630761),
        Classroom(name: "283", lat: 42.37148856356952, lon: -71.13528898962103)
    ]
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.navigationBar.isTranslucent = true
    }
}
struct Classroom {
    let name: String
    let lat: Double
    let lon: Double
}
class ResultsVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    weak var delegate: ResultsViewControllerDelegate?
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return places.count
    }
    public func configureData(with array: [Classroom]) {
        places = array
        tableView.reloadData()
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = places[indexPath.row].name
        cell.textLabel?.textColor = UIColor(named: "inverse")
        cell.backgroundColor = UIColor(named: "background")
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        dismiss(animated: true, completion: nil)
        delegate?.didTapPlace(with: places[indexPath.row])
    }
    private let tableView: UITableView = {
        let table = UITableView()
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "background")
        configureTableView()
    }
    var places = [Classroom]()
    func configureTableView() {
        tableView.tableFooterView = UIView(frame: .zero)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor(named: "background")
//        tableView.frame = view.bounds
        view.addSubview(tableView)
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        tableView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }
}


extension UISearchBar {
    
    // Due to searchTextField property who available iOS 13 only, extend this property for iOS 13 previous version compatibility
    var compatibleSearchTextField: UITextField {
        guard #available(iOS 13.0, *) else { return legacySearchField }
        return self.searchTextField
    }
    
    private var legacySearchField: UITextField {
        if let textField = self.subviews.first?.subviews.last as? UITextField {
            // Xcode 11 previous environment
            return textField
        } else if let textField = self.value(forKey: "searchField") as? UITextField {
            // Xcode 11 run in iOS 13 previous devices
            return textField
        } else {
            // exception condition or error handler in here
            return UITextField()
        }
    }
}
