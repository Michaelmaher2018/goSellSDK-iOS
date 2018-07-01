//
//  OTPViewController.swift
//  goSellSDK
//
//  Copyright © 2018 Tap Payments. All rights reserved.
//

import struct   CoreGraphics.CGGeometry.CGRect
import class    TapAdditionsKit.SeparateWindowRootViewController
import struct   TapAdditionsKit.TypeAlias
import class    UIKit.NSLayoutConstraint.NSLayoutConstraint
import class    UIKit.UIButton.UIButton
import class    UIKit.UIColor.UIColor
import class    UIKit.UIFont.UIFont
import class    UIKit.UIGestureRecognizer.UIGestureRecognizer
import class    UIKit.UIImage.UIImage
import class    UIKit.UIImageView.UIImageView
import class    UIKit.UILabel.UILabel
import class    UIKit.UIStoryboard.UIStoryboard
import class    UIKit.UITapGestureRecognizer.UITapGestureRecognizer
import class    UIKit.UIView.UIView
import class    UIKit.UIViewController.UIViewController
import protocol UIKit.UIViewControllerTransitioning.UIViewControllerAnimatedTransitioning
import protocol UIKit.UIViewControllerTransitioning.UIViewControllerInteractiveTransitioning
import protocol UIKit.UIViewControllerTransitioning.UIViewControllerTransitioningDelegate

import class UIKit.UIAlertController.UIAlertAction
import class UIKit.UIAlertController.UIAlertController

/// View controller that handles Tap OTP input.
internal final class OTPViewController: SeparateWindowViewController {
    
    // MARK: - Internal -
    // MARK: Properties
    
    internal var presentationAnimationAnimatingConstraint: NSLayoutConstraint? {
        
        return self.contentViewTopOffsetConstraint
    }
    
    internal fileprivate(set) var dismissalInteractionController: OTPDismissalInteractionController?
    
    // MARK: Methods
    
    internal static func show(in frame: CGRect) {
        
        let controller = self.createAndSetupController()
        
        let parentControllerSetupClosure: TypeAlias.GenericViewControllerClosure<SeparateWindowRootViewController> = { (rootController) in
            
            rootController.view.window?.frame = frame
        }
        
        controller.show(parentControllerSetupClosure: parentControllerSetupClosure)
    }
    
    internal func addInteractiveDismissalRecognizer(_ recognizer: UIGestureRecognizer) {
        
        self.dismissalView?.addGestureRecognizer(recognizer)
    }
    
    internal override func hide(animated: Bool = true, async: Bool = true, completion: TypeAlias.ArgumentlessClosure? = nil) {
        
        super.hide(animated: animated, async: async) {
            
            OTPViewController.destroyInstance()
            completion?()
        }
    }
    
