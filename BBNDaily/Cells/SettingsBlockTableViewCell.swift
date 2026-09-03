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
                // The SUBJECT only.
                //
                // This used to be "\(subject) \(teacher)", so the block list read "AP English
                // Masks Ms. Lieberman" - the teacher's name appended to every row, on a screen
                // whose job is to tell a student which class each letter is. Mike: "all of the
                // teachers are appearing in the name during blocks, which seems weird... I
                // shouldn't see the teacher name."
                //
                // It also removes the "Free N/A" case at the source. A free block's key is
                // `Free~~~F`, or `Free~N/A~N/A~G` for one written by an older build, and
                // `getValues()` turns an empty field into the literal "N/A" for display. The old
                // line stripped "N/A" out of the teacher slot and left the space it was joined
                // with, so a free block rendered as "Free" with a trailing space in one place and
                // "Free N/A" wherever the strip did not apply. Dropping the teacher slot entirely
                // means there is no N/A to strip.
                className = className.getValues()[0]
            }
            DataLabel.text = className
        }
        else if let badge = viewModel.badge {
            DataLabel.text = badge
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
