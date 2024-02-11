//
//  ApplePayTableViewCell.swift
//  goSellSDK
//
//  Created by Osama Rabie on 07/01/2020.
//  Copyright © 2020 Tap Payments. All rights reserved.
//

import UIKit

import CoreGraphics
import class UIKit.NSLayoutConstraint.NSLayoutConstraint
import class UIKit.UIImageView.UIImageView
import class UIKit.UILabel.UILabel
import class UIKit.UIScreen.UIScreen
import class UIKit.UITableViewCell.UITableViewCell
import class UIKit.UIView.UIView
import class PassKit.PKPaymentButton
import class PassKit.PKPaymentAuthorizationViewController
import class PassKit.PKPassLibrary
import enum PassKit.PKPaymentButtonType

internal class ApplePayTableViewCell: BaseTableViewCell {
	
	// MARK: - Internal -
	// MARK: Properties
	
	internal weak var model: ApplePaymentOptionTableViewCellModel?
	
	// MARK: - Private -
	// MARK: Properties
	
	//@IBOutlet private weak var titleLabel:      UILabel?
	@IBOutlet private weak var iconImageView:   UIImageView?
	//@IBOutlet private weak var arrowImageView:  UIImageView?
}

// MARK: - LoadingWithModelCell
extension ApplePayTableViewCell: LoadingWithModelCell {
	
	internal func updateContent(animated: Bool) {
		DispatchQueue.main.async {
			self.iconImageView?.image = self.model?.iconImage
			
			// Create the Apple Pay button
			let applePayButton = PKPaymentButton(paymentButtonType: .plain, paymentButtonStyle: .whiteOutline)
			applePayButton.addTarget(self, action: #selector(self.applePayButtonClicked(_:)), for: .touchUpInside)
			
			// Set button size
			let buttonHeight: CGFloat = 30
			let buttonWidth: CGFloat = 100
			
			// Position the button on the left
			applePayButton.frame = CGRect(x: 20, y: (self.contentView.bounds.height - buttonHeight) / 2, width: buttonWidth, height: buttonHeight)
			
			// Create and configure the label for text
			let label = UILabel()
			label.text = "الــدفع عن طريق ابل باي"
			label.textAlignment = .right

			label.font = UIFont(name: "Tajawal-Bold", size: 20)
			// Position the label on the right
			let labelWidth: CGFloat = self.contentView.bounds.width - buttonWidth - 60
			label.frame = CGRect(x: 20 + buttonWidth + 20, y: (self.contentView.bounds.height - buttonHeight) / 2, width: labelWidth, height: buttonHeight)
			
			// Add the button and label to the view
			self.contentView.addSubview(applePayButton)
			self.contentView.addSubview(label)
			
			self.backgroundColor = UIColor.white
			self.isHidden = !PKPaymentAuthorizationViewController.canMakePayments()
		}
	}
	
	@objc private func applePayButtonClicked(_ sender: Any) {
		
		//guard let model = Process.shared.viewModelsHandlerInterface.paymentOptionViewModel(at: model!.indexPath) as? TableViewCellViewModel else { return }
		
		//model.tableViewDidSelectCell(model.)
		var defaultApplePayType:PKPaymentButtonType = .plain
		if #available(iOS 10.0, *) {
			defaultApplePayType = .inStore
		}
		let applPayButtonType:PKPaymentButtonType = model?.applePayButtonType() ??  defaultApplePayType
		if applPayButtonType == .setUp {
			Process.shared.closePayment(with: .cancelled, fadeAnimation: true, force: true) {
				DispatchQueue.main.async {
					let library = PKPassLibrary()
					library.openPaymentSetup()
				}
			}
			return
		}
		model?.tableViewDidSelectCell(model!.tableView!)
	}
}
