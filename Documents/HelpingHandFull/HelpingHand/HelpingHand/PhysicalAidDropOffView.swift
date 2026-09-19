import SwiftUI
import MapKit

struct PhysicalAidDropOffView: View {
    let requirements: [PhysicalAidRequirement] // Pulled from your backend
    @Environment(\.dismiss) var dismiss
    
    // Sample drop-off point for the map
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mini Map showing drop-off locations
                Map(position: $cameraPosition) {
                    Marker("Red Cross Logistics Center", coordinate: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431))
                        .tint(Color.blue)
                }
                .frame(height: 250)
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                
                List {
                    Section(header: Text("Accepted Items")) {
                        HStack(spacing: 12) {
                            Image(systemName: "cross.case.fill")
                                .foregroundStyle(Color(red: 0.85, green: 0.42, blue: 0.32))
                            VStack(alignment: .leading) {
                                Text("Medical Supplies")
                                    .font(.headline)
                                Text("Bandages, antiseptics, sterile gloves.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "tshirt.fill")
                                .foregroundStyle(Color.blue)
                            VStack(alignment: .leading) {
                                Text("Winter Clothing")
                                    .font(.headline)
                                Text("New or gently used coats and blankets.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Section(header: Text("Drop-Off Details")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Verified NGO: Global Relief Partners")
                                .font(.subheadline.bold())
                            Text("Operating Hours: 8:00 AM - 6:00 PM")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Button(action: { /* Trigger Apple Maps routing */ }) {
                                Text("Get Directions")
                                    .font(.body.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.primary.opacity(0.06))
                                    .foregroundColor(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.top, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Contribute Supplies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(Color.primary)
                }
            }
        }
    }
}
