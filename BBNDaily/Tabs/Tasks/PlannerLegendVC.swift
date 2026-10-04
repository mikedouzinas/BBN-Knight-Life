//
//  PlannerLegendVC.swift
//  BBNDaily
//
//  HQ-2182. What the four colors mean: the kind's symbol in its color, its name, and one line on
//  what belongs under it. Reached from the info button on Tasks.
//

import UIKit

final class PlannerLegendVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Colors"
        view.backgroundColor = UIColor(named: "background")
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))

        let rows = PlannerKind.allCases.map { legendRow(for: $0) }
        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 24),
            stack.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -24),
        ])
    }

    private func legendRow(for kind: PlannerKind) -> UIView {
        let swatch = UIView()
        swatch.backgroundColor = kind.color
        swatch.layer.cornerRadius = 3
        swatch.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            swatch.widthAnchor.constraint(equalToConstant: 6),
            swatch.heightAnchor.constraint(equalToConstant: 40),
        ])

        let symbol = UIImageView(image: kind.symbol)
        symbol.tintColor = kind.color
        symbol.contentMode = .scaleAspectFit
        symbol.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            symbol.widthAnchor.constraint(equalToConstant: 28),
            symbol.heightAnchor.constraint(equalToConstant: 28),
        ])

        let name = UILabel()
        name.text = kind.label
        name.font = .systemFont(ofSize: 17, weight: .semibold)
        name.textColor = UIColor(named: "inverse")
        let meaning = UILabel()
        meaning.text = kind.meaning
        meaning.font = .systemFont(ofSize: 14)
        meaning.textColor = UIColor(named: "inverse")
        meaning.numberOfLines = 0
        let text = UIStackView(arrangedSubviews: [name, meaning])
        text.axis = .vertical
        text.spacing = 2

        let row = UIStackView(arrangedSubviews: [swatch, symbol, text])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 14
        row.isAccessibilityElement = true
        row.accessibilityLabel = "\(kind.label): \(kind.meaning)"
        return row
    }

    @objc private func done() { dismiss(animated: true) }
}
