//
//  SettingsBlockTableViewCell.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit

class SettingsBlockTableViewCell: UITableViewCell {
    static let identifier = "SettingsBlockTableViewCell"
    private let TitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .systemGray
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    } ()
    private let DataLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.systemBlue
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .right
        return label
    } ()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier )
        contentView.addSubview(TitleLabel)
        contentView.addSubview(DataLabel)
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        TitleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        TitleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        TitleLabel.rightAnchor.constraint(equalTo: DataLabel.leftAnchor, constant: -5).isActive = true
        DataLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
        DataLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
    }
    func configure(with viewModel: settingsBlock) {
        backgroundColor = UIColor(named: "background")
        if viewModel.blockName.count > 1 {
            TitleLabel.text = "\(viewModel.blockName)"
        }
        else {
            TitleLabel.text = "\(viewModel.blockName) Block"
        }
        var className = viewModel.className
        if className != "" {
            if className.contains("~") {
                let array = className.getValues()
                className = "\(array[0]) \(array[1].replacingOccurrences(of: "N/A", with: ""))"
            }
            DataLabel.text = className
        }
        else {
            if viewModel.blockName.count > 1 {
                if viewModel.blockName.lowercased().contains("share") {
                    DataLabel.text = ""
                }
                else {
                    DataLabel.text = "Not set"
                }
            }
            else if viewModel.blockName.lowercased().contains("lunch") {
                DataLabel.text = "2nd Lunch"
            }
            else {
                DataLabel.text = "[Class] [Room #]"
            }
        }
    }
}
