//
//  coverTableViewCell.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit

class coverTableViewCell: calendarTableViewCell {
    override func layoutSubviews() {
        superLayoutSubviews()
        constraint = TitleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10)
        constraint.isActive = true
        rightLabelWidthConstraint.isActive = false
        backViewLeftConstraint.isActive = false
        
        backView.leftAnchor.constraint(equalTo: lineView.rightAnchor, constant: 5).isActive = true
        backView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -5).isActive = true
        backView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5).isActive = true
        backView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5).isActive = true
        
        lineView.widthAnchor.constraint(equalToConstant: 0.5).isActive = true
        lineView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10).isActive = true
        lineView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10).isActive = true
        lineView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: contentView.frame.width/5).isActive = true
        
        TitleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        TitleLabel.rightAnchor.constraint(equalTo: lineView.leftAnchor, constant: -5).isActive = true
        
        BlockLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 10).isActive = true
        BlockLabel.rightAnchor.constraint(equalTo: lineView.leftAnchor, constant: -5).isActive = true
        BlockLabel.leftAnchor.constraint(equalTo: TitleLabel.leftAnchor).isActive = true
        
        RightLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10).isActive = true
        RightLabel.leftAnchor.constraint(equalTo: lineView.rightAnchor, constant: 10).isActive = true
        
        BottomRightLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 10).isActive = true
        BottomRightLabel.leftAnchor.constraint(equalTo: lineView.rightAnchor, constant: 10).isActive = true
    }
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(lineView)
        TitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        TitleLabel.textAlignment = .right
        BlockLabel.font = .systemFont(ofSize: 13, weight: .regular)
        BlockLabel.textAlignment = .right
        RightLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        RightLabel.textColor = UIColor(named: "inverse")
        RightLabel.textAlignment = .left

        // Long course names have to shrink and then truncate, never wrap.
        //
        // These two labels are stacked in a fixed-height row: RightLabel sits 10pt above
        // centre and BottomRightLabel 10pt below it. Neither had a line policy, so a name
        // longer than the column spilled onto a second line and ran straight through the row
        // underneath - which is why "210" (a room number, the tail of BottomRightLabel's
        // "name | room") appeared to be its own list item in B block.
        //
        // Not a rare case: real BB&N course names reach 57 characters, and five of them are
        // over 44. Shrink first so most names stay fully readable, then tail-truncate, so the
        // failure is an ellipsis rather than two rows of overlapping text.
        for label in [RightLabel, BottomRightLabel] {
            label.numberOfLines = 1
            label.lineBreakMode = .byTruncatingTail
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.75
        }
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    public let lineView: UIView = {
        let backview = UIView()
        backview.translatesAutoresizingMaskIntoConstraints = false
        backview.isSkeletonable = true
        backview.layer.cornerRadius = 6
        backview.layer.masksToBounds = true
        backview.backgroundColor = UIColor(named: "lightGray")
        return backview
    } ()
    
    // if viewmodel.block != N/A {
    //var className = LoginVC.blocks[viewModel.block] as? String
    //if className == "" {
    //    className = "[\(viewModel.block) Block]"
//    }
//    var text = "Update classes in settings to see details"
//    if (className ?? "").contains("~") {
//        let array = (className ?? "").getValues()
//        className = "\(array[0]) \(array[2].replacingOccurrences(of: "N/A", with: ""))"
//        text = "Press for details"
//        if !(LoginVC.classMeetingDays["\(viewModel.block.lowercased())"]?[selectedDay] ?? true) {
//            className = "\(viewModel.name)"
//        }
//    }
    // }
    // else {
    //     title.text = "\(viewModel.name)"
    // }
    override func configure(with viewModel: block, isLunch: Bool, selectedDay: Int) {
        RightLabel.isHidden = false
        BlockLabel.isHidden = false
        if viewModel.block != "N/A" {
            var className = LoginVC.blocks[viewModel.block] as? String
            if className == "" {
                className = "[\(viewModel.block) Block]"
            }
            var text = "Update class in settings."
            if (className ?? "").contains("~") {
                let array = (className ?? "").getValues()
                className = "\(array[0]) \(array[2].replacingOccurrences(of: "N/A", with: ""))"
                text = "Press for details"
                if !(LoginVC.classMeetingDays["\(viewModel.block.lowercased())"]?[selectedDay] ?? true) {
                    className = "Free"
                }
            }
            // corrected
            RightLabel.text = "\(className ?? "")"
            // BlockLabel.text = "\(viewModel.name)"
            BottomRightLabel.isHidden = false
            BottomRightLabel.text = "\(viewModel.name) | \(text)"
        }
        else {
            // BottomRightLabel.isHidden = true
            // corrected
            RightLabel.text = "\(viewModel.name)"
            if isLunch && LoginVC.hasLunchMenu() {
                BottomRightLabel.isHidden = false
                BottomRightLabel.text = "Press for menu"
            }
            else if isLunch {
                // No menu published for this week, so do not offer one.
                BottomRightLabel.isHidden = true
            }
            else {
                if viewModel.name.lowercased().contains("advisory") {
                    RightLabel.text = "\(viewModel.name) \(LoginVC.blocks["room-advisory"] ?? "")"
                }
                BottomRightLabel.isHidden = true
            }
        }
        //        RightLabel.text = "\(viewModel.startTime) \u{2192} \(viewModel.endTime)"
        // corrected
        TitleLabel.text = "\(viewModel.startTime)"
        BlockLabel.text = "\(viewModel.endTime)"
    }
}
