//
//  HomeView.swift
//  GlucoseTracker
//
//  Created by taeni on 9/9/25.
//

import SwiftUI

struct HomeView: View {
    
    @State private var showWebView = false
    
    var body: some View {
        VStack {
            Button("개인정보정책 URL이동") {
                showWebView = true
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .fullScreenCover(isPresented: $showWebView) {
            SafariView(url: URLConstants.naverURL)
                .ignoresSafeArea()
        }
    }
}

#Preview {
    HomeView()
}
