//
//  ContentView.swift
//  Svangur
//
//  Created by dharmani on 04-05-2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "fork.knife.circle.fill")
                .imageScale(.large)
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Svangur")
                .font(.largeTitle.bold())

            Button("View Profile") {
                router.navigate(to: .profile(userId: "user-1"))
            }
            .buttonStyle(.borderedProminent)

            Button("Open Dashboard") {
                router.navigate(to: .dashboard)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

#Preview("Home") {
    NavigationStack {
        ContentView()
    }
    .environmentObject(AppRouter())
}
