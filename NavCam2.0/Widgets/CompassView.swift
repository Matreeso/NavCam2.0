import SwiftUI
 
 struct CompassView: View {
     @StateObject private var compass = CompassManager()
 
     var body: some View {
         VStack(spacing: 16) {
             Text("🧭 Compass")
                 .font(.largeTitle)
                 .bold()
 
             ZStack {
                 Image(systemName: "circle")
                     .resizable()
                     .frame(width: 200, height: 200)
                     .foregroundColor(.gray)
 
                 Image(systemName: "arrow.up")
                     .resizable()
                     .frame(width: 80, height: 80)
                     .rotationEffect(.degrees(-compass.heading))
                     .foregroundColor(.red)
             }
             .padding()
 
             Text(String(format: "Heading: %.0f°", compass.heading))
                 .font(.title2)
         }
         .padding()
     }
 }
