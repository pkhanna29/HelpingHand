import SwiftUI

struct ContentView: View {
    // You can restore your @State variables (like activeSheet) here as you build out the button logic
    
    var body: some View {
        ZStack {
            // 1. The custom black-and-white map base
            MapLibreView()
                .ignoresSafeArea()
            
            // 2. The floating UI overlay
            VStack {
                // Top Navigation: My Impact Shortcut
                HStack {
                    Spacer()
                    Button(action: {
                        // Action to open Saved regions
                    }) {
                        Image(systemName: "bookmark")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Bottom Navigation Pill
                HStack(spacing: 40) {
                    Button(action: {}) {
                        Image(systemName: "info.circle") // Our Purpose
                    }
                    Button(action: {}) {
                        Image(systemName: "location.north.circle.fill") // Explore Map
                    }
                    Button(action: {}) {
                        Image(systemName: "book") // How Itßß√∫ Works
                    }
                }
                .font(.title2)
                .foregroundColor(.primary)
                .padding(.vertical, 16)
                .padding(.horizontal, 32)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            }
            .padding(.bottom, 34) // Keeps the pill safely above the iOS home indicator
        }
    }
}

#Preview {
    ContentView()
}
