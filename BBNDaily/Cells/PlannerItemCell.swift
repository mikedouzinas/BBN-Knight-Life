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
        contentView.addSubview(checkBox)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        checkBox.addTarget(self, action: #selector(checkBoxTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            backView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 5),
            backView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -5),
            backView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            backView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            checkBox.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 20),
            checkBox.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkBox.heightAnchor.constraint(equalToConstant: 30),
            checkBox.widthAnchor.constraint(equalTo: checkBox.heightAnchor),

            titleLabel.leftAnchor.constraint(equalTo: checkBox.rightAnchor, constant: 10),
            titleLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -20),
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
        checkBox.setImage(UIImage(named: item.completed ? "complete" : "incomplete"), for: .normal)
        checkBox.accessibilityLabel = item.completed ? "Mark not done" : "Mark done"
        contentView.alpha = item.completed ? 0.4 : 1.0
    }
}
