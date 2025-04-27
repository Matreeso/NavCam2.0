import SwiftUI
 
 struct AltitudeTiltView: View {
     @StateObject private var manager = AltitudeTiltManager()
 
     var body: some View {
         VStack(spacing: 20) {
             Text("🗻 Altitude & Tilt")
                 .font(.largeTitle)
                 .bold()
 
             Text(String(format: "Altitude: %.2f m", manager.altitude))
                 .font(.title2)
 
             Text(String(format: "Pitch: %.2f°", manager.pitch))
             Text(String(format: "Roll: %.2f°", manager.roll))
         }
         .padding()
     }
 }
