import SwiftUI
import MapLibre

struct MapLibreView: UIViewRepresentable {
    
    func makeUIView(context: Context) -> MLNMapView {
        let styleURL = URL(string: "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json")
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true
        
        // Assign the coordinator as the delegate to know when the style finishes loading
        mapView.delegate = context.coordinator
        
        return mapView
    }
    
    func updateUIView(_ uiView: MLNMapView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: MapLibreView
        
        init(_ parent: MapLibreView) {
            self.parent = parent
        }
        
        // Ensure the base style is fully loaded before drawing custom layers
        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            addCrisisZone(to: style)
        }
        
        private func addCrisisZone(to style: MLNStyle) {
            // 1. Define the polygon coordinates (e.g., bounding box for the crisis area)
            var coordinates = [
                CLLocationCoordinate2D(latitude: 32.0, longitude: 34.0),
                CLLocationCoordinate2D(latitude: 32.0, longitude: 35.0),
                CLLocationCoordinate2D(latitude: 31.0, longitude: 35.0),
                CLLocationCoordinate2D(latitude: 31.0, longitude: 34.0)
            ]
            
            // 2. Create the shape and add it as a data source
            let polygon = MLNPolygon(coordinates: &coordinates, count: UInt(coordinates.count))
            let source = MLNShapeSource(identifier: "crisis-zone-source", shape: polygon, options: nil)
            style.addSource(source)
            
            // 3. Create a fill layer to color it based on severity
            let fillLayer = MLNFillStyleLayer(identifier: "crisis-zone-fill", source: source)
            
            // 4. Map the Level 5 Very High severity to a muted deep red
            fillLayer.fillColor = NSExpression(forConstantValue: UIColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 0.4))
            fillLayer.fillOutlineColor = NSExpression(forConstantValue: UIColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 0.8))
            
            style.addLayer(fillLayer)
        }
    }
}