    internal override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        self.otpInputView?.becomeFirstResponder()
        self.startAttempt()
    }
    
    // MARK: - Fileprivate -
    
    /// Transition handler for OTP view controller.
    fileprivate final class Transitioning: NSObject {
        
        fileprivate var shouldUseDefaultOTPAnimation = true
        fileprivate static var storage: Transitioning?
        
        private override init() {
            
            super.init()
            KnownSingletonTypes.add(Transitioning.self)
        }
    }
    
    // MARK: - Private -
    
    private struct Constants {
        
        fileprivate static let dismissalArrowImage: UIImage = {
           
            guard let result = UIImage.named("ic_close_otp", in: .goSellSDKResources) else {
                
                fatalError("Failed to load \"ic_close_otp\" icon from the resources bundle.")
            }
            
            return result
        }()
        
        fileprivate static let descriptionFont:     UIFont  = .helveticaNeueRegular(13.0)
        fileprivate static let descriptionColor:    UIColor = .hex("535353")
        fileprivate static let numberColor:         UIColor = .hex("1584FC")
        
        fileprivate static let updateTimerTimeInterval: TimeInterval = 1.0
        fileprivate static let resendButtonTitleDateFormat = "mm:ss"
        
        @available(*, unavailable) private init() {}
    }
    
    // MARK: Properties
    
    @IBOutlet private weak var dismissalView: UIView?
    
    @IBOutlet private weak var dismissalArrowImageView: UIImageView? {
        
        didSet {
            
            self.dismissalArrowImageView?.image = Constants.dismissalArrowImage
        }
    }
    
    @IBOutlet private weak var otpInputView: OTPInputView? {
        
        didSet {
            
            self.otpInputView?.delegate = self
            self.updateConfirmationButtonState()
        }
    }
    
    @IBOutlet private weak var descriptionLabel: UILabel? {
        
        didSet {
            
            self.updateDescriptionLabelText()
        }
    }
    
    @IBOutlet private weak var resendButton: UIButton?
    
    @IBOutlet private weak var confirmationButton: TapButton? {
        
        didSet {
            
            self.confirmationButton?.delegate = self
            self.confirmationButton?.themeSettings = Theme.current.settings.otpConfirmationButtonSettings
            self.confirmationButton?.setTitle("CONFIRM")
            self.updateConfirmationButtonState()
        }
    }
    
    @IBOutlet private weak var contentViewTopOffsetConstraint: NSLayoutConstraint?
    
    private static var storage: OTPViewController?
    
    private lazy var timerDataManager = OTPTimerDataManager()
    
    private lazy var countdownDateFormatter: DateFormatter = {
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: goSellSDK.localeIdentifier)
        formatter.dateFormat = Constants.resendButtonTitleDateFormat
        
        return formatter
    }()
    
    // MARK: Methods
    
    private static func createAndSetupController() -> OTPViewController {
        
        KnownSingletonTypes.add(OTPViewController.self)
        
        let controller = self.shared
        controller.modalPresentationStyle = .custom
        controller.transitioningDelegate = Transitioning.shared
        
        return controller
    }
    
    private func updateDescriptionLabelText() {
        
        let maskedNumber = "+965 00●●●●00"
        let descriptionText = "Please enter the OTP that has been sent to "
        
        let descriptionAttributes: [NSAttributedStringKey: Any] = [
            
            .font: Constants.descriptionFont,
            .foregroundColor: Constants.descriptionColor
        ]
        
        let numberAttributes: [NSAttributedStringKey: Any] = [
            
            .font: Constants.descriptionFont,
            .foregroundColor: Constants.numberColor
        ]
        
        let attributedDescriptionText = NSAttributedString(string: descriptionText, attributes: descriptionAttributes)
        let attributedMaskedNumberText = NSAttributedString(string: maskedNumber, attributes: numberAttributes)
        let result = NSMutableAttributedString(attributedString: attributedDescriptionText)
        result.append(attributedMaskedNumberText)
        
        self.descriptionLabel?.attributedText = NSAttributedString(attributedString: result)
    }
    
    private func updateConfirmationButtonState() {
        
        guard let inputView = self.otpInputView else { return }
        
        self.makeConfirmationButtonEnabled(inputView.isProvidedDataValid)
    }
    
    private func makeConfirmationButtonEnabled(_ enabled: Bool) {
        
        self.confirmationButton?.isEnabled = enabled
    }
    
    private func startAttempt() {
        
        self.timerDataManager.startTimer(force: false) { [weak self] (state) in
            
            self?.updateResendButtonTitle(with: state)
        }
    }
    
    private func updateResendButtonTitle(with state: OTPTimerState) {
        
        switch state {
            
        case .ticking(let remainingSeconds):
            
            let remainingDate = Date(timeIntervalSince1970: remainingSeconds)
            let title = self.countdownDateFormatter.string(from: remainingDate)
            
            self.resendButton?.setTitle(title, for: .normal)
            self.resendButton?.alpha = 1.0
            self.resendButton?.isEnabled = false
            
        case .notTicking:
            
            self.resendButton?.setTitle("RESEND", for: .normal)
            self.resendButton?.alpha = 1.0
            self.resendButton?.isEnabled = true
            
        case .attemptsFinished:
            
            self.resendButton?.setTitle("RESEND", for: .normal)
            self.resendButton?.alpha = 0.5
            self.resendButton?.isEnabled = false
            
        }
    }
    
    @IBAction private func resendButtonTouchUpInside(_ sender: Any) {
        
        self.startAttempt()
    }
    
    @IBAction private func dismissalViewTapDetected(_ recognizer: UITapGestureRecognizer) {
        
        guard let recognizerView = recognizer.view, recognizerView.bounds.contains(recognizer.location(in: recognizerView)), recognizer.state == .ended else {
            
            return
        }
        
        self.hide(animated: true)
    }
}

