//
//  ContentView.swift
//  Master Payment App
//
//  Created by sheikh abu mohamed on 08/03/26.
//
//  Complete app flow:
//  1. DashboardScreen - Main wallet & payment hub
//  2. ScannerScreen - QR code scanner for payments
//  3. AmountScreen - Payment amount confirmation
//  4. SuccessScreen - Payment receipt
//  5. ReceiveQRScreen - Show QR for receiving payments
//

import SwiftUI
import AVFoundation
import AudioToolbox
import Combine
import FirebaseCore

// MARK: - App Root

struct ContentView: View {
    @State private var path: [AppRoute] = []
    @StateObject private var walletManager = WalletManager()
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some View {
        NavigationStack(path: $path) {
            DashboardScreen(path: $path, walletManager: walletManager, notificationManager: notificationManager)
                .navigationDestination(for: AppRoute.self) { route in
                    Group {
                        switch route {
                        case .scanner:
                            ScannerScreen(path: $path, walletManager: walletManager)
                        case .amount(let upiID):
                            AmountScreen(path: $path, upiID: upiID, walletManager: walletManager)
                        case .success(let upiID, let amount, let date):
                            PaymentSuccessView(upiID: upiID, amount: amount, paymentDate: date)
                        case .receiveQR:
                            ReceiveQRScreen(walletManager: walletManager)
                        case .addMoney:
                            AddMoneyScreen(path: $path, walletManager: walletManager)
                        case .sendMessage(let recipientUPI, let amount):
                            SendMessageScreen(path: $path, recipientUPI: recipientUPI, amount: amount)
                        case .notifications:
                            NotificationHistoryScreen(notificationManager: notificationManager)
                        }
                    }
                }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PaymentCompleted"))) { notification in
            // Navigate to send message screen after payment
            if let userInfo = notification.userInfo,
               let upiID = userInfo["upiID"] as? String,
               let amountStr = userInfo["amount"] as? String,
               let amount = Double(amountStr) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    path.append(.sendMessage(recipientUPI: upiID, amount: amount))
                }
            }
        }
    }
}

// MARK: - Navigation Routes

enum AppRoute: Hashable {
    case scanner
    case amount(upiID: String)
    case success(upiID: String, amount: String, date: Date)
    case receiveQR
    case addMoney
    case sendMessage(recipientUPI: String, amount: Double)
    case notifications
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .scanner:
            hasher.combine("scanner")
        case .amount(let upiID):
            hasher.combine("amount")
            hasher.combine(upiID)
        case .success(let upiID, let amount, let date):
            hasher.combine("success")
            hasher.combine(upiID)
            hasher.combine(amount)
            hasher.combine(date.timeIntervalSince1970)
        case .receiveQR:
            hasher.combine("receiveQR")
        case .addMoney:
            hasher.combine("addMoney")
        case .sendMessage(let upiID, let amount):
            hasher.combine("sendMessage")
            hasher.combine(upiID)
            hasher.combine(amount)
        case .notifications:
            hasher.combine("notifications")
        }
    }
    
    static func == (lhs: AppRoute, rhs: AppRoute) -> Bool {
        switch (lhs, rhs) {
        case (.scanner, .scanner): return true
        case (.amount(let l), .amount(let r)): return l == r
        case (.success(let lu, let la, _), .success(let ru, let ra, _)): return lu == ru && la == ra
        case (.receiveQR, .receiveQR): return true
        case (.addMoney, .addMoney): return true
        case (.sendMessage(let lu, let la), .sendMessage(let ru, let ra)): return lu == ru && la == ra
        case (.notifications, .notifications): return true
        default: return false
        }
    }
}

// MARK: - Wallet Manager

class WalletManager: ObservableObject {
    @Published var balance: Double = 5000.0
    @Published var transactions: [Transaction] = [
        Transaction(id: "1", type: .received, amount: 500, from: "Rahul Sharma", date: Date().addingTimeInterval(-3600)),
        Transaction(id: "2", type: .sent, amount: 250, to: "Priya Singh", date: Date().addingTimeInterval(-7200))
    ]
    
