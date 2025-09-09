//
//  LoadingView.swift
//  GlucoseTracker
//
//  Created by taeni on 9/9/25.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
        }
        .padding()
    }
}

#Preview {
    LoadingView()
}
