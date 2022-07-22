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

class ComingSoonView: UIView {
    private let TextLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(named: "background")
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.layer.masksToBounds = true
        label.layer.cornerRadius = 8
//        label.padding(2, 2, 8, 8)
        label.font = .systemFont(ofSize: 18, weight: .regular)
        label.numberOfLines = 2
        label.text = "Coming Soon! For now, press the button below to call the bus."
        return label
    } ()
    public let phoneButton: UIButton = {
        let editButton = UIButton()
        editButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.setTitle("", for: .normal)
        editButton.setImage(UIImage(systemName: "phone.fill"), for: .normal)
        editButton.addTarget(self, action: #selector(callBus), for: .touchUpInside)
        editButton.tintColor = UIColor(named: "background")
        return editButton
    } ()
    @objc func callBus() {
        guard let number = URL(string: "tel://" + "16175930396") else { return }
        UIApplication.shared.open(number)
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.layer.masksToBounds = true
        self.layer.cornerRadius = 8
        self.backgroundColor = UIColor(named: "inverse")?.withAlphaComponent(0.8)
        self.addSubview(TextLabel)
        self.addSubview(phoneButton)
        TextLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        TextLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: -10).isActive = true
        TextLabel.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 1).isActive = true
        TextLabel.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -1).isActive = true
        phoneButton.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        phoneButton.topAnchor.constraint(equalTo: TextLabel.bottomAnchor, constant: 5).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
class MapsVC: UIViewController, ResultsViewControllerDelegate, CLLocationManagerDelegate, GMSMapViewDelegate {
    @IBAction func moreInfo(_ sender: UIBarButtonItem) {
        guard let number = URL(string: "tel://" + "16175930396") else { return }
        UIApplication.shared.open(number)
//        ProgressHUD.colorAnimation = UIColor(named: "gold-bright")!
//        ProgressHUD.showSucceed("Coming Soon! \n Bus number is (617) 593-0396")
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
        marker.title = "\(classroom.name)"
        marker.snippet = "Upper School"
        marker.icon = UIImage(named: "map-marker")?.withTintColor(UIColor(named: "blue")!)
        marker.map = mapView
        self.mapView.camera = camera
    }
    
    var ResultsViewController: ResultsVC!
    var searchVC = UISearchController()
    var mapView: GMSMapView!
    func draw(src: CLLocationCoordinate2D, dst: CLLocationCoordinate2D) {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)

        let url = URL(string: "https://maps.googleapis.com/maps/api/directions/json?origin=\(src.latitude),\(src.longitude)&destination=\(dst.latitude),\(dst.longitude)&sensor=false&mode=driving&key=AIzaSyBY5M_mXpnXwCz5-T889VLtkm22HjY8-rw")!

        let task = session.dataTask(with: url, completionHandler: {
            (data, response, error) in
            if error != nil {
                print(error!.localizedDescription)
            } else {
                do {
                    if let json : [String:Any] = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String: Any] {
                        let preRoutes = json["routes"] as! NSArray
                        let routes = preRoutes[0] as! NSDictionary
                        let routeOverviewPolyline:NSDictionary = routes.value(forKey: "overview_polyline") as! NSDictionary
                        let polyString = routeOverviewPolyline.object(forKey: "points") as! String
                        DispatchQueue.main.async(execute: {
                            let path = GMSPath(fromEncodedPath: polyString)
                            let polyline = GMSPolyline(path: path)
                            polyline.strokeWidth = 6.0
                            polyline.strokeColor = UIColor(named: "maps-border")!
                            polyline.map = self.mapView
                            let innerline = GMSPolyline(path: path)
                            innerline.strokeWidth = 3.0
                            innerline.strokeColor = UIColor(named: "maps-blue")!
                            innerline.map = self.mapView
                        })
                    }

                } catch {
                    print("parsing error")
                }
            }
        })
        task.resume()
    }
    private var comingSoonView: ComingSoonView!
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        mapView.clear()
        mapView.removeFromSuperview()
        mapView = nil
        comingSoonView.removeFromSuperview()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isTranslucent = true
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        mapView = GMSMapView(frame: view.bounds)
        view.addSubview(mapView)
        addLocations()
        locationManager.requestWhenInUseAuthorization()
        self.mapView.isMyLocationEnabled = true
        self.mapView.delegate = self
        self.locationManager.delegate = self
        self.locationManager.startUpdatingLocation()
        mapView.mapType = .normal
        mapView.settings.scrollGestures = true
        mapView.settings.zoomGestures = true
        view.addSubview(comingSoonView)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        comingSoonView = ComingSoonView(frame: CGRect(x: (view.frame.width-(view.frame.width-100))/2, y: (view.frame.height-120)/2, width: view.frame.width-100, height: 120))
//        view.addSubview(comingSoonView)
        GMSServices.provideAPIKey("AIzaSyBY5M_mXpnXwCz5-T889VLtkm22HjY8-rw")
        // 42.36894453932155, -71.13374727281084
    }
    func mapViewDidFinishTileRendering(_ mapView: GMSMapView) {
        view.bringSubviewToFront(comingSoonView)
    }
    func addLocations() {
        let camera = GMSCameraPosition.camera(withLatitude: 42.36894453932155, longitude: -71.13374727281084, zoom: 15)
        mapView = GMSMapView.map(withFrame: .zero, camera: camera)
        let marker = GMSMarker()
        let coord = CLLocationCoordinate2D(latitude: 42.37088697136021, longitude: -71.13551938855346)
        marker.position = coord
        marker.title = "Buckingham Browne & Nichols"
        marker.icon = UIImage(named: "map-marker")?.withTintColor(UIColor(named: "blue")!)
        marker.snippet = "Upper School"
        marker.map = mapView

        let fourthMarker = GMSMarker()
        let coord2 = CLLocationCoordinate2D(latitude: 42.365025316906966, longitude: -71.13659662107911)
        fourthMarker.position = coord2
        fourthMarker.title = "Fourth Lot"
        fourthMarker.icon = UIImage(named: "parking")?.withTintColor(UIColor(named: "blue")!)
        fourthMarker.snippet = "Parking"
        fourthMarker.map = mapView

        let harvardMarker = GMSMarker()
        let coord3 = CLLocationCoordinate2D(latitude: 42.3729343, longitude: -71.1218140)
        harvardMarker.position = coord3
        harvardMarker.title = "Harvard Square"
        harvardMarker.icon = UIImage(named: "harvard")
        harvardMarker.snippet = "Bus Stop"
        harvardMarker.map = mapView
        
        self.view = mapView
        draw(src: coord, dst: coord2)
        draw(src: coord, dst: coord3)
    }
    func createSearchBar(){
        searchVC = UISearchController(searchResultsController: ResultsViewController)
        self.navigationItem.searchController = searchVC
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