    init() {
        // Firebase is already initialized in scane_appApp.swift
        // No need to initialize here again
    }
    
    func deductFromWallet(_ amount: Double) {
        balance -= amount
        transactions.append(Transaction(id: UUID().uuidString, type: .sent, amount: amount, to: "Payment", date: Date()))
    }
    
    func addToWallet(_ amount: Double, from: String) {
        balance += amount
        transactions.append(Transaction(id: UUID().uuidString, type: .received, amount: amount, from: from, date: Date()))
    }
}

// MARK: - App Notification Model

struct AppNotification: Identifiable, Codable {
    let id: String
    let title: String
    let body: String
    let type: String   // "debit", "credit", "scan", "payment"
    let date: Date
    let amount: Double?
    let upiRef: String?
}

// MARK: - Notification Manager (In-App History)

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var notifications: [AppNotification] = []
    
    private let storageKey = "app_notifications"
    
    init() {
        loadNotifications()
    }
    
    func addNotification(title: String, body: String, type: String, amount: Double? = nil, upiRef: String? = nil) {
        let notification = AppNotification(
            id: UUID().uuidString,
            title: title,
            body: body,
            type: type,
            date: Date(),
            amount: amount,
            upiRef: upiRef
        )
        DispatchQueue.main.async {
            self.notifications.insert(notification, at: 0)
            self.saveNotifications()
        }
    }
    
    func removeNotification(id: String) {
        notifications.removeAll { $0.id == id }
        saveNotifications()
    }
    
    func clearAll() {
        notifications.removeAll()
        saveNotifications()
    }
    
    private func saveNotifications() {
        if let data = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadNotifications() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([AppNotification].self, from: data) {
            notifications = saved
        }
    }
}

struct Transaction: Identifiable {
    let id: String
    enum TransactionType {
        case sent
        case received
    }
    let type: TransactionType
    let amount: Double
    let from: String?
    let to: String?
    let date: Date
    
    init(id: String, type: TransactionType, amount: Double, from: String? = nil, to: String? = nil, date: Date) {
        self.id = id
        self.type = type
        self.amount = amount
        self.from = from
        self.to = to
        self.date = date
    }
}

// MARK: - Dashboard Screen

struct DashboardScreen: View {
    @Binding var path: [AppRoute]
    @ObservedObject var walletManager: WalletManager
    @ObservedObject var notificationManager: NotificationManager
    
