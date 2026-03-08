//
//  ContentView.swift
//  scane app
//
//  Created by sheikh abu mohamed on 08/03/26.
//
//  3-screen flow:
//  1. ScannerScreen  – camera QR scanner
//  2. AmountScreen   – enter payment amount
//  3. SuccessScreen  – Paytm-style receipt (from PaymentSuccessViewController.swift)
//

import SwiftUI
import AVFoundation
import AudioToolbox

// MARK: - App Root

struct ContentView: View {

    /// Drives the full navigation stack
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScannerScreen(path: $path)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .amount(let upiID):
                        AmountScreen(path: $path, upiID: upiID)
                    case .success(let upiID, let amount, let date):
                        PaymentSuccessView(upiID: upiID, amount: amount, paymentDate: date)
                            .navigationBarHidden(true)
                    }
                }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PaymentDoneNotification"))) { _ in
            // Pop all the way back to the scanner
            path = NavigationPath()
        }
    }
}

// MARK: - Navigation Routes

enum AppRoute: Hashable {
    case amount(upiID: String)
    case success(upiID: String, amount: String, date: Date)
}

// MARK: - Screen 1 · QR Scanner

struct ScannerScreen: View {

    @Binding var path: NavigationPath
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

    @Binding var path: NavigationPath
    let upiID: String

    @State private var amount: String = ""
    @State private var shake = false
    @FocusState private var focused: Bool

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
                          let _ = Double(amount), Double(amount)! > 0 else {
                        withAnimation(.default) { shake = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shake = false }
                        return
                    }
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
        DispatchQueue.main.async {
            self.completion?(value)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
