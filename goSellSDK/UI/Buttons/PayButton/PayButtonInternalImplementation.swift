//
//  PayButtonInternalImplementation.swift
//  goSellSDK
//
//  Copyright © 2018 Tap Payments. All rights reserved.
//

import class UIKit.UIStoryboard.UIStoryboard
import class UIKit.UIView.UIView

internal protocol PayButtonInternalImplementation: PayButtonProtocol {
    
    var dataSource: PaymentDataSource? { get }
    
    var uiElement: PayButtonUI? { get }
    
    var theme: Theme { get }
    
    func updateDisplayedStateAndAmount()
}

internal extension PayButtonInternalImplementation {
    
    // MARK: - Internal -
    // MARK: Properties
    
    internal var canBeHighlighted: Bool {
        
        return !PaymentDataManager.shared.isExecutingAPICalls
    }
    
    // MARK: Methods
    
    internal func calculateDisplayedAmount() {
        
        self.isEnabled = true
        
        let items = self.dataSource?.items ?? []
        let taxes = self.dataSource?.taxes ?? nil
        let shipping = self.dataSource?.shipping ?? nil
        
        let amount = AmountCalculator.totalAmount(of: items, with: taxes, and: shipping)
        
        guard let currency = self.dataSource?.currency, amount > 0.0, items.count > 0 else {
            
            self.uiElement?.amount = nil
            return
        }
        
        self.uiElement?.amount = AmountedCurrency(currency, amount)
    }
    
    internal func buttonTouchUpInside() {
        
        PaymentDataManager.shared.start(with: self)
    }
    
    internal func paymentDataManagerDidStartLoadingPaymentOptions() {
        
        self.uiElement?.startLoader()
    }
    
    internal func paymentDataManagerDidStopLoadingPaymentOptions(with success: Bool) {
        
        self.uiElement?.stopLoader()
        
        guard success else { return }
        
        let controller = self.instantiatePaymentContainerController()
        
        if let selfAsView = self as? UIView & PayButtonProtocol {
            
            controller.payButton = selfAsView
        }
        
        controller.showOnSeparateWindow { [unowned controller] (rootController) in
            
            rootController.allowedInterfaceOrientations = .portrait
            rootController.preferredInterfaceOrientation = .portrait
            rootController.canAutorotate = false
            
            rootController.present(controller, animated: false, completion: nil)
        }
    }
    
    // MARK: - Private -
    // MARK: Methods
    
    private func instantiatePaymentContainerController() -> PaymentViewController {
        
        guard let controller = UIStoryboard.goSellSDKPayment.instantiateInitialViewController() as? PaymentViewController else {
            
            fatalError("Failed to instantiate \(PaymentViewController.self) from storyboard.")
        }
        
        return controller
    }
}