    private let paytmBlue = Color(red: 0, green: 0.45, blue: 0.85)
    private let successGreen = Color(red: 0.13, green: 0.76, blue: 0.37)
    
    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.98, blue: 0.99).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Header with greeting & notification bell
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Welcome back!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("Sheikh Abu Mohamed")
                                .font(.title2.bold())
                                .foregroundColor(.black)
                        }
                        Spacer()
                        Button {
                            path.append(.notifications)
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell.fill")
                                    .font(.title2)
                                    .foregroundColor(paytmBlue)
                                    .padding(10)
                                    .background(paytmBlue.opacity(0.1))
                                    .clipShape(Circle())
                                
                                if !notificationManager.notifications.isEmpty {
                                    Text("\(notificationManager.notifications.count)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 20, height: 20)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .offset(x: 4, y: -4)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // MARK: - Wallet Card
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Wallet Balance")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                Text("₹\(String(format: "%.2f", walletManager.balance))")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Image(systemName: "wallet.pass.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.3))
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Card Number")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("**** **** **** 1234")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Valid Thru")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("03/28")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.3))
                        
                        Button {
                            path.append(.addMoney)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                Text("Add Money")
                                    .font(.subheadline.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundColor(paytmBlue)
                        }
                    }
                    .padding(24)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [paytmBlue, Color(red: 0, green: 0.35, blue: 0.75)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(20)
                    .padding(.horizontal, 20)
                    .shadow(color: paytmBlue.opacity(0.3), radius: 12, x: 0, y: 8)
                    
                    // MARK: - Action Buttons
                    HStack(spacing: 12) {
                        Button {
                            path.append(.scanner)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.title2)
                                Text("Pay Now")
                                    .font(.caption.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundColor(.white)
                            .background(paytmBlue)
                            .cornerRadius(12)
                        }
                        
                        Button {
                            path.append(.receiveQR)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "qrcode")
                                    .font(.title2)
                                Text("Request")
                                    .font(.caption.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundColor(.white)
                            .background(successGreen)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // MARK: - Daily News Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Latest Updates")
                                .font(.headline.bold())
                            Spacer()
                            Image(systemName: "newspaper.fill")
                                .foregroundColor(paytmBlue)
                        }
                        .padding(.horizontal, 20)
                        
                        VStack(spacing: 12) {
                            NewsCard(
                                icon: "📱",
                                title: "New Feature Unlock",
                                description: "Send money internationally at 0% fees",
                                color: Color.blue.opacity(0.1)
                            )
                            
                            NewsCard(
                                icon: "🎁",
                                title: "Cashback Offer",
                                description: "Get 10% cashback on every 5 transactions",
                                color: Color.green.opacity(0.1)
                            )
                            
                            NewsCard(
                                icon: "🔐",
                                title: "Security Update",
                                description: "Biometric authentication now available",
                                color: Color.purple.opacity(0.1)
                            )
                            
                            NewsCard(
                                icon: "🏆",
                                title: "Loyalty Program",
                                description: "Earn rewards with every transaction",
                                color: Color.orange.opacity(0.1)
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 10)
                    
                    // MARK: - Recent Transactions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Transactions")
                            .font(.headline.bold())
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            ForEach(walletManager.transactions.prefix(3)) { transaction in
                                TransactionRow(transaction: transaction)
                                if transaction.id != walletManager.transactions.prefix(3).last?.id {
                                    Divider()
                                        .padding(.vertical, 8)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical, 20)
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - News Card

struct NewsCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 28))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.black)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(color)
        .cornerRadius(10)
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.type == .sent ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.title2)
                .foregroundColor(transaction.type == .sent ? .red : .green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.type == .sent ? "Paid to" : "Received from")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(transaction.type == .sent ? (transaction.to ?? "") : (transaction.from ?? ""))
                    .font(.subheadline.bold())
                    .foregroundColor(.black)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(transaction.type == .sent ? "-" : "+")₹\(String(format: "%.2f", transaction.amount))")
                    .font(.subheadline.bold())
                    .foregroundColor(transaction.type == .sent ? .red : .green)
                Text(transaction.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Receive QR Screen

struct ReceiveQRScreen: View {
    @ObservedObject var walletManager: WalletManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.98, blue: 0.99).ignoresSafeArea()
            
            VStack(spacing: 24) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.blue)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                VStack(spacing: 16) {
                    Text("Receive Money")
                        .font(.title2.bold())
                    
                    Text("Share this QR code with anyone to receive payment")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                VStack(spacing: 20) {
                    // QR Code placeholder
                    ZStack {
                        Color.white
                        VStack(spacing: 0) {
                            ForEach(0..<15, id: \.self) { _ in
                                HStack(spacing: 0) {
                                    ForEach(0..<15, id: \.self) { _ in
                                        Rectangle()
                                            .fill(Bool.random() ? Color.black : Color.white)
                                            .frame(width: 8, height: 8)
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                    .frame(height: 280)
                    .cornerRadius(16)
                    .padding(24)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.1), radius: 8)
                    .padding(.horizontal, 20)
                    
                    VStack(spacing: 8) {
                        Text("Your UPI ID")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("aqi97@upi")
                            .font(.headline.bold())
                            .foregroundColor(.black)
                    }
                    
                    Button {
                        UIPasteboard.general.string = "aqi97@upi"
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy UPI ID")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color(red: 0, green: 0.45, blue: 0.85))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
        }
    }
}


// MARK: - Screen 1 · QR Scanner

struct ScannerScreen: View {
    @Binding var path: [AppRoute]
    @ObservedObject var walletManager: WalletManager
    @State private var isTorchOn = false
    @State private var cameraError = false

    var body: some View {
        ZStack {
            // Live camera feed
            ScannerRepresentable(
                onScan: { code in
                    AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                    path.append(AppRoute.amount(upiID: code))
                },
                isTorchOn: $isTorchOn
            )
            .ignoresSafeArea()

            // Overlay UI
            VStack {
                // Top bar
                HStack {
                    Spacer()
                    Button {
                        isTorchOn.toggle()
                    } label: {
                        Image(systemName: isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                }
                .padding(.top, 16)

                Spacer()

                // Scan-frame guide
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 260, height: 260)

                    // Corner brackets
                    ScanCorners()
                        .stroke(Color(red: 0, green: 0.72, blue: 1), lineWidth: 4)
                        .frame(width: 260, height: 260)
                }

                Spacer()

                // Bottom label
                VStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                    Text("Point camera at a QR code to pay")
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.bottom, 50)
            }
        }
        .navigationTitle("Scan QR")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(red: 0, green: 0.45, blue: 0.85), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Camera Unavailable",
               isPresented: $cameraError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please allow camera access in Settings.")
        }
    }
}

// Corner brackets shape
struct ScanCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let len: CGFloat = 30
        let r: CGFloat   = 10
        var p = Path()
        // top-left
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + len))
        // top-right
        p.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY + r))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))
        // bottom-left
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY - len))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
        p.move(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        // bottom-right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.move(to: CGPoint(x: rect.maxX - len, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))
        return p
    }
}

