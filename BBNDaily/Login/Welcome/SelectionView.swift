//
//  SelectionView.swift
//  BBNDaily
//
//  Created by Mike Veson on 4/6/23.
//

import Foundation
import UIKit

enum SelectionType {
    case classSelection
    case lunchSelection
}

class SelectionView: UIView, UIPickerViewDelegate, UIPickerViewDataSource {
    var delegate: SelectionViewDelegate?
    private var selectionType: SelectionType
    private var titles: [String]
    private var options: [[String]]
    
    private var pickers: [UIPickerView] = []
    private let doneButton = UIButton()
    private var currentPage: Int = 0
    
    private let searchController = UISearchController(searchResultsController: nil)
    private let tableView = UITableView()
    private var filteredOptions: [[String]] = []
    
    init(frame: CGRect, selectionType: SelectionType, titles: [String], options: [[String]], delegate: SelectionViewDelegate? = nil) {
        self.selectionType = selectionType
        self.titles = titles
        self.options = options
        self.delegate = delegate
        super.init(frame: frame)
        setupTitleLabel()
        setupDoneButton()
        
        if selectionType == .classSelection {
            setupSearch()
        } else {
            setupPickers()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupTitleLabel() {
        let titleLabel = UILabel(frame: CGRect(x: 0, y: frame.height * 0.05, width: frame.width, height: frame.height * 0.1))
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = UIColor(named: "white")
        titleLabel.text = selectionType == .classSelection ? "Classes" : "Lunch Times"
        addSubview(titleLabel)
    }
    
    private func setupSearch() {
        let topPadding: CGFloat = 50.0
        
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search for your class"
        searchController.searchBar.sizeToFit()
        searchController.searchBar.barTintColor = UIColor(named: "blue")
        searchController.searchBar.frame.origin.y = topPadding
        addSubview(searchController.searchBar)
        
        tableView.frame = CGRect(x: 0,
                                 y: searchController.searchBar.bounds.height + topPadding,
                                 width: frame.width,
                                 height: frame.height * 0.8 - searchController.searchBar.bounds.height)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor(named: "blue")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        addSubview(tableView)
        
        filteredOptions = options
    }
    private func setupPickers() {
        let numberOfPickers = titles.count
        let pickerWidth = frame.width * 0.8
        let pickerHeight = frame.height * 0.08
        let pickerSpacing = frame.height * 0.01
        let labelHeight = frame.height * 0.04
        let totalPickerHeight = CGFloat(numberOfPickers) * (pickerHeight + labelHeight + pickerSpacing)
        let firstPickerYPosition = (frame.height - totalPickerHeight) / 2

        for (index, title) in titles.enumerated() {
            let pickerView = UIPickerView()
            pickerView.tag = index
            pickerView.delegate = self
            pickerView.dataSource = self
            pickerView.frame = CGRect(x: (frame.width - pickerWidth) / 2,
                                      y: firstPickerYPosition + CGFloat(index) * (pickerHeight + labelHeight + pickerSpacing),
                                      width: pickerWidth,
                                      height: pickerHeight)
            addSubview(pickerView)
            pickers.append(pickerView)

            let label = UILabel(frame: CGRect(x: (frame.width - pickerWidth) / 2,
                                              y: pickerView.frame.minY - labelHeight,
                                              width: pickerWidth,
                                              height: labelHeight))
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
            label.text = title
            addSubview(label)
        }
    }
    private func setupDoneButton() {
        doneButton.frame = CGRect(x: 0, y: 0, width: frame.width * 0.3, height: frame.height * 0.07)
        doneButton.center = CGPoint(x: frame.width / 2, y: doneButton.bounds.height*5/6)
        doneButton.setTitle("Continue", for: .normal)
        doneButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        doneButton.setTitleColor(UIColor(named: "blue"), for: .normal)
        doneButton.backgroundColor = .white
        doneButton.layer.cornerRadius = doneButton.bounds.height / 2
        doneButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        addSubview(doneButton)
    }
    
    @objc private func doneButtonTapped() {
        if currentPage < titles.count - 1 {
            currentPage += 1
            setupSearch()
        } else {
            delegate?.selectionCompleted(for: selectionType)
        }
    }
    
    // UIPickerViewDataSource and UIPickerViewDelegate methods
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return options[pickerView.tag].count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return options[pickerView.tag][row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // Handle picker selection if needed
    }
}

protocol SelectionViewDelegate {
    func selectionCompleted(for selectionType: SelectionType)
}

extension SelectionView: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredOptions[currentPage].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = filteredOptions[currentPage][indexPath.row]
        return cell
    }
    
    // add some feature for selection
    //    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    //        selectedIndices[currentPage] = indexPath.row
    //        updateDoneButtonVisibility()
    //    }
}

extension SelectionView: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        if searchText.isEmpty {
            filteredOptions = options
        } else {
            filteredOptions[currentPage] = options[currentPage].filter { option in
                return option.lowercased().contains(searchText.lowercased())
            }
        }
        tableView.reloadData()
    }
}
