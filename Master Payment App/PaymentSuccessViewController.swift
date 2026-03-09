//
//  PaymentSuccessViewController.swift
//  scane app
//
//  Created by sheikh abu mohamed on 08/03/26.
//
//  Paytm-style Payment Success Receipt Screen
//  Accepts dynamic amount, UPI ID and payment date from the navigation flow.
//

import SwiftUI
import UIKit
import AudioToolbox

// MARK: - SwiftUI Entry Point

/// Drop into NavigationStack with live payment data.
struct PaymentSuccessView: View {

    let upiID: String
    let amount: String
    let paymentDate: Date
    @Environment(\.dismiss) var dismiss

    var body: some View {
        PaymentSuccessRepresentable(upiID: upiID, amount: amount, paymentDate: paymentDate)
            .ignoresSafeArea()
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(red: 0, green: 0.45, blue: 0.85), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct PaymentSuccessRepresentable: UIViewControllerRepresentable {

    let upiID: String
    let amount: String
    let paymentDate: Date

    func makeUIViewController(context: Context) -> PaymentSuccessViewController {
        PaymentSuccessViewController(upiID: upiID, amount: amount, paymentDate: paymentDate)
    }
    func updateUIViewController(_ uiViewController: PaymentSuccessViewController, context: Context) {}
}

// MARK: - UILabel Extension (Reusable Styling)

extension UILabel {

    /// Convenience factory for styled labels
    static func styled(
        text: String,
        font: UIFont,
        color: UIColor = .darkText,
        alignment: NSTextAlignment = .center,
        lines: Int = 0
    ) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.textAlignment = alignment
        label.numberOfLines = lines
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    /// Apply a new style in-place and return self for chaining
    @discardableResult
    func applyStyle(
        font: UIFont? = nil,
        color: UIColor? = nil,
        alignment: NSTextAlignment? = nil
    ) -> UILabel {
        if let font { self.font = font }
        if let color { self.textColor = color }
        if let alignment { self.textAlignment = alignment }
        return self
    }
}

// MARK: - PaymentSuccessViewController

final class PaymentSuccessViewController: UIViewController {

    // MARK: Dynamic Data
    private let upiID: String
    private let amount: String
    private let paymentDate: Date

    // MARK: Palette
    private let paytmBlue      = UIColor(red: 0.00, green: 0.45, blue: 0.85, alpha: 1)
    private let paytmLightBlue = UIColor(red: 0.88, green: 0.95, blue: 1.00, alpha: 1)
    private let successGreen   = UIColor(red: 0.13, green: 0.76, blue: 0.37, alpha: 1)
    private let subtitleGray   = UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1)
    private let dividerColor   = UIColor(red: 0.90, green: 0.90, blue: 0.90, alpha: 1)

    // MARK: Init
    init(upiID: String, amount: String, paymentDate: Date) {
        self.upiID       = upiID
        self.amount      = amount
        self.paymentDate = paymentDate
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Use init(upiID:amount:paymentDate:)") }

    // MARK: - Date Helpers
    private var formattedDateTime: String {
        let df = DateFormatter()
        df.dateFormat = "d MMM, h:mm a"
        return df.string(from: paymentDate)
    }

    private var referenceNumber: String {
        // Generate a pseudo-random ref based on the timestamp
        let ts = Int(paymentDate.timeIntervalSince1970)
        return String(format: "%012d", abs(ts) % 999_999_999_999)
    }
    
    private var transactionID: String {
        // Generate unique transaction ID using UUID prefix + timestamp
        let uuid = UUID().uuidString.prefix(8).uppercased()
        let timestamp = Int(Date().timeIntervalSince1970)
        return "TXN\(uuid)\(String(timestamp).suffix(6))"
    }
    
    private var utrNumber: String {
        // Generate unique UTR (Unified Transaction Reference) number
        let timestamp = Int(Date().timeIntervalSince1970)
        let randomSuffix = Int.random(in: 1000...9999)
        return String(format: "UTR%010d%04d", timestamp, randomSuffix)
    }

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1)
        setupUI()
        playSuccessSound()
        animateSuccess()
        sendPaymentNotification()
    }
    