// MARK: - Screen 2 · Amount Entry

struct AmountScreen: View {
    @Binding var path: [AppRoute]
    let upiID: String
    @ObservedObject var walletManager: WalletManager

    @State private var amount: String = ""
    @State private var shake = false
    @FocusState private var focused: Bool
    @State private var showInsufficientError = false

    private let paytmBlue = Color(red: 0, green: 0.45, blue: 0.85)

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── Header card ───────────────────────────────
                VStack(spacing: 10) {
                    // QR recipient icon
                    ZStack {
                        Circle()
                            .fill(paytmBlue.opacity(0.12))
                            .frame(width: 72, height: 72)
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 30))
                            .foregroundColor(paytmBlue)
                    }

                    Text("Paying To")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(upiID)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 30)
                }
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.88, green: 0.95, blue: 1))

                // ── Amount input ──────────────────────────────
                VStack(spacing: 6) {
                    Text("Enter Amount")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(alignment: .center, spacing: 4) {
                        Text("₹")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(paytmBlue)
                        TextField("0", text: $amount)
                            .font(.system(size: 44, weight: .bold))
                            .keyboardType(.numberPad)
                            .focused($focused)
                            .foregroundColor(.primary)
                            .frame(minWidth: 80)
                            .fixedSize()
                    }
                    .modifier(ShakeEffect(animatableData: shake ? 1 : 0))

                    Divider()
                        .background(paytmBlue)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 32)

                // ── Pay button ────────────────────────────────
                Button {
                    guard !amount.trimmingCharacters(in: .whitespaces).isEmpty,
                          let amountValue = Double(amount), amountValue > 0 else {
                        withAnimation(.default) { shake = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shake = false }
                        return
                    }
                    
                    // Check wallet balance
                    if amountValue > walletManager.balance {
                        showInsufficientError = true
                        return
                    }
                    
                    // Deduct from wallet
                    walletManager.deductFromWallet(amountValue)
                    
                    focused = false
                    AudioServicesPlaySystemSound(1001)
                    path.append(AppRoute.success(upiID: upiID, amount: amount, date: Date()))
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                        Text("Pay  ₹\(amount.isEmpty ? "0" : amount)")
                            .font(.title3.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(paytmBlue)
                    .cornerRadius(14)
                    .padding(.horizontal, 28)
                }
                .padding(.top, 10)

                // ── UPI note ──────────────────────────────────
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                    Text("100% safe & secured · Powered by UPI")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
                .padding(.top, 18)
            }
        }
        .navigationTitle("Enter Amount")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(paytmBlue, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { focused = true }
        .alert("Insufficient Balance", isPresented: $showInsufficientError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You don't have enough balance. Your balance is ₹\(String(format: "%.2f", walletManager.balance))")
        }
    }
}

