import CoreLocation
 import Foundation
 import SwiftUI
 
 class CompassManager: NSObject, ObservableObject, CLLocationManagerDelegate {
     private let locationManager = CLLocationManager()
 
     @Published var heading: Double = 0.0 // in degrees
 
     override init() {
         super.init()
         locationManager.delegate = self
         locationManager.headingFilter = 1 // Update if change is 1 degree
         locationManager.requestWhenInUseAuthorization()
 
         if CLLocationManager.headingAvailable() {
             locationManager.startUpdatingHeading()
         }
     }
 
     func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
         // Use magneticHeading or trueHeading
         self.heading = newHeading.magneticHeading
     }
 }
