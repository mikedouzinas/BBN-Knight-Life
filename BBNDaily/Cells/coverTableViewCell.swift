//
//  coverTableViewCell.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit

class coverTableViewCell: calendarTableViewCell {
    /// Whether the two lines of text sit a fixed distance from the top (so a taller row leaves them where
    /// they are) rather than around the row's middle. Only the Schedule's block row, which can grow to
    /// hold tags, turns this on; every other row keeps the layout it always had.
    var pinsLabelsToTop: Bool { false }
    override func layoutSubviews() {
        superLayoutSubviews()
        let pinned = pinsLabelsToTop
        // In a 60pt row these are the same two places: 10pt above and 10pt below the middle.
        func upper(_ label: UILabel) -> NSLayoutConstraint {
            pinned ? label.centerYAnchor.constraint(equalTo: contentView.topAnchor, constant: 20)
                   : label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10)
        }
        func lower(_ label: UILabel) -> NSLayoutConstraint {
            pinned ? label.centerYAnchor.constraint(equalTo: contentView.topAnchor, constant: 40)
                   : label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 10)
        }
        constraint = upper(TitleLabel)
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
        
        lower(BlockLabel).isActive = true
        BlockLabel.rightAnchor.constraint(equalTo: lineView.leftAnchor, constant: -5).isActive = true
        BlockLabel.leftAnchor.constraint(equalTo: TitleLabel.leftAnchor).isActive = true
        
        upper(RightLabel).isActive = true
        RightLabel.leftAnchor.constraint(equalTo: lineView.rightAnchor, constant: 10).isActive = true
        
        lower(BottomRightLabel).isActive = true
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

/// The Schedule tab's block row: the same row, which can grow to hold the student's tests and homework
/// for that class as small tags in its right-hand column, under "Extended D | Press for details". The
/// divider and the current-block highlight stretch over the tags because they are part of the row.
final class ScheduleBlockCell: coverTableViewCell {
    static let blockIdentifier = "ScheduleBlockCell"
    static let baseHeight: CGFloat = 60
    /// Where the first tag starts, and the room under the last one.
    private static let tagsTop: CGFloat = 54
    private static let tagsBottom: CGFloat = 10

    override var pinsLabelsToTop: Bool { true }

    private let tagStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = PlannerTagButton.spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// The row's height with `count` tags in it.
    static func height(forTagCount count: Int) -> CGFloat {
        guard count > 0 else { return baseHeight }
        return tagsTop + CGFloat(count) * PlannerTagButton.height + CGFloat(count - 1) * PlannerTagButton.spacing + tagsBottom
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(tagStack)
        NSLayoutConstraint.activate([
            tagStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: ScheduleBlockCell.tagsTop),
            tagStack.leftAnchor.constraint(equalTo: lineView.rightAnchor, constant: 10),
            tagStack.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -12),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        setTags([], onTap: { _ in })
    }

    /// Replaces the tags. Tapping one hands back its item; tapping anywhere else on the row still opens the class.
    func setTags(_ items: [PlannerItem], onTap: @escaping (PlannerItem) -> Void) {
        tagStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for item in items {
            let tag = PlannerTagButton(item: item)
            tag.onTap = onTap
            tagStack.addArrangedSubview(tag)
        }
    }
}
