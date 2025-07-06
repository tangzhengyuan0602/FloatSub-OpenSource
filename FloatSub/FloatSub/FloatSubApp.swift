//
//  FloatSubApp.swift
//  FloatSub
//
//  Created by ByteDance on 7/5/25.
//

import SwiftUI

struct ViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ContentView {
        return ContentView()
    }

    func updateUIViewController(_ uiViewController: ContentView, context: Context) {
        // No update needed
    }
}

@main
struct FloatSubApp: App {
    var body: some Scene {
        WindowGroup {
            ViewControllerRepresentable()
        }
    }
}


