//
//  TaskCell.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit

class TaskCell: UITableViewCell {
    static let identifier = "TaskCell"
    
    private let TitleLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.textColor = UIColor(named: "inverse")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.minimumScaleFactor = 0.5
        label.adjustsFontSizeToFitWidth = true
        label.text = "ndiewniedneddeewjd"
        label.textAlignment = .left
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    private let DescriptionLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(named: "inverse")
        label.minimumScaleFactor = 0.8
        label.adjustsFontSizeToFitWidth = true
        label.textAlignment = .left
        label.text = "ndiewniedneddeewjd"
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    private let DateLabel: PaddingLabel = {
        let label = PaddingLabel()
        label.textColor = UIColor(named: "inverse")
        label.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.layer.masksToBounds = true
        label.layer.cornerRadius = 8
        label.padding(2, 2, 8, 8)
//        let spacing: CGFloat = 8.0
//        label.paddingLeft = spacing
//        label.paddingRight = spacing
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.isSkeletonable = true
        label.numberOfLines = 2
        return label
    } ()
    public let backView: UIView = {
        let backview = UIView()
        backview.translatesAutoresizingMaskIntoConstraints = false
        backview.isSkeletonable = true
        backview.layer.cornerRadius = 16
        backview.layer.masksToBounds = true
        backview.skeletonCornerRadius = 16
        backview.backgroundColor = UIColor(named: "current-cell")?.withAlphaComponent(0.1)
        return backview
    } ()
    public let checkBox: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "incomplete"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isSkeletonable = true
        button.skeletonCornerRadius = 8
        button.tintColor = UIColor(named: "inverse")
        return button
    } ()
    public var isComplete = false
    public var onCheckBoxTapped: (() -> Void)?
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(backView)
        contentView.addSubview(checkBox)
        contentView.addSubview(TitleLabel)
        contentView.addSubview(DescriptionLabel)
        contentView.addSubview(DateLabel)
        contentView.addSubview(badgeStack)
        contentView.addSubview(homeworkStack)
        installConstraints()
        contentView.backgroundColor = UIColor(named: "background")
        checkBox.addTarget(self, action: #selector(checkBoxTapped), for: .touchUpInside)

        isSkeletonable = true
        contentView.isSkeletonable = true
    }
    @objc private func checkBoxTapped() {
        onCheckBoxTapped?()
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    // HQ-2194: tests and homework attached to this class, drawn along the bottom of the row.
    private let badgeStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isHidden = true
        return stack
    } ()
    // Each of the class's homework as its own line: a checkbox and the blue block.
    private let homeworkStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = TomorrowClassItems.lineGap
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isHidden = true
        return stack
    } ()
    // The description runs to the bottom of the row, or stops above the badges when there are any.
    private var descriptionToBottom: NSLayoutConstraint!
    private var descriptionToBadges: NSLayoutConstraint!

    /// A row with badges needs the room for them. WorkVC asks for this height instead of its usual one.
    static let heightWithBadges: CGFloat = 132

    // These used to be (re)built inside layoutSubviews, which adds another copy of every constraint on
    // every layout pass. They are installed once, here, so the badges can swap one of them cleanly.
    private func installConstraints() {
        descriptionToBottom = DescriptionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        descriptionToBadges = DescriptionLabel.bottomAnchor.constraint(equalTo: badgeStack.topAnchor, constant: -4)
        NSLayoutConstraint.activate([
            backView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 5),
            backView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -5),
            backView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            backView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),

            checkBox.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 20),
            checkBox.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkBox.heightAnchor.constraint(equalToConstant: 30),
            checkBox.widthAnchor.constraint(equalTo: checkBox.heightAnchor),

            TitleLabel.leftAnchor.constraint(equalTo: checkBox.rightAnchor, constant: 10),
            TitleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            TitleLabel.centerXAnchor.constraint(equalTo: DescriptionLabel.centerXAnchor),
            TitleLabel.bottomAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            TitleLabel.rightAnchor.constraint(equalTo: contentView.centerXAnchor),

            DescriptionLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            DescriptionLabel.leftAnchor.constraint(equalTo: TitleLabel.leftAnchor),
            DescriptionLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -20),
            descriptionToBottom,

            DateLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -20),
            DateLabel.centerYAnchor.constraint(equalTo: TitleLabel.centerYAnchor),
            DateLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 160),
            DateLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            DateLabel.heightAnchor.constraint(equalToConstant: 20),
            DateLabel.leftAnchor.constraint(greaterThanOrEqualTo: contentView.centerXAnchor, constant: 5),

            badgeStack.leftAnchor.constraint(equalTo: TitleLabel.leftAnchor),
            badgeStack.rightAnchor.constraint(lessThanOrEqualTo: contentView.rightAnchor, constant: -20),
            badgeStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            badgeStack.heightAnchor.constraint(equalToConstant: 28),

            homeworkStack.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 20),
            homeworkStack.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -20),
            homeworkStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: TomorrowClassItems.headerHeight),
        ])
    }

    override func prepareForReuse(){
        super.prepareForReuse()
        setBadges([], onTap: { _ in })
        setHomework([], tests: [], onTap: { _ in }, onToggle: { _ in })
        onAddTapped = nil
    }

    /// The class card's column: one line per homework (checkbox + blue block), then the + under the checkboxes,
    /// then the tests as blocks. Every line is `lineHeight` tall with `lineGap` between, so they cannot overlap.
    private func setHomework(_ items: [PlannerItem], tests: [PlannerItem], onTap: @escaping (PlannerItem) -> Void,
                             onToggle: @escaping (PlannerItem) -> Void) {
        homeworkStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let height = TomorrowClassItems.lineHeight
        func line(_ views: [UIView]) -> UIStackView {
            let spacer = UIView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            let line = UIStackView(arrangedSubviews: views + [spacer])
            line.axis = .horizontal
            line.alignment = .fill
            line.spacing = 10
            line.heightAnchor.constraint(equalToConstant: height).isActive = true
            return line
        }
        for item in items {
            let box = ItemCheckButton(item: item)
            box.onToggle = onToggle
            let badge = PlannerBadgeButton(item: item)
            badge.onTap = onTap
            homeworkStack.addArrangedSubview(line([box, badge]))
        }
        guard !items.isEmpty else { homeworkStack.isHidden = true; return }
        let plus = UIButton(type: .system)
        plus.setImage(UIImage(systemName: "plus.circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)), for: .normal)
        plus.tintColor = UIColor(named: "inverse")
        plus.accessibilityLabel = "Add another"
        plus.widthAnchor.constraint(equalToConstant: height).isActive = true
        plus.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        homeworkStack.addArrangedSubview(line([plus]))
        if !tests.isEmpty {
            let blocks = UIStackView()
            blocks.axis = .horizontal
            blocks.spacing = 6
            blocks.alignment = .fill
            PlannerBadgeButton.fill(blocks, with: tests, onTap: onTap)
            // Starts where the blue blocks above start: past the checkbox column and its gap.
            let indent = UIView()
            indent.widthAnchor.constraint(equalToConstant: height).isActive = true
            homeworkStack.addArrangedSubview(line([indent, blocks]))
        }
        homeworkStack.isHidden = false
    }

    /// A small + after the blue blocks: add another to this class. Only drawn once something has been added;
    /// before that, tapping the row is how the first one is added.
    var onAddTapped: (() -> Void)?
    @objc private func addTapped() { onAddTapped?() }

    private func setBadges(_ items: [PlannerItem], onTap: @escaping (PlannerItem) -> Void) {
        PlannerBadgeButton.fill(badgeStack, with: items, onTap: onTap)
        if !items.isEmpty {
            let plus = UIButton(type: .system)
            plus.setImage(UIImage(systemName: "plus.circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)), for: .normal)
            plus.tintColor = UIColor(named: "inverse")
            plus.accessibilityLabel = "Add another"
            plus.widthAnchor.constraint(equalToConstant: 30).isActive = true
            plus.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
            badgeStack.addArrangedSubview(plus)
        }
        badgeStack.isHidden = items.isEmpty
        descriptionToBottom.isActive = items.isEmpty
        descriptionToBadges.isActive = !items.isEmpty
    }
    func configure (with viewModel: SchoolTask){
        TitleLabel.text = "\(viewModel.title)"
        DateLabel.text = "\(viewModel.dueDate.stringDateFromMultipleFormats(preferredFormat: 6) ?? "")"
        DescriptionLabel.text = viewModel.description
    }

    // HQ-779: checked homework fades rather than disappearing - still there to reopen and
    // edit, just visually out of the way once it's done.
    // HQ-2194 / HQ-2632: `items` are this class's planner items for the day shown (split by
    // TomorrowClassItems): each homework is a line of its own with its own checkbox, tests are blocks along the
    // bottom, and a + after them adds another. With none of either, the row shows the old placeholder and
    // checkbox, and tapping the row adds the first.
    func configure(with entry: HomeworkEntry, items: TomorrowClassItems = TomorrowClassItems(homework: [], tests: []),
                   onItemTapped: @escaping (PlannerItem) -> Void = { _ in },
                   onHomeworkToggled: @escaping (PlannerItem) -> Void = { _ in }) {
        let hasLines = !items.homework.isEmpty
        setHomework(items.homework, tests: items.tests, onTap: onItemTapped, onToggle: onHomeworkToggled)
        // With homework lines the tests are part of that column; otherwise they are the row's bottom blocks.
        setBadges(hasLines ? [] : items.tests, onTap: onItemTapped)
        isComplete = entry.completed
        TitleLabel.text = entry.subject
        DateLabel.text = "Block \(entry.block)"
        if hasLines {
            DescriptionLabel.text = ""
        } else if !entry.holdsHomework {
            // Never "Tap to add homework" here - tapping this row does nothing, since
            // WorkVC only opens the entry prompt when holdsHomework is true.
            DescriptionLabel.text = "No homework for this class"
        } else {
            DescriptionLabel.text = entry.text.isEmpty ? "Tap to add homework or a test" : entry.text
        }
        // The class's own checkbox is for the old-style note; with homework lines each line has its own.
        checkBox.isHidden = hasLines
        checkBox.setImage(UIImage(named: entry.completed ? "complete" : "incomplete"), for: .normal)
        // Fade the row's own parts, not the whole contentView: the blocks are separate items with
        // their own done state, and a test is not finished because the class's homework is.
        contentView.alpha = 1
        let rowAlpha: CGFloat = entry.completed && !hasLines ? 0.4 : 1.0
        [backView, checkBox, TitleLabel, DescriptionLabel, DateLabel].forEach { $0.alpha = rowAlpha }
    }
}

/// The checkbox on one homework line: ticked when that item is done, and hands the item back when tapped.
final class ItemCheckButton: UIButton {
    let item: PlannerItem
    var onToggle: ((PlannerItem) -> Void)?

    init(item: PlannerItem) {
        self.item = item
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setImage(UIImage(named: item.completed ? "complete" : "incomplete"), for: .normal)
        tintColor = UIColor(named: "inverse")
        widthAnchor.constraint(equalToConstant: TomorrowClassItems.lineHeight).isActive = true
        heightAnchor.constraint(equalToConstant: TomorrowClassItems.lineHeight).isActive = true
        accessibilityLabel = item.completed ? "Mark \(item.title) not done" : "Mark \(item.title) done"
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func tapped() { onToggle?(item) }
}
