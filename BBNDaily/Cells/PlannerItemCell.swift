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

    var onCheckBoxTapped: (() -> Void)?

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
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        checkBox.addTarget(self, action: #selector(checkBoxTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            backView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 5),
            backView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -5),
            backView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            backView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            kindStripe.leftAnchor.constraint(equalTo: backView.leftAnchor),
            kindStripe.topAnchor.constraint(equalTo: backView.topAnchor),
            kindStripe.bottomAnchor.constraint(equalTo: backView.bottomAnchor),
            kindStripe.widthAnchor.constraint(equalToConstant: 6),

            kindSymbol.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -20),
            kindSymbol.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            kindSymbol.widthAnchor.constraint(equalToConstant: 24),
            kindSymbol.heightAnchor.constraint(equalToConstant: 24),

            checkBox.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 20),
            checkBox.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkBox.heightAnchor.constraint(equalToConstant: 30),
            checkBox.widthAnchor.constraint(equalTo: checkBox.heightAnchor),

            titleLabel.leftAnchor.constraint(equalTo: checkBox.rightAnchor, constant: 10),
            bigFlag.rightAnchor.constraint(equalTo: kindSymbol.leftAnchor, constant: -10),
            bigFlag.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            bigFlag.widthAnchor.constraint(equalToConstant: 14),
            bigFlag.heightAnchor.constraint(equalToConstant: 14),
            titleLabel.rightAnchor.constraint(equalTo: bigFlag.leftAnchor, constant: -6),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 2),

            subtitleLabel.leftAnchor.constraint(equalTo: titleLabel.leftAnchor),
            subtitleLabel.rightAnchor.constraint(equalTo: titleLabel.rightAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 4),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func checkBoxTapped() { onCheckBoxTapped?() }

    func configure(with item: PlannerItem, today: String) {
        // Checked items fade and strike through rather than disappearing: still there to reopen.
        let attributes: [NSAttributedString.Key: Any] = item.completed
            ? [.strikethroughStyle: NSUnderlineStyle.single.rawValue] : [:]
        titleLabel.attributedText = NSAttributedString(string: item.title, attributes: attributes)
        subtitleLabel.text = PlannerListing.subtitle(for: item, today: today)
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
