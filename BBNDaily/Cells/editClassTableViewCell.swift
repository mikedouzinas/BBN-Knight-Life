//
//  editClassTableViewCell.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit

class editClassTableViewCell: coverTableViewCell {
    public var link: ClassesOptionsPopupVC!
    var classModel: ClassModel!
    var indexPath: IndexPath!
    override func layoutSubviews() {
        superLayoutSubviews()
        constraint = TitleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10)
        constraint.isActive = true
        rightLabelWidthConstraint.isActive = false
        backViewLeftConstraint.isActive = false
        
        backView.leftAnchor.constraint(equalTo: lineView.rightAnchor, constant: 5).isActive = true
        backView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -5).isActive = true
        backView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5).isActive = true
        backView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5).isActive = true
        
        lineView.widthAnchor.constraint(equalToConstant: 0.5).isActive = true
        lineView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10).isActive = true
        lineView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10).isActive = true
        lineView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: contentView.frame.width/5).isActive = true
        
        TitleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        TitleLabel.rightAnchor.constraint(equalTo: lineView.leftAnchor, constant: -5).isActive = true
        
        BlockLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 10).isActive = true
        BlockLabel.rightAnchor.constraint(equalTo: lineView.leftAnchor, constant: -5).isActive = true
        BlockLabel.leftAnchor.constraint(equalTo: TitleLabel.leftAnchor).isActive = true
        
        editButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10).isActive = true
        editButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10).isActive = true
        editButton.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
        editButton.widthAnchor.constraint(equalTo: editButton.heightAnchor).isActive = true
        
        RightLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10).isActive = true
        RightLabel.leftAnchor.constraint(equalTo: lineView.rightAnchor, constant: 10).isActive = true
        RightLabel.rightAnchor.constraint(equalTo: editButton.leftAnchor, constant: -5).isActive = true
        
        BottomRightLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 10).isActive = true
        BottomRightLabel.leftAnchor.constraint(equalTo: lineView.rightAnchor, constant: 10).isActive = true
        BottomRightLabel.rightAnchor.constraint(equalTo: editButton.leftAnchor, constant: -5).isActive = true
    }
    public let editButton: UIButton = {
        let editButton = UIButton()
        editButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.isSkeletonable = true
        editButton.layer.cornerRadius = 6
        editButton.layer.masksToBounds = true
        editButton.setTitle("", for: .normal)
        editButton.setImage(UIImage(systemName: "square.and.pencil"), for: .normal)
        editButton.addTarget(self, action: #selector(editCell), for: .touchUpInside)
        editButton.tintColor = UIColor(named: "inverse")
        return editButton
    } ()
    @objc func editCell () {
//        print("pressed edit local")
        link.editCell(viewModel: classModel, indexPath: indexPath)
    }
    func configure(with viewModel: ClassModel, indexPath: IndexPath) {
        super.configure(with: viewModel)
        self.classModel = viewModel
        self.indexPath = indexPath
    }
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(editButton)
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
}
