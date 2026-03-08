//
//  FirebaseManager.swift
//  Master Payment App
//
//  Firebase integration for payment notifications
//

import Foundation
import UserNotifications
import UIKit
import MessageUI

import FirebaseCore
import FirebaseDatabase
import FirebaseMessaging

class FirebaseManager: NSObject, MFMessageComposeViewControllerDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    
    static let shared = FirebaseManager()
    private let database = Database.database().reference()
    
    // MARK: - Initialize Firebase
    func initializeFirebase() {
//        FirebaseApp.configure()
        setupMessaging()
    }
    
    // MARK: - Setup Cloud Messaging
    private func setupMessaging() {
        Messaging.messaging().delegate = self
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    print("✅ Notifications enabled")
                } else if let error = error {
                    print("❌ Notification permission denied: \(error.localizedDescription)")
                }
            }
        }
        
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Send Payment Notification
    func sendPaymentNotification(recipientUPI: String, amount: Double, senderName: String = "Someone") {
        
        let recipientID = recipientUPI.split(separator: "@").first.map(String.init) ?? recipientUPI
        
        let notificationData: [String: Any] = [
            "type": "payment_received",
            "amount": amount,
            "sender": senderName,
            "timestamp": ServerValue.timestamp(),
            "recipientID": recipientID
        ]
        
        database.child("notifications")
            .child(recipientID)
            .childByAutoId()
            .setValue(notificationData) { error, _ in
                
                if let error = error {
                    print("❌ Failed to send notification: \(error.localizedDescription)")
                } else {
                    print("✅ Notification saved in Firebase")
                }
            }
        
        sendPushNotification(recipientID: recipientID, amount: amount, senderName: senderName)
    }
    
    // MARK: - Push Notification
    func sendPushNotification(recipientID: String, amount: Double, senderName: String = "You") {
        
        print("📲 Sending push notification to \(recipientID)")
        
        let content = UNMutableNotificationContent()
        content.title = "Payment Received 🎉"
        content.body = "You received ₹\(String(format: "%.2f", amount)) from \(senderName)"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        
        content.userInfo = [
            "type": "payment_received",
            "amount": amount,
            "sender": senderName,
            "recipientID": recipientID
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Push notification error: \(error.localizedDescription)")
            } else {
                print("✅ Push notification sent")
            }
        }
    }
    
    // MARK: - Store Transaction
    func storeTransaction(
        senderUPI: String,
        recipientUPI: String,
        amount: Double,
        transactionID: String,
        status: String = "completed"
    ) {
        
        let transactionData: [String: Any] = [
            "senderUPI": senderUPI,
            "recipientUPI": recipientUPI,
            "amount": amount,
            "transactionID": transactionID,
            "status": status,
            "timestamp": ServerValue.timestamp()
        ]
        
        database.child("transactions")
            .child(transactionID)
            .setValue(transactionData) { error, _ in
                
                if let error = error {
                    print("❌ Failed to store transaction: \(error.localizedDescription)")
                } else {
                    print("✅ Transaction stored in Firebase")
                }
            }
    }
    
    // MARK: - Fetch Notifications
    func getUserNotifications(userID: String, completion: @escaping ([[String: Any]]) -> Void) {
        
        database.child("notifications")
            .child(userID)
            .observeSingleEvent(of: .value) { snapshot in
                
                var notifications: [[String: Any]] = []
                
                if let values = snapshot.value as? [String: Any] {
                    for (_, value) in values {
                        if let notification = value as? [String: Any] {
                            notifications.append(notification)
                        }
                    }
                }
                
                completion(notifications)
            }
    }
    
    // MARK: - Send SMS
    func sendSMSMessage(phoneNumber: String, amount: Double, senderName: String = "You") {
        
        guard MFMessageComposeViewController.canSendText() else {
            print("❌ SMS not available")
            return
        }
        
        let message = "You received ₹\(String(format: "%.2f", amount)) from \(senderName) via Master Payment App."
        
        print("📱 SMS to \(phoneNumber): \(message)")
        
        // In real implementation, present MFMessageComposeViewController
    }
    
    // MARK: - Send WhatsApp Message
    func sendWhatsAppMessage(phoneNumber: String, amount: Double, senderName: String = "You") {
        
        let message = "You received ₹\(String(format: "%.2f", amount)) from \(senderName) via Master Payment App."
        
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "https://wa.me/\(phoneNumber)?text=\(encodedMessage)"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url) { success in
                if success {
                    print("✅ WhatsApp opened")
                } else {
                    print("❌ WhatsApp not installed")
                }
            }
        }
    }
    
    // MARK: - FCM Token
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        
        if let token = fcmToken {
            print("🔑 FCM Token: \(token)")
            
            UserDefaults.standard.set(token, forKey: "fcmToken")
            
            if let uid = UserDefaults.standard.string(forKey: "userID") {
                Database.database()
                    .reference()
                    .child("users")
                    .child(uid)
                    .child("fcmToken")
                    .setValue(token)
            }
        }
    }
    
    // MARK: - Foreground Notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("📲 Notification received: \(notification.request.content.body)")
        completionHandler([.banner, .sound, .badge])
    }
    
    // MARK: - Tap Notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("🎉 User tapped notification")
        completionHandler()
    }
    
    // MARK: - SMS Delegate
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        
        switch result {
        case .cancelled:
            print("❌ SMS cancelled")
        case .failed:
            print("❌ SMS failed")
        case .sent:
            print("✅ SMS sent")
        @unknown default:
            break
        }
        
        controller.dismiss(animated: true)
    }
}
