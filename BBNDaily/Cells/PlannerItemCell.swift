//
//  PlannerItemCell.swift
//  BBNDaily
//
//  HQ-2181. One row of the Tasks tab's "Upcoming" list: a planner item with a checkbox, its
//  title, and a line saying when it is due and what kind it is. Laid out like TaskCell so the two
//  sections of the list read as one screen. Constraints are made once in init, not in
//  layoutSubviews, which would add a fresh set on every layout pass.
//

import UIKit

final class PlannerItemCell: UITableViewCell {
    static let identifier = "PlannerItemCell"

    private let backView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        view.backgroundColor = UIColor(named: "current-cell")?.withAlphaComponent(0.1)
        return view
    }()
    // The kind's color (HQ-2182): a stripe down the left edge, and its symbol at the right. Both,
    // and the kind's word in the subtitle, so color is never the only thing telling kinds apart.
    private let kindStripe: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    // HQ-2186: a big deadline carries a flag next to its title, in addition to the words "Big" in the
    // subtitle, so it reads at a glance and is not told apart by color alone.
    private let bigFlag: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "flag.fill"))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.tintColor = UIColor(named: "inverse")
        view.isHidden = true
        return view
    }()
    private let kindSymbol: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        return view
    }()
    private let checkBox: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "incomplete"), for: .normal)
        button.tintColor = UIColor(named: "inverse")
        return button
    }()
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.textColor = UIColor(named: "inverse")
        label.numberOfLines = 2
        return label
    }()
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(named: "inverse")
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
    }()

    // The fold arrow on a test that has steps: points down while its steps show, right when they are folded.
    private let chevron: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = UIColor(named: "inverse")
        return button
    }()

    var onCheckBoxTapped: (() -> Void)?
    var onToggleSteps: (() -> Void)?
    /// The card's edges. Moved in on both sides to show a step as a narrower card under its parent
    /// (HQ-2187); everything inside the card is anchored to the card, so it moves with it.
    private var backLeading: NSLayoutConstraint!
    private var backTrailing: NSLayoutConstraint!
    private var chevronWidth: NSLayoutConstraint!
    private var checkBoxWidth: NSLayoutConstraint!
    private static let stepIndent: CGFloat = 20

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = UIColor(named: "background")
        contentView.backgroundColor = UIColor(named: "background")
        contentView.addSubview(backView)
        // Inside backView, not beside it: the card clips its corners, so the stripe follows them
        // instead of sticking out past the rounded edge as a square strip.
        backView.addSubview(kindStripe)
        contentView.addSubview(kindSymbol)
        contentView.addSubview(bigFlag)
        contentView.addSubview(checkBox)
        contentView.addSubview(chevron)
        chevron.addTarget(self, action: #selector(chevronTapped), for: .touchUpInside)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        checkBox.addTarget(self, action: #selector(checkBoxTapped), for: .touchUpInside)

        backLeading = backView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 5)
        backTrailing = backView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -5)
        chevronWidth = chevron.widthAnchor.constraint(equalToConstant: 0)
        checkBoxWidth = checkBox.widthAnchor.constraint(equalToConstant: 30)
        NSLayoutConstraint.activate([
            backLeading,
            backTrailing,
            backView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            backView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            kindStripe.leftAnchor.constraint(equalTo: backView.leftAnchor),
            kindStripe.topAnchor.constraint(equalTo: backView.topAnchor),
            kindStripe.bottomAnchor.constraint(equalTo: backView.bottomAnchor),
            kindStripe.widthAnchor.constraint(equalToConstant: 6),

            kindSymbol.rightAnchor.constraint(equalTo: backView.rightAnchor, constant: -15),
            kindSymbol.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            kindSymbol.widthAnchor.constraint(equalToConstant: 24),
            kindSymbol.heightAnchor.constraint(equalToConstant: 24),

            checkBox.leftAnchor.constraint(equalTo: backView.leftAnchor, constant: 15),
            checkBox.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkBox.heightAnchor.constraint(equalToConstant: 30),
            checkBoxWidth,

            titleLabel.leftAnchor.constraint(equalTo: checkBox.rightAnchor, constant: 10),
            bigFlag.rightAnchor.constraint(equalTo: kindSymbol.leftAnchor, constant: -10),
            bigFlag.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            bigFlag.widthAnchor.constraint(equalToConstant: 14),
            bigFlag.heightAnchor.constraint(equalToConstant: 14),
            chevron.rightAnchor.constraint(equalTo: bigFlag.leftAnchor, constant: -2),
            chevron.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevron.heightAnchor.constraint(equalToConstant: 36),
            chevronWidth,
            titleLabel.rightAnchor.constraint(equalTo: chevron.leftAnchor, constant: -4),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 2),

            subtitleLabel.leftAnchor.constraint(equalTo: titleLabel.leftAnchor),
            subtitleLabel.rightAnchor.constraint(equalTo: titleLabel.rightAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 4),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func checkBoxTapped() { onCheckBoxTapped?() }
    @objc private func chevronTapped() { onToggleSteps?() }

    /// `checkable` false hides the checkbox, for a list where a row can only be looked at and tapped
    /// (the Schedule tab and the week view): a box that does nothing is clutter.
    func configure(with item: PlannerItem, today: String, depth: Int = 0, progress: String? = nil, expanded: Bool? = nil,
                   checkable: Bool = true) {
        checkBox.isHidden = !checkable
        checkBoxWidth.constant = checkable ? 30 : 0
        backLeading.constant = 5 + CGFloat(depth) * PlannerItemCell.stepIndent
        backTrailing.constant = -(5 + CGFloat(depth) * PlannerItemCell.stepIndent)
        chevronWidth.constant = expanded == nil ? 0 : 36
        chevron.isHidden = expanded == nil
        chevron.setImage(UIImage(systemName: expanded == false ? "chevron.right" : "chevron.down"), for: .normal)
        chevron.accessibilityLabel = expanded == false ? "Show steps" : "Hide steps"
        // Checked items fade and strike through rather than disappearing: still there to reopen.
        let attributes: [NSAttributedString.Key: Any] = item.completed
            ? [.strikethroughStyle: NSUnderlineStyle.single.rawValue] : [:]
        titleLabel.attributedText = NSAttributedString(string: item.title, attributes: attributes)
        // A parent carries its steps' progress on the same line ("... · 2 of 4 steps done").
        subtitleLabel.text = [PlannerListing.subtitle(for: item, today: today), progress].compactMap { $0 }.joined(separator: " · ")
        kindStripe.backgroundColor = item.kind.color
        kindSymbol.image = item.kind.symbol
        kindSymbol.tintColor = item.kind.color
        kindSymbol.accessibilityLabel = item.kind.label
        bigFlag.isHidden = !item.isBig
        bigFlag.accessibilityLabel = "Big deadline"
        checkBox.setImage(UIImage(named: item.completed ? "complete" : "incomplete"), for: .normal)
        checkBox.accessibilityLabel = item.completed ? "Mark not done" : "Mark done"
        contentView.alpha = item.completed ? 0.4 : 1.0
    }
}

