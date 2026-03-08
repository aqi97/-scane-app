# Scane App - UPI Payment QR Scanner

A modern iOS application for scanning QR codes and processing UPI payments with a professional receipt UI.

## Features

✨ **QR Code Scanner**
- Live camera feed with QR code detection
- Torch (flashlight) toggle
- Haptic feedback on successful scan
- Visual scanning guide with corner brackets

💰 **Payment Flow**
- Scan UPI QR codes
- Enter payment amount
- Real-time validation
- Sound feedback on success

📱 **Success Receipt**
- Professional Paytm-style receipt design
- Dynamic transaction details
- Current date/time and reference number
- Smooth animations and transitions

## Technology Stack

- **Swift UI** - Modern declarative UI framework
- **UIKit** - Native camera and payment receipt implementation
- **AVFoundation** - Camera and QR code scanning
- **AudioToolbox** - Sound and haptic feedback

## Project Structure

```
scane app/
├── ContentView.swift              # Main navigation & 3-screen flow
│   ├── ScannerScreen             # QR code scanner
│   ├── AmountScreen              # Payment amount entry
│   └── AppRoute                  # Navigation routes
├── PaymentSuccessViewController.swift  # Receipt screen (UIKit)
├── scane_appApp.swift            # App entry point
└── Assets/                        # App icons and colors
```

## How It Works

### 1. **ScannerScreen** 📷
- Displays live camera feed
- Scans QR codes in real-time
- Shows scanning guide overlay
- Extracts UPI ID from QR code

### 2. **AmountScreen** 💵
- Shows recipient UPI ID
- User enters payment amount
- Input validation
- Shake animation on invalid input

### 3. **PaymentSuccessView** ✅
- Professional receipt display
- Shows amount, UPI ID, date/time
- Unique reference number
- Success sounds and vibration
- Done button returns to scanner

## Installation & Setup

### Requirements
- Xcode 14+
- iOS 14+
- Apple Developer Account (for real device testing)

### Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/scane-app.git
   cd "scane app"
   ```

2. **Open in Xcode**
   ```bash
   open "scane app.xcodeproj"
   ```

3. **Configure signing**
   - Select the project in Xcode
   - Go to Signing & Capabilities
   - Select your development team

4. **Run the app**
   - Select simulator or device
   - Press Cmd + R to run

## Features in Detail

### QR Scanner
- Uses `AVCaptureSession` for real-time scanning
- Torch control for dark environments
- Automatic haptic feedback

### Payment Amount Entry
- Validates positive numbers only
- Shake animation feedback
- Real-time amount display

### Receipt Screen
- Dynamic data from payment flow
- Current timestamp automatically captured
- Unique reference ID generation
- Success sound (1577 system sound)
- Haptic vibration feedback

## Color Palette

- **Primary Blue**: `rgb(0, 115, 217)` - Paytm inspired
- **Success Green**: `rgb(33, 194, 94)` - Transaction success
- **Light Blue**: `rgb(224, 242, 254)` - Background accents
- **Divider Gray**: `rgb(229, 229, 229)` - Separators

## Known Limitations

- QR codes must contain valid text data
- Currently accepts any text as UPI ID (no validation)
- Amount input limited to numeric values
- No actual payment processing (demo only)

## Future Enhancements

- [ ] UPI ID format validation
- [ ] Multiple payment gateway integration
- [ ] Transaction history storage
- [ ] Receipt sharing/export
- [ ] Dark mode support
- [ ] Biometric authentication
- [ ] Multiple language support

## Contributing

Feel free to fork this repository and submit pull requests for any improvements.

## License

MIT License - feel free to use this project as reference

## Support

For issues and questions, please create an issue in the repository.

---

**Built with ❤️ for iOS developers**
