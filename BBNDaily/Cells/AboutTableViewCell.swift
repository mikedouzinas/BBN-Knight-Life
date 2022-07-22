//
//  AboutTableViewCell.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit

class AboutTableViewCell: UITableViewCell {
    static let identifier = "AboutTableViewCell"
    let leftLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .regular)
        label.textColor = UIColor(named: "inverse")
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundColor = UIColor(named: "inverse")?.withAlphaComponent(0.1)
        //        contentView.backgroundColor =  UIColor(named: "inverseBackgroundCol")?.withAlphaComponent(0.1)
        leftLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        leftLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
    }
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(leftLabel)
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    public func configure(with viewModel: Library) {
        accessoryType = .disclosureIndicator
        leftLabel.text = "\(viewModel.name)"
    }
}
