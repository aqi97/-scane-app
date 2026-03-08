//
//  scane_appApp.swift
//  scane app
//
//  Created by sheikh abu mohamed on 08/03/26.
//

import SwiftUI

@main
struct scane_appApp: App {
    init() {
        // Initialize Firebase when app launches
        FirebaseManager.shared.initializeFirebase()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
