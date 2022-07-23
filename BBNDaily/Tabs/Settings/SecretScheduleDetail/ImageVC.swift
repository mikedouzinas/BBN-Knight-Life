//
//  ImageVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/23/22.
//

import Foundation
import UIKit
import Firebase
import ProgressHUD

class ImageVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @IBOutlet var imageButton: UIButton!
    @IBOutlet var tempImageView: UIImageView!
    @IBOutlet var finishButton: UIButton!
    var link: SecretScheduleVC!
    @IBAction func pressedFinish() {
        guard let image = tempImageView.image else {
            ProgressHUD.colorAnimation = .red
            ProgressHUD.showFailed("You need to select an image!")
            return
        }
        let currDate = link.currentDate.replacingOccurrences(of: "/", with: "-")
        link.currentDay.image = image
        guard let imageData = image.pngData() else {
            return
        }
        finishButton.isEnabled = false
        let storageRef = Storage.storage().reference()
        storageRef.child("schedules/\(currDate).png").putData(imageData, metadata: nil, completion: { _, error in
            guard error == nil else {
                print("failed to upload \(String(describing: error))")
                ProgressHUD.showFailed("Failed to upload photo :(")
                return
            }
            DispatchQueue.main.async { [self] in
                let storage = FirebaseStorage.Storage.storage()
                let reference = storage.reference(withPath: "schedules/\(currDate).png")
                reference.downloadURL(completion: { [self] (url, error) in
                    if let error = error {
                        print(error)
                    }
                    else {
                        let urlstring = url!.absoluteString
                        guard let url = URL(string: urlstring) else {
                            return
                        }
                        DispatchQueue.main.async {[self] in
                            imageCache.setObject(image, forKey: NSString(string: urlstring))
                            dismiss(animated: true)
                            link.currentDay.imageUrl = "\(url)"
                            link.uploadData()
                        }
                    }
                })
            }
        })
        
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        tempImageView.image = link.currentDay.image
    }
    @IBAction func choosePhoto() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    @IBAction func takePhoto() {
        // fyi i could use the same method with a received button but im lazy
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    @IBAction func cancel () {
        dismiss(animated: true)
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage else {
            return
        }
        tempImageView.image = image
    }
}

