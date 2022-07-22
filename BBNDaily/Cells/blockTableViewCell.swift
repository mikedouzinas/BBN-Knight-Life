//
//  blockTableViewCell.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit

class blockTableViewCell: UITableViewCell {
    static let identifier = "blockTableViewCell"
    
    private let TitleLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.textColor = UIColor(named: "inverse")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.minimumScaleFactor = 0.5
        label.text = "ndiewniedneddeewjd"
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    private let BlockLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(named: "lightGray")
        label.minimumScaleFactor = 0.8
        label.text = "ndiewniedneddeewjd"
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    private let RightLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(named: "gold-text")
        label.minimumScaleFactor = 0.8
        label.textAlignment = .right
        label.text = "ndiewniedneddeewjd"
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    private let BottomRightLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.minimumScaleFactor = 0.8
        label.textColor = UIColor(named: "lightGray")
        label.text = "ndiewniedneddeewjd"
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(TitleLabel)
        contentView.addSubview(BlockLabel)
        contentView.addSubview(RightLabel)
        contentView.addSubview(BottomRightLabel)
        contentView.backgroundColor = UIColor(named: "background")
        
        isSkeletonable = true
        contentView.isSkeletonable = true
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    var constraint = NSLayoutConstraint()
    override func layoutSubviews() {
        super.layoutSubviews()
        constraint = TitleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10)
        constraint.isActive = true
        
        TitleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        TitleLabel.rightAnchor.constraint(equalTo: RightLabel.leftAnchor, constant: -2).isActive = true
        
        BlockLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 10).isActive = true
        BlockLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        
        RightLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        RightLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10).isActive = true
        RightLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
        
        BottomRightLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 10).isActive = true
        BottomRightLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
        
    }
    override func prepareForReuse(){
        super.prepareForReuse()
    }
    func configure (with viewModel: ClassModel){
        BlockLabel.isHidden = false
        BottomRightLabel.isHidden = false
        RightLabel.isHidden = false
        TitleLabel.text = viewModel.Subject
        BlockLabel.text = viewModel.Teacher
        RightLabel.text = viewModel.Room
        BottomRightLabel.text = "\(viewModel.Block.capitalized) Block"
    }
    func configure(with viewModel: Person) {
        BlockLabel.isHidden = false
        RightLabel.isHidden = true
        BottomRightLabel.isHidden = true
        TitleLabel.text = viewModel.name
        BlockLabel.text = viewModel.email
    }
    func configure (with viewModel: block, isLunch: Bool, selectedDay: Int){
        RightLabel.isHidden = false
        if viewModel.block != "N/A" {
            BlockLabel.isHidden = false
            var className = LoginVC.blocks[viewModel.block] as? String
            if className == "" {
                className = "[\(viewModel.block) Class]"
            }
            var text = "Update classes in settings to see details"
            if (className ?? "").contains("~") {
                let array = (className ?? "").getValues()
                className = "\(array[0]) \(array[2].replacingOccurrences(of: "N/A", with: ""))"
                text = "Press for details"
                if !(LoginVC.classMeetingDays["\(viewModel.block.lowercased())"]?[selectedDay] ?? true) {
                    className = "\(viewModel.name)"
                }
            }
            TitleLabel.text = className
            BlockLabel.text = "\(viewModel.name)"
            BottomRightLabel.isHidden = false
            BottomRightLabel.text = text
        }
        else {
            BottomRightLabel.isHidden = true
            TitleLabel.text = "\(viewModel.name)"
            if isLunch {
                BlockLabel.isHidden = false
                BlockLabel.text = "Press for Current Menu"
            }
            else {
                if viewModel.name.lowercased().contains("advisory") {
                    TitleLabel.text = "\(viewModel.name) \(LoginVC.blocks["room-advisory"] ?? "")"
                }
                BlockLabel.isHidden = true
            }
        }
        RightLabel.text = "\(viewModel.startTime) \u{2192} \(viewModel.endTime)"
    }
}