// Shake animation modifier
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = sin(animatableData * .pi * 4) * 8
        return ProjectionTransform(CGAffineTransform(translationX: t, y: 0))
    }
}

// MARK: - Camera Bridge (UIKit)

struct ScannerRepresentable: UIViewControllerRepresentable {

    let onScan: (String) -> Void
    @Binding var isTorchOn: Bool

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.completion = onScan
        return vc
    }

    func updateUIViewController(_ vc: ScannerViewController, context: Context) {
        vc.setTorch(on: isTorchOn)
    }
}

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var completion: ((String) -> Void)?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasScanned = false  // Reset for new scan
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: device) else { return }
        if captureSession.canAddInput(input) { captureSession.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasScanned,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        hasScanned = true
        captureSession.stopRunning()
        
        // Send immediate scan notification to the recipient
        FirebaseManager.shared.sendQRScanNotification(
            recipientUPI: value,
            scannerName: "Someone"
        )
        
        DispatchQueue.main.async {
            self.completion?(value)
        }
    }
}

// MARK: - Add Money Screen

struct AddMoneyScreen: View {
    @Binding var path: [AppRoute]
    @ObservedObject var walletManager: WalletManager
    @Environment(\.dismiss) var dismiss
    
    @State private var amount: String = ""
    @State private var shake = false
    @State private var showSuccess = false
    @FocusState private var focused: Bool
    
    private let paytmBlue = Color(red: 0, green: 0.45, blue: 0.85)
    private let successGreen = Color(red: 0.13, green: 0.76, blue: 0.37)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                
                // ── Header card ───────────────────────────────
                VStack(spacing: 10) {
                    // Bank icon
                    ZStack {
                        Circle()
                            .fill(successGreen.opacity(0.12))
                            .frame(width: 72, height: 72)
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 30))
                            .foregroundColor(successGreen)
                    }
                    
                    Text("Add Money to Wallet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Quick & Secure")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 30)
                }
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.88, green: 0.95, blue: 1))
                
                // ── Amount input ──────────────────────────────
                VStack(spacing: 6) {
                    Text("Enter Amount")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(alignment: .center, spacing: 4) {
                        Text("₹")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(successGreen)
                        TextField("0", text: $amount)
                            .font(.system(size: 44, weight: .bold))
                            .keyboardType(.numberPad)
                            .focused($focused)
                            .foregroundColor(.primary)
                            .frame(minWidth: 80)
                            .fixedSize()
                    }
                    .modifier(ShakeEffect(animatableData: shake ? 1 : 0))
                    
                    Divider()
                        .background(successGreen)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 32)
                
                // ── Add Money button ────────────────────────────────
                Button {
                    guard !amount.trimmingCharacters(in: .whitespaces).isEmpty,
                          let amountValue = Double(amount), amountValue > 0 else {
                        withAnimation(.default) { shake = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shake = false }
                        return
                    }
                    
                    // Add money to wallet
                    walletManager.addToWallet(amountValue, from: "Bank Transfer")
                    
                    focused = false
                    AudioServicesPlaySystemSound(1001)
                    showSuccess = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        path.removeLast()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title3)
                        Text("Add  ₹\(amount.isEmpty ? "0" : amount)")
                            .font(.title3.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(successGreen)
                    .cornerRadius(14)
                    .padding(.horizontal, 28)
                }
                .padding(.top, 10)
                
                // ── Safe note ──────────────────────────────────
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                    Text("100% safe & secured · Instant Credit")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
                .padding(.top, 18)
            }
        }
        .navigationTitle("Add Money")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(successGreen, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { focused = true }
        .alert("Money Added! 🎉", isPresented: $showSuccess) {
            Button("Done", role: .cancel) {}
        } message: {
            Text("₹\(amount) has been added to your wallet successfully.")
        }
    }
}

