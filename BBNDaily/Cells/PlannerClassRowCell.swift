//
//  PlannerClassRowCell.swift
//  BBNDaily
//
//  HQ-2194. A class on the This Week view, with a badge for each test or homework attached to it:
//  the class on the left, the badges on the right, each in its kind's color. Tapping a badge opens
//  that item. A class with nothing attached is the plain one-line row it always was.
//
//  A badge carries three things so color is never the only signal: the kind's symbol, the item's
//  title, and the color itself. A finished item's badge is faded and struck through.
//

import UIKit

final class PlannerClassRowCell: UITableViewCell {

    static let height: CGFloat = 52

    private let classLabel = UILabel()
    private let badges = UIStackView()
    var onSelectItem: ((PlannerItem) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = UIColor(named: "background")
        contentView.backgroundColor = UIColor(named: "background")

        classLabel.translatesAutoresizingMaskIntoConstraints = false
        classLabel.font = .systemFont(ofSize: 14)
        classLabel.textColor = UIColor(named: "inverse")
        classLabel.numberOfLines = 2
        classLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        classLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        badges.translatesAutoresizingMaskIntoConstraints = false
        badges.axis = .horizontal
        badges.spacing = 6
        badges.alignment = .center
        badges.setContentHuggingPriority(.required, for: .horizontal)
        badges.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        contentView.addSubview(classLabel)
        contentView.addSubview(badges)
        NSLayoutConstraint.activate([
            classLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 20),
            classLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            badges.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -12),
            badges.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            badges.leftAnchor.constraint(greaterThanOrEqualTo: classLabel.rightAnchor, constant: 8),
            // A class with badges must not be squeezed by them: the label keeps at least 45% of the row.
            classLabel.widthAnchor.constraint(greaterThanOrEqualTo: contentView.widthAnchor, multiplier: 0.45),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        badges.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }

    func configure(block: String, subject: String, items: [PlannerItem]) {
        classLabel.text = "\(block) · \(subject)"
        PlannerBadgeButton.fill(badges, with: items) { [weak self] item in self?.onSelectItem?(item) }
    }
}
