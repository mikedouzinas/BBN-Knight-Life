//
//  PlannerWeekDataSource.swift
//  BBNDaily
//
//  HQ-2184. Draws a PlannerWeek into the Tasks table: one section per school day, each headed by
//  the day and how heavy it is, holding that day's classes (or why there are none) and what the
//  student has planned. It is a separate data source that the table swaps to when "This Week" is
//  chosen, so WorkVC's own tomorrow-list code is not touched or made to branch on a mode.
//

import UIKit

final class PlannerWeekDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {

    var days = [PlannerWeekDay]()
    var today = PlannerItem.dayString(from: Date())
    /// Called when a student's own item is tapped. School key dates never reach this.
    var onSelectItem: ((PlannerItem) -> Void)?

    // MARK: Sections

    func numberOfSections(in tableView: UITableView) -> Int { days.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        days.indices.contains(section) ? days[section].rows.count : 0
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 40 }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard days.indices.contains(section) else { return nil }
        let day = days[section]

        let container = UIView()
        container.backgroundColor = UIColor(named: "background")
        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = PlannerWeek.dayTitle(forDay: day.day, today: today)
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = UIColor(named: "inverse")
        let load = UILabel()
        load.translatesAutoresizingMaskIntoConstraints = false
        load.text = day.heavyLabel
        load.font = .systemFont(ofSize: 12, weight: .bold)
        load.textColor = UIColor(named: "inverse")
        load.textAlignment = .right
        load.setContentCompressionResistancePriority(.required, for: .horizontal)
        container.addSubview(title)
        container.addSubview(load)
        NSLayoutConstraint.activate([
            title.leftAnchor.constraint(equalTo: container.leftAnchor, constant: 16),
            title.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            load.rightAnchor.constraint(equalTo: container.rightAnchor, constant: -16),
            load.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            title.rightAnchor.constraint(lessThanOrEqualTo: load.leftAnchor, constant: -8),
        ])
        container.isAccessibilityElement = true
        container.accessibilityLabel = [title.text, day.heavyLabel].compactMap { $0 }.joined(separator: ", ")
        return container
    }

    // "Nothing planned" says so, rather than leaving a day looking unfinished.
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        days.indices.contains(section) && days[section].hasNothingPlanned ? "Nothing planned" : nil
    }

    // MARK: Rows

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard days.indices.contains(indexPath.section), days[indexPath.section].rows.indices.contains(indexPath.row) else { return 44 }
        if case .item = days[indexPath.section].rows[indexPath.row] { return 72 }
        return 40
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard days.indices.contains(indexPath.section), days[indexPath.section].rows.indices.contains(indexPath.row) else {
            return UITableViewCell()
        }
        switch days[indexPath.section].rows[indexPath.row] {
        case .item(let item):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: PlannerItemCell.identifier, for: indexPath) as? PlannerItemCell else {
                return UITableViewCell()
            }
            cell.configure(with: item, today: today)
            cell.onCheckBoxTapped = nil   // checking things off is the Tomorrow view's job; here a row is looked at
            return cell
        case .schoolClass(let schoolClass):
            return plainCell("\(schoolClass.block) · \(schoolClass.subject)", secondary: false)
        case .note(let message):
            return plainCell(message, secondary: true)
        }
    }

    private func plainCell(_ text: String, secondary: Bool) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        cell.backgroundColor = UIColor(named: "background")
        cell.textLabel?.text = text
        cell.textLabel?.font = .systemFont(ofSize: 14, weight: .regular)
        cell.textLabel?.textColor = UIColor(named: "inverse")
        cell.textLabel?.alpha = secondary ? 0.7 : 1.0
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard days.indices.contains(indexPath.section), days[indexPath.section].rows.indices.contains(indexPath.row),
              case .item(let item) = days[indexPath.section].rows[indexPath.row], !item.isSchoolKeyDate else { return }
        onSelectItem?(item)
    }
}