    private func sendPaymentNotification() {
        // Extract numeric amount
        if let amountValue = Double(amount) {
            // Generate UPI reference number for this transaction
            let upiRef = FirebaseManager.shared.generateUPIReference()
            let txnID = transactionID
            
            // ── Store debit notification in app history ─────────
            let accountNumber = "XXXXXXXX1605"
            let dateStr = {
                let f = DateFormatter(); f.dateFormat = "dd-MM-yy"; return f.string(from: Date())
            }()
            let debitBody = "Your A/c \(accountNumber) has been debited by Rs.\(String(format: "%.2f", amountValue)) via UPI txn on \(dateStr). UPI Ref: \(upiRef). If not done by you, report immediately to the bank on 18008901234. MASTER BANK"
            
            NotificationManager.shared.addNotification(
                title: "💳 MASTER BANK - Debit Alert",
                body: debitBody,
                type: "debit",
                amount: amountValue,
                upiRef: upiRef
            )
            
            // ── Store credit notification for recipient ────────
            let creditBody = "Your A/c has been credited by Rs.\(String(format: "%.2f", amountValue)) from Sheikh Abu Mohamed via UPI on \(dateStr). UPI Ref: \(upiRef). MASTER BANK"
            
            NotificationManager.shared.addNotification(
                title: "💰 Credit - ₹\(String(format: "%.2f", amountValue)) received",
                body: creditBody,
                type: "credit",
                amount: amountValue,
                upiRef: upiRef
            )
            
            // Send debit notification to sender (you)
            FirebaseManager.shared.sendDebitNotification(
                senderUPI: "user@upi",
                amount: amountValue,
                recipientUPI: upiID,
                upiRef: upiRef
            )
            
            // Send credit SMS to recipient
            FirebaseManager.shared.sendCreditNotification(
                recipientUPI: upiID,
                amount: amountValue,
                senderName: "Sheikh Abu Mohamed",
                upiRef: upiRef
            )
            
            // Store transaction in Firebase for history
            FirebaseManager.shared.storeTransaction(
                senderUPI: "user@upi",
                recipientUPI: upiID,
                amount: amountValue,
                transactionID: txnID,
                status: "completed"
            )
        }
    }
    