/// A test or homework inside its class's block row on the Schedule tab: one small tag (kind symbol,
/// title, big flag) with no checkbox, since ticking things off is the Tasks tab's job. Tapping it
/// hands back the item so the screen can open it.
final class PlannerTagButton: UIButton {
    static let height: CGFloat = 30
    static let spacing: CGFloat = 6

    let item: PlannerItem
    var onTap: ((PlannerItem) -> Void)?

    init(item: PlannerItem) {
        self.item = item
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 9
        backgroundColor = item.kind.color.withAlphaComponent(0.14)

        let symbol = UIImageView(image: item.kind.symbol)
        symbol.tintColor = item.kind.color
        symbol.contentMode = .scaleAspectFit
        symbol.translatesAutoresizingMaskIntoConstraints = false
        symbol.isUserInteractionEnabled = false
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = UIColor(named: "inverse")
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.attributedText = NSAttributedString(string: item.title,
                                                  attributes: item.completed ? [.strikethroughStyle: NSUnderlineStyle.single.rawValue] : [:])
        let flag = UIImageView(image: UIImage(systemName: "flag.fill"))
        flag.tintColor = UIColor(named: "inverse")
        flag.contentMode = .scaleAspectFit
        flag.translatesAutoresizingMaskIntoConstraints = false
        flag.isUserInteractionEnabled = false
        flag.isHidden = !item.isBig
        addSubview(symbol)
        addSubview(label)
        addSubview(flag)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: PlannerTagButton.height),
            symbol.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            symbol.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbol.widthAnchor.constraint(equalToConstant: 14),
            symbol.heightAnchor.constraint(equalToConstant: 14),
            flag.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            flag.centerYAnchor.constraint(equalTo: centerYAnchor),
            flag.widthAnchor.constraint(equalToConstant: 11),
            flag.heightAnchor.constraint(equalToConstant: 11),
            label.leadingAnchor.constraint(equalTo: symbol.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: flag.leadingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        alpha = item.completed ? 0.45 : 1
        accessibilityLabel = "\(item.isBig ? "Big " : "")\(item.kind.label): \(item.title)"
        accessibilityHint = "Opens it"
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() { onTap?(item) }
}
