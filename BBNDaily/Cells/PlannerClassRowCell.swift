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
    private var items = [PlannerItem]()

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
        self.items = items
        classLabel.text = "\(block) · \(subject)"
        badges.arrangedSubviews.forEach { $0.removeFromSuperview() }
        // Room for two badges beside the class; any more would crush the class name. The rest are
        // not lost: the count says so, and the item is still on the Upcoming list and the calendar.
        let shown = items.prefix(2)
        for (index, item) in shown.enumerated() { badges.addArrangedSubview(badge(for: item, index: index)) }
        if items.count > shown.count {
            let more = UILabel()
            more.text = "+\(items.count - shown.count)"
            more.font = .systemFont(ofSize: 12, weight: .semibold)
            more.textColor = UIColor(named: "inverse")
            badges.addArrangedSubview(more)
        }
    }

    private func badge(for item: PlannerItem, index: Int) -> UIView {
        let button = UIButton(type: .custom)
        button.tag = index
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1.5
        button.layer.borderColor = item.kind.color.cgColor
        button.backgroundColor = item.kind.color.withAlphaComponent(0.18)
        button.clipsToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)

        let symbol = UIImageView(image: item.kind.symbol)
        symbol.tintColor = item.kind.color
        symbol.contentMode = .scaleAspectFit
        symbol.translatesAutoresizingMaskIntoConstraints = false
        symbol.isUserInteractionEnabled = false
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = UIColor(named: "inverse")
        label.lineBreakMode = .byTruncatingTail
        label.attributedText = NSAttributedString(string: item.title, attributes: item.completed ? [.strikethroughStyle: NSUnderlineStyle.single.rawValue] : [:])
        let stack = UIStackView(arrangedSubviews: [symbol, label])
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(stack)
        NSLayoutConstraint.activate([
            symbol.widthAnchor.constraint(equalToConstant: 14),
            symbol.heightAnchor.constraint(equalToConstant: 14),
            stack.leftAnchor.constraint(equalTo: button.leftAnchor, constant: 8),
            stack.rightAnchor.constraint(equalTo: button.rightAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: button.topAnchor, constant: 5),
            stack.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -5),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: 110),
        ])
        button.alpha = item.completed ? 0.45 : 1
        button.accessibilityLabel = "\(item.kind.label): \(item.title)"
        button.accessibilityHint = "Opens it"
        button.addTarget(self, action: #selector(badgeTapped(_:)), for: .touchUpInside)
        return button
    }

    @objc private func badgeTapped(_ sender: UIButton) {
        guard items.indices.contains(sender.tag) else { return }
        onSelectItem?(items[sender.tag])
    }
}