    private func playSuccessSound() {
        AudioServicesPlaySystemSound(1577)  // Success/Pebble sound
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
    
    private func animateSuccess() {
        // Add subtle entrance animation
        view.alpha = 0
        UIView.animate(withDuration: 0.6, delay: 0, options: .curveEaseOut, animations: {
            self.view.alpha = 1
        })
    }

    // MARK: - UI Construction
    private func setupUI() {

        // Scrollable so it works on smaller devices
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsVerticalScrollIndicator = false
        view.addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let content = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor)
        ])

        // ── 1. Light-blue header background ───────────────────
        let headerBG = UIView()
        headerBG.backgroundColor = paytmBlue
        headerBG.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(headerBG)

        NSLayoutConstraint.activate([
            headerBG.topAnchor.constraint(equalTo: content.topAnchor),
            headerBG.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            headerBG.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            headerBG.heightAnchor.constraint(equalToConstant: 280)
        ])

        // ── 2. Large success checkmark ─────────────────────────
        let successIcon = makeSuccessCheckmark()
        content.addSubview(successIcon)

        NSLayoutConstraint.activate([
            successIcon.topAnchor.constraint(equalTo: content.topAnchor, constant: 60),
            successIcon.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            successIcon.widthAnchor.constraint(equalToConstant: 100),
            successIcon.heightAnchor.constraint(equalToConstant: 100)
        ])

        // ── 3. "Payment Successful" text ──────────────────────
        let successText = UILabel.styled(
            text: "Payment Successful",
            font: .boldSystemFont(ofSize: 24),
            color: .white,
            alignment: .center
        )
        content.addSubview(successText)

        NSLayoutConstraint.activate([
            successText.topAnchor.constraint(equalTo: successIcon.bottomAnchor, constant: 20),
            successText.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            successText.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: 20),
            successText.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20)
        ])

        // ── 4. Receipt card ────────────────────────────────────
        let card = makeReceiptCard()
        content.addSubview(card)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: successText.bottomAnchor, constant: 40),
            card.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -30)
        ])
    }

    // MARK: - Paytm Logo
    private func makePaytmLogo() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let attributed = NSMutableAttributedString(
            string: "pay",
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: 32),
                .foregroundColor: paytmBlue
            ]
        )
        attributed.append(NSAttributedString(
            string: "tm",
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: 32),
                .foregroundColor: UIColor(red: 0.00, green: 0.70, blue: 0.95, alpha: 1)
            ]
        ))

        let logo = UILabel()
        logo.attributedText = attributed
        logo.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(logo)

        NSLayoutConstraint.activate([
            logo.topAnchor.constraint(equalTo: container.topAnchor),
            logo.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            logo.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            logo.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        return container
    }

    // MARK: - Large Success Checkmark
    private func makeSuccessCheckmark() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let circle = UIView()
        circle.backgroundColor = successGreen
        circle.layer.cornerRadius = 50
        circle.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(circle)

        NSLayoutConstraint.activate([
            circle.widthAnchor.constraint(equalToConstant: 100),
            circle.heightAnchor.constraint(equalToConstant: 100),
            circle.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            circle.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        let config = UIImage.SymbolConfiguration(pointSize: 50, weight: .bold)
        let checkmark = UIImage(systemName: "checkmark", withConfiguration: config)
        let checkView = UIImageView(image: checkmark)
        checkView.tintColor = .white
        checkView.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(checkView)

        NSLayoutConstraint.activate([
            checkView.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            checkView.centerYAnchor.constraint(equalTo: circle.centerYAnchor)
        ])

        return container
    }

    // MARK: - Receipt Card
    private func makeReceiptCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius  = 20
        card.layer.shadowColor   = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.12
        card.layer.shadowRadius  = 16
        card.layer.shadowOffset  = CGSize(width: 0, height: 8)
        card.clipsToBounds = false

        let stack = UIStackView()
        stack.axis      = .vertical
        stack.alignment = .fill
        stack.spacing   = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 32),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -32),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24)
        ])

        // ── Amount row with icon ──────────────────────────────
        let amountRow = makeAmountRow()
        stack.addArrangedSubview(amountRow)
        stack.setCustomSpacing(24, after: amountRow)

        // ── Divider ────────────────────────────────────────────
        stack.addArrangedSubview(makeDivider())
        stack.setCustomSpacing(24, after: stack.arrangedSubviews.last!)

        // ── Transaction Details Container ─────────────────────
        let detailsContainer = UIStackView()
        detailsContainer.axis = .vertical
        detailsContainer.spacing = 16
        detailsContainer.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(detailsContainer)
        
        // Recipient Section
        let recipientLabel = UILabel.styled(
            text: "Recipient",
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: subtitleGray,
            alignment: .left
        )
        detailsContainer.addArrangedSubview(recipientLabel)
        
        let toLabel = UILabel.styled(
            text: upiID,
            font: .systemFont(ofSize: 16, weight: .medium),
            color: .darkText,
            alignment: .left,
            lines: 2
        )
        detailsContainer.addArrangedSubview(toLabel)
        
        // ── Divider ────────────────────────────────────────────
        detailsContainer.addArrangedSubview(makeDivider())
        
        // Speed Badge
        let speedBadge = makeSpeedBadge()
        detailsContainer.addArrangedSubview(speedBadge)
        
        // ── Divider ────────────────────────────────────────────
        detailsContainer.addArrangedSubview(makeDivider())

        // ── From: payer ────────────────────────────────────────
        let payerLabel = UILabel.styled(
            text: "From",
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: subtitleGray,
            alignment: .left
        )
        detailsContainer.addArrangedSubview(payerLabel)
        
        let fromLabel = UILabel.styled(
            text: "Sheikh Abu Mohamed So Nazir Ah",
            font: .systemFont(ofSize: 16, weight: .medium),
            color: .darkText,
            alignment: .left, lines: 2
        )
        detailsContainer.addArrangedSubview(fromLabel)

        let bankLabel = UILabel.styled(
            text: "Jammu And Kashmir Bank - 1605",
            font: .systemFont(ofSize: 13),
            color: subtitleGray,
            alignment: .left
        )
        detailsContainer.addArrangedSubview(bankLabel)
        
        // Add details container to main stack
        stack.setCustomSpacing(24, after: detailsContainer)

        // ── Divider ────────────────────────────────────────────
        stack.addArrangedSubview(makeDivider())
        stack.setCustomSpacing(20, after: stack.arrangedSubviews.last!)

        // ── Transaction Info ──────────────────────────────────
        let infoStack = UIStackView()
        infoStack.axis = .vertical
        infoStack.spacing = 8
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(infoStack)
        
        let dateLabel = UILabel.styled(
            text: formattedDateTime,
            font: .systemFont(ofSize: 14, weight: .medium),
            color: .darkText,
            alignment: .center
        )
        infoStack.addArrangedSubview(dateLabel)
        
        let txnLabel = UILabel.styled(
            text: "Transaction ID: \(transactionID)",
            font: .systemFont(ofSize: 12, weight: .medium),
            color: .darkText,
            alignment: .center
        )
        infoStack.addArrangedSubview(txnLabel)
        
        let utrLabel = UILabel.styled(
            text: "UTR: \(utrNumber)",
            font: .systemFont(ofSize: 12, weight: .medium),
            color: .darkText,
            alignment: .center
        )
        infoStack.addArrangedSubview(utrLabel)
        
        let refLabel = UILabel.styled(
            text: "Ref: \(referenceNumber)",
            font: .systemFont(ofSize: 11),
            color: subtitleGray,
            alignment: .center
        )
        infoStack.addArrangedSubview(refLabel)
        stack.setCustomSpacing(24, after: infoStack)

        // ── Done button ────────────────────────────────────────
        let doneBtn = makeDoneButton()
        stack.addArrangedSubview(doneBtn)
        doneBtn.widthAnchor.constraint(
            equalTo: stack.widthAnchor
        ).isActive = true
        doneBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true

        return card
    }

    // MARK: - Amount Row
    private func makeAmountRow() -> UIView {
        let row = UIStackView()
        row.axis      = .horizontal
        row.alignment = .center
        row.spacing   = 16
        row.translatesAutoresizingMaskIntoConstraints = false

        row.addArrangedSubview(makeCheckCircle())

        let amountStack = UIStackView()
        amountStack.axis = .vertical
        amountStack.spacing = 4
        amountStack.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel.styled(
            text: "Amount Paid",
            font: .systemFont(ofSize: 14, weight: .regular),
            color: subtitleGray,
            alignment: .left
        )
        
        let amountLabel = UILabel()
        amountLabel.text      = "₹\(amount)"
        amountLabel.font      = .boldSystemFont(ofSize: 36)
        amountLabel.textColor = .darkText
        amountLabel.textAlignment = .left
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        amountStack.addArrangedSubview(label)
        amountStack.addArrangedSubview(amountLabel)
        row.addArrangedSubview(amountStack)
        row.addArrangedSubview(UIView())  // Spacer

        return row
    }

    // MARK: - Green Checkmark Circle
    private func makeCheckCircle() -> UIView {
        let size: CGFloat = 38
        let circle = UIView()
        circle.backgroundColor    = successGreen
        circle.layer.cornerRadius = size / 2
        circle.translatesAutoresizingMaskIntoConstraints = false
        circle.widthAnchor.constraint(equalToConstant: size).isActive  = true
        circle.heightAnchor.constraint(equalToConstant: size).isActive = true

        let config    = UIImage.SymbolConfiguration(pointSize: 17, weight: .bold)
        let checkImg  = UIImage(systemName: "checkmark", withConfiguration: config)
        let checkView = UIImageView(image: checkImg)
        checkView.tintColor = .white
        checkView.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(checkView)

        NSLayoutConstraint.activate([
            checkView.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            checkView.centerYAnchor.constraint(equalTo: circle.centerYAnchor)
        ])
        return circle
    }

    // MARK: - Speed Badge
    private func makeSpeedBadge() -> UIView {
        let badge = UIView()
        badge.backgroundColor   = UIColor(red: 0.93, green: 0.98, blue: 0.93, alpha: 1)
        badge.layer.cornerRadius = 12
        badge.translatesAutoresizingMaskIntoConstraints = false

        let label  = UILabel()
        let dots   = NSAttributedString(
            string: "● ● ●  ",
            attributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: successGreen
            ]
        )
        let rocket = NSAttributedString(
            string: "🚀 Paid instantly",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor(red: 0.05, green: 0.55, blue: 0.20, alpha: 1)
            ]
        )
        let combined = NSMutableAttributedString(attributedString: dots)
        combined.append(rocket)
        label.attributedText = combined
        label.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: badge.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -14)
        ])
        return badge
    }

    // MARK: - Divider
    private func makeDivider() -> UIView {
        let line = UIView()
        line.backgroundColor = dividerColor
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        line.widthAnchor.constraint(
            equalToConstant: UIScreen.main.bounds.width - 80
        ).isActive = true
        return line
    }

    // MARK: - Done Button
    private func makeDoneButton() -> UIView {
        let btn = UIButton(type: .system)
        btn.setTitle("Done", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor    = paytmBlue
        btn.layer.cornerRadius = 14
        btn.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subtle shadow
        btn.layer.shadowColor = paytmBlue.cgColor
        btn.layer.shadowOpacity = 0.3
        btn.layer.shadowRadius = 8
        btn.layer.shadowOffset = CGSize(width: 0, height: 4)
        
        btn.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        return btn
    }

    @objc private func doneTapped() {
        // Post notification with payment info for the SendMessageScreen
        NotificationCenter.default.post(
            name: NSNotification.Name("PaymentCompleted"),
            object: nil,
            userInfo: [
                "upiID": upiID,
                "amount": amount
            ]
        )
        
        // Dismiss this view controller
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.navigationController?.popToRootViewController(animated: true)
        }
    }
}

// MARK: - Preview

#Preview {
    PaymentSuccessView(
        upiID: "indusind.payu@indus",
        amount: "21070",
        paymentDate: Date()
    )
}
