//
//  PlannerBadgeButton.swift
//  BBNDaily
//
//  HQ-2194. The small colored badge a test or homework gets on its class's row, shared by the This
//  Week view (PlannerClassRowCell) and the Tomorrow view (TaskCell) so the two are the same thing
//  and cannot drift apart. It carries the kind's symbol and the item's title as well as its color,
//  so color is never the only signal; a finished item is faded and struck through. Tapping it hands
//  back the item it was made for.
//

import UIKit

final class PlannerBadgeButton: UIButton {

    let item: PlannerItem
    var onTap: ((PlannerItem) -> Void)?

    init(item: PlannerItem) {
        self.item = item
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 8
        layer.borderWidth = 1.5
        layer.borderColor = item.kind.color.cgColor
        backgroundColor = item.kind.color.withAlphaComponent(0.18)
        clipsToBounds = true

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
        label.attributedText = NSAttributedString(string: item.title,
                                                  attributes: item.completed ? [.strikethroughStyle: NSUnderlineStyle.single.rawValue] : [:])
        let stack = UIStackView(arrangedSubviews: [symbol, label])
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            symbol.widthAnchor.constraint(equalToConstant: 14),
            symbol.heightAnchor.constraint(equalToConstant: 14),
            stack.leftAnchor.constraint(equalTo: leftAnchor, constant: 8),
            stack.rightAnchor.constraint(equalTo: rightAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: 110),
        ])
        alpha = item.completed ? 0.45 : 1
        accessibilityLabel = "\(item.kind.label): \(item.title)"
        accessibilityHint = "Opens it"
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() { onTap?(item) }

    /// Fills `stack` with badges for `items`: at most two, then a "+N" for the rest (they are still on
    /// the Upcoming list and the calendar). Used by both views so the rule is in one place.
    static func fill(_ stack: UIStackView, with items: [PlannerItem], onTap: @escaping (PlannerItem) -> Void) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let shown = items.prefix(2)
        for item in shown {
            let badge = PlannerBadgeButton(item: item)
            badge.onTap = onTap
            stack.addArrangedSubview(badge)
        }
        if items.count > shown.count {
            let more = UILabel()
            more.text = "+\(items.count - shown.count)"
            more.font = .systemFont(ofSize: 12, weight: .semibold)
            more.textColor = UIColor(named: "inverse")
            stack.addArrangedSubview(more)
        }
    }
}
