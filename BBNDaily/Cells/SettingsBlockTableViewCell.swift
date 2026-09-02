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
        // HQ-659: explicit rather than relying on UILabel's default (which happens to
        // already be 1 line / truncating tail) - this is where a class's full name
        // ("Subject Teacher") shows in the block list, and it's the one label in this
        // ticket's four required render spots that isn't shared with unrelated content.
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
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
                // An action row has nothing to display on the right. This reads the row's own
                // isAction flag rather than sniffing its title for "share"/"apple"/"google",
                // which is why "Clear My Classes" rendered as "Not Set": it was an action row
                // whose name nobody had added to that list.
                DataLabel.text = viewModel.isAction ? "" : "Not Set"
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