// MARK: - InstantiatableFromStoryboard
extension OTPViewController: InstantiatableFromStoryboard {
    
    internal static var hostingStoryboard: UIStoryboard {
        
        return .goSellSDKPayment
    }
}

// MARK: - Singleton
extension OTPViewController: Singleton {
    
    internal static var hasAliveInstance: Bool {
        
        return self.storage != nil
    }
    
    internal static var shared: OTPViewController {
        
        if let nonnullStorage = self.storage {
            
            return nonnullStorage
        }
        
        let instance = OTPViewController.instantiate()
        self.storage = instance
        
        Transitioning.shared.shouldUseDefaultOTPAnimation = true
        
        return instance
    }
    
    internal static func destroyInstance() {
        
        Transitioning.shared.shouldUseDefaultOTPAnimation = false
        self.storage?.hide(animated: true)
        self.storage = nil
    }
}

// MARK: - TapButtonDelegate
extension OTPViewController: TapButtonDelegate {
    
    internal var canBeHighlighted: Bool {
        
        return true
    }
    
    internal func buttonTouchUpInside() {
        
        let alert = UIAlertController(title: "Not implemented", message: "This action is not implemented yet.", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { [weak alert] (action) in
            
            alert?.dismiss(animated: true, completion: nil)
        }
        
        alert.addAction(okAction)
        
        self.show(alert, sender: self)
    }
    
    internal func securityButtonTouchUpInside() {
        
        self.buttonTouchUpInside()
    }
}

// MARK: - Singleton
extension OTPViewController.Transitioning: Singleton {
    
    fileprivate static var hasAliveInstance: Bool {
        
        return self.storage != nil
    }
    
    fileprivate static var shared: OTPViewController.Transitioning {
        
        if let nonnullStorage = self.storage {
            
            return nonnullStorage
        }
        
        let instance = OTPViewController.Transitioning()
        self.storage = instance
        
        return instance
    }
    
    fileprivate static func destroyInstance() {
        
        self.storage = nil
    }
}

// MARK: - UIViewControllerTransitioningDelegate
extension OTPViewController.Transitioning: UIViewControllerTransitioningDelegate {
    
    internal func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        
        if let otpController = presented as? OTPViewController {
            
            let interactionController = OTPDismissalInteractionController(viewController: otpController)
            otpController.dismissalInteractionController = interactionController
        }
        
        return self.shouldUseDefaultOTPAnimation    ? OTPAnimationController(operation: .presentation, from: presented, to: presenting)
                                                    : PaymentPresentationAnimationController()
    }
    
    internal func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        
        return self.shouldUseDefaultOTPAnimation    ? OTPAnimationController(operation: .dismissal, from: dismissed, to: dismissed.presentingViewController!)
                                                    : PaymentDismissalAnimationController()
    }
    
    internal func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        
        if
            
            let otpAnimator = animator as? OTPAnimationController,
            let otpController = otpAnimator.fromViewController as? OTPViewController,
            let interactionController = otpController.dismissalInteractionController, interactionController.isInteracting {
            
            interactionController.statusListener = otpAnimator
            return interactionController
        }
        else {
            
            return nil
        }
    }
}

// MARK: - OTPInputViewDelegate
extension OTPViewController: OTPInputViewDelegate {
    
    internal func otpInputView(_ otpInputView: OTPInputView, inputStateChanged valid: Bool) {
        
        self.makeConfirmationButtonEnabled(valid)
    }
}
