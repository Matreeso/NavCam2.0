import CoreMotion
 import SwiftUI
 import Combine
 
 class MotionManager: ObservableObject {
     private var motionManager = CMMotionManager()
     private var timer: Timer?
 
     @Published var x: Double = 0.0
     @Published var y: Double = 0.0
     @Published var z: Double = 0.0
     @Published var gForce: Double = 0.0
 
     init() {
         startUpdates()
     }
 
     func startUpdates() {
         guard motionManager.isAccelerometerAvailable else { return }
         motionManager.accelerometerUpdateInterval = 0.1
 
         motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
             guard let self = self, let acceleration = data?.acceleration else { return }
 
             self.x = acceleration.x
             self.y = acceleration.y
             self.z = acceleration.z
 
             // Calculate G-force
             self.gForce = sqrt(acceleration.x * acceleration.x +
                                acceleration.y * acceleration.y +
                                acceleration.z * acceleration.z)
         }
     }
 
     func stopUpdates() {
         motionManager.stopAccelerometerUpdates()
     }
 }
