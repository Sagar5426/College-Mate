//
//  Gradient+Extension.swift
//  College Mate
//
//  Created by Sagar Jangra on 12/10/2025.
//

import SwiftUI

extension LinearGradient {
    /// A reusable linear gradient used as the app background.
    static var appBackground: LinearGradient {
        LinearGradient(
            colors: [.gray.opacity(0.1), .black.opacity(0.1), .gray.opacity(0.07)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

extension View {
    /// Applies the app's background gradient and ignores safe areas.
    func appBackground() -> some View {
        self.background(LinearGradient.appBackground)
            .ignoresSafeArea()
    }
}
