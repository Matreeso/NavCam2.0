import SwiftUI
 
 struct PitchView: View {
     @StateObject private var manager: AltitudeTiltManager = AltitudeTiltManager()
 
     var fillPercent: Double {
         min(max((manager.pitch + 90) / 180, 0), 1)
     }
 
     var body: some View {
         VStack(spacing: 12) {
             Text("📐 Pitch")
                 .font(.headline)
                 .bold()
 
             ZStack {
                 Circle()
                     .stroke(lineWidth: 20)
                     .opacity(0.3)
                     .foregroundColor(.blue)
 
                 Circle()
                     .trim(from: 0, to: fillPercent)
                     .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                     .foregroundColor(.blue)
                     .rotationEffect(.degrees(-90))
                     .animation(.easeOut(duration: 0.2), value: fillPercent)
 
                 Text(String(format: "%.1f°", manager.pitch))
                     .font(.title)
             }
             .frame(width: 150, height: 150)
         }
         .padding()
         .frame(maxWidth: .infinity)
         .cornerRadius(12)
     }
 }

