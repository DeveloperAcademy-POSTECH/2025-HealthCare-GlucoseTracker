//
//  ContentView.swift
//  GlucoseTracker
//
//  Created by taeni on 9/2/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            HistoryView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("History")
                }
            
            ReportView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Report")
                }
            
            TestView()
                .tabItem {
                    Image(systemName: "testtube.2")
                    Text("Test")
                }
        }
        .accentColor(.accentColor)
    }
}

#Preview {
    ContentView()
}
