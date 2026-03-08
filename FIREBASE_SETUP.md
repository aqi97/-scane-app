# Firebase Payment Notification Setup Guide

## Overview
Your payment app now sends Firebase notifications when a payment is received. When a user scans a QR code and makes a payment, the recipient receives an instant notification: **"You received ₹X from [Sender Name]"**

---

## 📋 Setup Steps

### Step 1: Install Firebase CocoaPods
Open Terminal in your project folder and run:

```bash
cd "/Users/sheikhabumohamed/Downloads/scane app"
pod install
```

This will install all Firebase dependencies (Database, Messaging, Analytics).

---

### Step 2: Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"**
3. Name it: **"Master Payment App"** (or your choice)
4. Enable Google Analytics (optional)
5. Click **"Create Project"**

---

### Step 3: Register Your iOS App
1. In Firebase Console, click the iOS icon (⊕)
2. Enter **Bundle ID**: `com.sheikhabumohamed.masterPaymentApp` (match your Xcode settings)
3. Download the **`GoogleService-Info.plist`** file
4. **Important**: Drag and drop this file into Xcode → select "Master Payment App" target
5. Click **"Finish"**

---

### Step 4: Enable Real-time Database
1. In Firebase Console, go to **"Realtime Database"** (in left sidebar)
2. Click **"Create Database"**
3. Choose region (close to your users)
4. Start in **"Test mode"** (for development)
5. Click **"Enable"**

---

### Step 5: Enable Cloud Messaging
1. Go to **"Cloud Messaging"** in Firebase Console
2. Look for the **"Server API Key"** (you'll use this to send remote notifications)
3. Save this key securely

---

### Step 6: Update Xcode Project Settings
1. Open your project in Xcode
2. Select the **"Master Payment App"** target
3. Go to **"Signing & Capabilities"**
4. Click **"+ Capability"**
5. Search for and add: **"Push Notifications"**

---

## 🔔 How It Works

### Payment Flow with Firebase:
```
1. User scans QR code → AmountScreen shows
2. User enters amount and pays
3. PaymentSuccessViewController is shown
4. 🔥 Firebase sends notification to recipient: "You received ₹X"
5. Notification is stored in Firebase Realtime Database
6. Recipient sees notification in their notification center
```

### Data Structure in Firebase:
```
notifications/
  ├── aqi97/                    (recipient user ID)
  │   ├── -notification1/
  │   │   ├── type: "payment_received"
  │   │   ├── amount: 500.0
  │   │   ├── sender: "You"
  │   │   └── timestamp: 1683734400000
  │   └── -notification2/
  │       └── ...
  └── other_user/
      └── ...

transactions/
  ├── 123456789012/
  │   ├── senderUPI: "user@upi"
  │   ├── recipientUPI: "aqi97@upi"
  │   ├── amount: 500.0
  │   ├── status: "completed"
  │   └── timestamp: 1683734400000
  └── ...
```

---

## 🧪 Testing Notifications

### Local Notifications (for testing):
The app sends local notifications immediately (visible on device).
No need for actual Firebase setup during development!

### To test:
1. Build and run the app on your iPhone or simulator
2. Scan a QR code and complete a payment
3. You should see: **"Payment Received! 🎉 You received ₹X from Someone"**

---

## 📝 Code Integration

### Payment Success Notification:
```swift
// Automatically called when payment completes
FirebaseManager.shared.sendPaymentNotification(
    recipientUPI: "aqi97@upi",      // Recipient's UPI ID
    amount: 500.0,                   // Amount paid
    senderName: "You"                // Payer's name
)
```

### Store Transaction History:
```swift
// Automatically called when payment completes
FirebaseManager.shared.storeTransaction(
    senderUPI: "user@upi",
    recipientUPI: "aqi97@upi",
    amount: 500.0,
    transactionID: "123456789012",
    status: "completed"
)
```

---

## 🔐 Firebase Security Rules

For development, use **Test Mode**. For production, update your rules:

```json
{
  "rules": {
    "notifications": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "root.child('users').child($uid).exists()"
      }
    },
    "transactions": {
      ".read": true,
      ".write": "root.child('users').child(auth.uid).exists()"
    }
  }
}
```

---

## ✅ File Changes Made

1. **FirebaseManager.swift** - New file
   - Handles Firebase initialization
   - Sends payment notifications
   - Stores transactions
   - Manages local notifications

2. **scane_appApp.swift** - Updated
   - Initializes Firebase on app launch

3. **PaymentSuccessViewController.swift** - Updated
   - Sends notification when payment succeeds
   - Stores transaction in Firebase

4. **Podfile** - New file
   - Specifies Firebase dependencies

---

## 🆘 Troubleshooting

### Error: "Firebase module not found"
- Run `pod install` again
- Close Xcode and open the `.xcworkspace` file instead of `.xcodeproj`

### Error: "GoogleService-Info.plist not found"
- Download it again from Firebase Console
- Make sure it's added to Xcode with "Master Payment App" target selected

### Notifications not appearing
- Check notification permissions: Settings → Master Payment App → Notifications
- For simulator: Xcode may not show notifications. Test on real device.

### Transaction not saving to Firebase
- Make sure Realtime Database is created
- Check Firebase rules aren't blocking writes

---

## 📱 Next Steps (Optional)

1. **Add user authentication** - Store sender's name instead of "You"
2. **Create notification history screen** - Let users see all received payments
3. **Add remote notifications** - Send notifications via Firebase Cloud Messaging
4. **Implement UPI user profiles** - Store user info in Firebase
5. **Add transaction receipts** - Store detailed payment info in Firestore

---

For more help: [Firebase iOS Documentation](https://firebase.google.com/docs/ios/setup)
