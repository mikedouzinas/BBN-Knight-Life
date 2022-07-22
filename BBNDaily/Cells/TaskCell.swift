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
//    public let checkBox: UIImageView = {
//        let img = UIImageView()
//        img.image = UIImage(named: "incomplete")
//        img.translatesAutoresizingMaskIntoConstraints = false
//        img.isSkeletonable = true
//        img.skeletonCornerRadius = 8
//        img.tintColor = UIColor(named: "inverse")
//        return img
//    } ()
    public var isComplete = false
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(backView)
//        contentView.addSubview(checkBox)
        contentView.addSubview(TitleLabel)
        contentView.addSubview(DescriptionLabel)
        contentView.addSubview(DateLabel)
        contentView.backgroundColor = UIColor(named: "background")
        
        isSkeletonable = true
        contentView.isSkeletonable = true
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    var constraint = NSLayoutConstraint()
    override func layoutSubviews() {
        super.layoutSubviews()
        
        backView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 5).isActive = true
        backView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -5).isActive = true
        backView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5).isActive = true
        backView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5).isActive = true
        
        TitleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 20).isActive = true
//        checkBox.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 20).isActive = true
//        checkBox.rightAnchor.constraint(equalTo: TitleLabel.leftAnchor, constant: -10).isActive = true
//        checkBox.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
//        checkBox.heightAnchor.constraint(equalToConstant: 30).isActive = true
//        checkBox.widthAnchor.constraint(equalTo: checkBox.heightAnchor).isActive = true
        
        TitleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10).isActive = true
        TitleLabel.centerXAnchor.constraint(equalTo: DescriptionLabel.centerXAnchor).isActive = true
        TitleLabel.bottomAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10).isActive = true
        TitleLabel.rightAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true

        DescriptionLabel.topAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10).isActive = true
        DescriptionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10).isActive = true
        DescriptionLabel.leftAnchor.constraint(equalTo: TitleLabel.leftAnchor).isActive = true
        DescriptionLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -20).isActive = true
        
        DateLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -20).isActive = true
        DateLabel.centerYAnchor.constraint(equalTo: TitleLabel.centerYAnchor).isActive = true
        DateLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 160).isActive = true
        DateLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        DateLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true
        DateLabel.leftAnchor.constraint(greaterThanOrEqualTo: contentView.centerXAnchor, constant: 5).isActive = true

    }
    override func prepareForReuse(){
        super.prepareForReuse()
    }
    func configure (with viewModel: SchoolTask){
        TitleLabel.text = "\(viewModel.title)"
        DateLabel.text = "\(viewModel.dueDate.stringDateFromMultipleFormats(preferredFormat: 6) ?? "")"
        DescriptionLabel.text = viewModel.description
    }
}
