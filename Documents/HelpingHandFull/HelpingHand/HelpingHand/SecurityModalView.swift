//
//  SecurityModalView.swift
//  HelpingHand
//
//  Created by Pranav Khanna on 9/18/26.
//

import SwiftUI

struct SecurityModalView: View {
    let charityName: String
    let charityURL: URL
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Custom Modal
            VStack(spacing: 20) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.green)
                    .padding(.top, 10)
                
                Text("Connecting Securely")
                    .font(.title3.bold())
                
                Text("You are now securely connecting to the official donation page for \(charityName). 100% of your contribution goes directly to their verified relief efforts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                
                VStack(spacing: 12) {
                    // Opens device browser to external site
                    Link(destination: charityURL) {
                        Text("Continue")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.primary)
                            .foregroundColor(Color(UIColor.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    // Dismisses modal
                    Button("Cancel") {
                        isPresented = false
                    }
                    .font(.body.weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 32)
        }
    }
}