// MARK: - Send Message Screen

struct SendMessageScreen: View {
    @Binding var path: [AppRoute]
    let recipientUPI: String
    let amount: Double
    @Environment(\.dismiss) var dismiss
    
    @State private var phoneNumber: String = ""
    @State private var showPhoneInput = false
    @State private var showSuccess = false
    
    private let paytmBlue = Color(red: 0, green: 0.45, blue: 0.85)
    private let successGreen = Color(red: 0.13, green: 0.76, blue: 0.37)
    
    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.98, blue: 0.99).ignoresSafeArea()
            
            VStack(spacing: 24) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.blue)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                VStack(spacing: 16) {
                    Text("Send Message")
                        .font(.title2.bold())
                    
                    Text("Notify the recipient about payment")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    // WhatsApp Button
                    Button {
                        FirebaseManager.shared.sendWhatsAppMessage(
                            phoneNumber: "+919876543210",
                            amount: amount,
                            senderName: "You"
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "message.fill")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("WhatsApp")
                                    .font(.headline)
                                Text("Send via WhatsApp")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundColor(.gray)
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .foregroundColor(.black)
                    }
                    
                    // SMS Button
                    Button {
                        showPhoneInput = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bubble.right.fill")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("SMS")
                                    .font(.headline)
                                Text("Send via Text Message")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundColor(.gray)
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .foregroundColor(.black)
                    }
                    
                    // Push Notification Button
                    Button {
                        FirebaseManager.shared.sendPushNotification(
                            recipientID: String(recipientUPI.split(separator: "@").first ?? ""),
                            amount: amount,
                            senderName: "You"
                        )
                        showSuccess = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            path = []
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.badge.fill")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("App Notification")
                                    .font(.headline)
                                Text("Send in-app notification")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundColor(.gray)
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .foregroundColor(.black)
                    }
                    
                    // Skip Button
                    Button {
                        path = []
                    } label: {
                        Text("Skip for now")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundColor(paytmBlue)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(paytmBlue, lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .alert("Notification Sent! ✅", isPresented: $showSuccess) {
            Button("Done", role: .cancel) {}
        } message: {
            Text("The recipient has been notified about the payment.")
        }
    }
}

// MARK: - Notification History Screen

struct NotificationHistoryScreen: View {
    @ObservedObject var notificationManager: NotificationManager
    @Environment(\.dismiss) var dismiss
    
    private let paytmBlue = Color(red: 0, green: 0.45, blue: 0.85)
    
    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.98, blue: 0.99).ignoresSafeArea()
            
            VStack(spacing: 0) {
                if notificationManager.notifications.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("No Notifications")
                            .font(.title3.bold())
                            .foregroundColor(.gray)
                        Text("Your payment notifications will appear here")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.8))
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(notificationManager.notifications) { notification in
                            NotificationRow(notification: notification)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let id = notificationManager.notifications[index].id
                                notificationManager.removeNotification(id: id)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(paytmBlue, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !notificationManager.notifications.isEmpty {
                    Button("Clear All") {
                        notificationManager.clearAll()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let notification: AppNotification
    
    private var iconName: String {
        switch notification.type {
        case "debit":  return "arrow.up.circle.fill"
        case "credit": return "arrow.down.circle.fill"
        case "scan":   return "qrcode.viewfinder"
        default:       return "bell.fill"
        }
    }
    
    private var iconColor: Color {
        switch notification.type {
        case "debit":  return .red
        case "credit": return .green
        case "scan":   return .orange
        default:       return .blue
        }
    }
    
    private var timeAgo: String {
        let interval = Date().timeIntervalSince(notification.date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM, h:mm a"
        return formatter.string(from: notification.date)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.black)
                
                Text(notification.body)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(3)
                
                if let ref = notification.upiRef {
                    Text("UPI Ref: \(ref)")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
            
            Spacer()
            
            Text(timeAgo)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
