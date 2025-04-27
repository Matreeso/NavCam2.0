import Foundation
 import CoreMotion
 import CoreLocation
 import UIKit
 
 class AltitudeTiltManager: NSObject, ObservableObject, CLLocationManagerDelegate {
     private let altimeter = CMAltimeter()
     private let motionManager = CMMotionManager()
     private let locationManager = CLLocationManager()
 
     @Published var altitude: Double = 0.0
     @Published var pitch: Double = 0.0 // in degrees
     @Published var roll: Double = 0.0 // in degrees
 
     override init() {
         super.init()
         locationManager.delegate = self
         locationManager.requestWhenInUseAuthorization()
         locationManager.startUpdatingLocation()
         startMonitoringAltitude()
         startMonitoringTilt()
     }
 
     private func startMonitoringAltitude() {
         guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
         altimeter.startRelativeAltitudeUpdates(to: .main) { data, error in
             guard let pressureData = data else { return }
             self.altitude = pressureData.relativeAltitude.doubleValue
         }
     }
 
     private func startMonitoringTilt() {
         guard motionManager.isDeviceMotionAvailable else { return }
         motionManager.deviceMotionUpdateInterval = 0.1
         motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
             guard let motion = motion else { return }
 
             // Convert radians to degrees
             let pitchRadians = motion.attitude.pitch
             let rollRadians = motion.attitude.roll
 
             let pitchDegrees: Double
             let rollDegrees: Double
 
             switch UIDevice.current.orientation {
             case .landscapeLeft:
                 pitchDegrees = -rollRadians * 180 / .pi
                 rollDegrees = pitchRadians * 180 / .pi
             case .landscapeRight:
                 pitchDegrees = rollRadians * 180 / .pi
                 rollDegrees = -pitchRadians * 180 / .pi
             case .portraitUpsideDown:
                 pitchDegrees = -pitchRadians * 180 / .pi
                 rollDegrees = -rollRadians * 180 / .pi
             default: // portrait and unknown
                 pitchDegrees = pitchRadians * 180 / .pi
                 rollDegrees = rollRadians * 180 / .pi
             }
 
             self.pitch = pitchDegrees
             self.roll = rollDegrees
 
         }
     }
 }
