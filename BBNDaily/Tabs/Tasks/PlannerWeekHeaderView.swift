//
//  PlannerWeekHeaderView.swift
//  BBNDaily
//
//  HQ-2184. The top of the Tasks table: a Tomorrow | This Week switch and, in the week view, the
//  range being shown with arrows to move a week at a time.
//

import UIKit

final class PlannerWeekHeaderView: UIView {

    static let tomorrowHeight: CGFloat = 52
    static let weekHeight: CGFloat = 96

    let modeControl = UISegmentedControl(items: ["Tomorrow", "This Week"])
    private let previousButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let rangeLabel = UILabel()
    private let weekRow = UIStackView()

    var onModeChanged: ((Bool) -> Void)?      // true = week
    var onPreviousWeek: (() -> Void)?
    var onNextWeek: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(named: "background")

        modeControl.selectedSegmentIndex = 0
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        modeControl.translatesAutoresizingMaskIntoConstraints = false

        previousButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        previousButton.accessibilityLabel = "Previous week"
        previousButton.addTarget(self, action: #selector(goPrevious), for: .touchUpInside)
        nextButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        nextButton.accessibilityLabel = "Next week"
        nextButton.addTarget(self, action: #selector(goNext), for: .touchUpInside)
        rangeLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        rangeLabel.textColor = UIColor(named: "inverse")
        rangeLabel.textAlignment = .center

        weekRow.axis = .horizontal
        weekRow.distribution = .equalCentering
        weekRow.alignment = .center
        weekRow.translatesAutoresizingMaskIntoConstraints = false
        [previousButton, rangeLabel, nextButton].forEach { weekRow.addArrangedSubview($0) }
        weekRow.isHidden = true

        addSubview(modeControl)
        addSubview(weekRow)
        NSLayoutConstraint.activate([
            modeControl.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            modeControl.leftAnchor.constraint(equalTo: leftAnchor, constant: 16),
            modeControl.rightAnchor.constraint(equalTo: rightAnchor, constant: -16),
            weekRow.topAnchor.constraint(equalTo: modeControl.bottomAnchor, constant: 10),
            weekRow.leftAnchor.constraint(equalTo: leftAnchor, constant: 24),
            weekRow.rightAnchor.constraint(equalTo: rightAnchor, constant: -24),
            weekRow.heightAnchor.constraint(equalToConstant: 32),
            previousButton.widthAnchor.constraint(equalToConstant: 44),
            nextButton.widthAnchor.constraint(equalToConstant: 44),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func modeChanged() { onModeChanged?(modeControl.selectedSegmentIndex == 1) }
    @objc private func goPrevious() { onPreviousWeek?() }
    @objc private func goNext() { onNextWeek?() }

    /// Shows or hides the week row and returns the height the header now needs.
    @discardableResult
    func setWeekMode(_ week: Bool, range: String, canGoBack: Bool, canGoForward: Bool) -> CGFloat {
        weekRow.isHidden = !week
        rangeLabel.text = range
        previousButton.isEnabled = canGoBack
        nextButton.isEnabled = canGoForward
        return week ? PlannerWeekHeaderView.weekHeight : PlannerWeekHeaderView.tomorrowHeight
    }
}
