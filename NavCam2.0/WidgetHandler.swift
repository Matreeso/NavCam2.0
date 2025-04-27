//
//  WidgetHandler.swift
//  NavCam2.0
//
//  One-stop “dashboard” file.
//  • Defines every widget (altitude-tilt, compass, pitch, roll, speed, g-force, weather, ETA …)
//  • Gives each widget its own rounded-rectangle container
//  • Exposes a drop-reorderable `WidgetDashboard` you can embed anywhere
//
/*
import SwiftUI
import CoreMotion
import CoreLocation
import Combine
import AVFoundation
import WeatherKit

// MARK: -- Widget taxonomy -----------------------------------------------------

// MARK: -- Widget taxonomy -----------------------------------------------------

enum WidgetKind: String, CaseIterable, Identifiable {
    case altitudeTilt = "Altitude & Tilt"
    case compass      = "Compass"
    case pitch        = "Pitch"
    case roll         = "Roll"
    case speed        = "Speed"
    case gForce       = "G-Force"
    case camera       = "Camera"
    case weather      = "Weather"
    case eta          = "ETA"

    var id: String { rawValue }
    var emoji: String {
        switch self {
        case .altitudeTilt: return "🗻"
        case .compass:      return "🧭"
        case .pitch:        return "📐"
        case .roll:         return "📏"
        case .speed:        return "🛣️"
        case .gForce:       return "📱"
        case .camera:       return "🎥"
        case .weather:      return "☀️"
        case .eta:          return "⌛️"
        }
    }
}

// MARK: -- Generic bordered container ----------------------------------------

struct WidgetBox<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label   = label
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundColor(.textSecondary)
            content
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.colorCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.colorBorder, lineWidth: 1)
        )
    }
}

// MARK: -- Sensor managers (lightweight / shared) -----------------------------

final class AltitudeTiltManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let altimeter  = CMAltimeter()
    private let motion     = CMMotionManager()
    private let location   = CLLocationManager()

    @Published var altitude: Double = 0        // metres
    @Published var pitch:    Double = 0        // °
    @Published var roll:     Double = 0        // °

    override init() {
        super.init()
        location.requestWhenInUseAuthorization()
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
                self?.altitude = data?.relativeAltitude.doubleValue ?? 0
            }
        }
        motion.deviceMotionUpdateInterval = 1 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let a = data?.attitude else { return }
            self?.pitch = a.pitch * 180 / .pi
            self?.roll  = a.roll  * 180 / .pi
        }
    }
}

final class CompassManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let location = CLLocationManager()
    @Published var heading: Double = 0
    override init() {
        super.init()
        location.delegate = self
        location.headingFilter = 1
        location.requestWhenInUseAuthorization()
        if CLLocationManager.headingAvailable() { location.startUpdatingHeading() }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.magneticHeading
    }
}

final class MotionManager: ObservableObject {
    private let motion = CMMotionManager()
    @Published var g: Double = 0
    init() {
        motion.accelerometerUpdateInterval = 1 / 30
        motion.startAccelerometerUpdates(to: .main) { [weak self] d, _ in
            guard let a = d?.acceleration else { return }
            self?.g = sqrt(a.x*a.x + a.y*a.y + a.z*a.z)
        }
    }
}

final class SpeedManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let location = CLLocationManager()
    @Published var speedMps: Double = 0
    override init() {
        super.init()
        location.delegate = self
        location.activityType = .automotiveNavigation
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.requestWhenInUseAuthorization()
        location.startUpdatingLocation()
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        speedMps = locs.last?.speed ?? 0
    }
}

// MARK: -- Weather manager (current location) ----------------------------

@MainActor
final class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let service = WeatherService.shared
    private let location = CLLocationManager()

    @Published var temperatureF: Double = 0
    @Published var condition: WeatherCondition = .clear
    @Published var symbolName: String = "sun.max"

    override init() {
        super.init()
        location.delegate = self
        location.requestWhenInUseAuthorization()
        location.startUpdatingLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.last else { return }
        Task { @MainActor in
            do {
                let weather = try await service.weather(for: loc)
                temperatureF = weather.currentWeather.temperature.converted(to: .fahrenheit).value
                condition     = weather.currentWeather.condition
                symbolName    = weather.currentWeather.symbolName
            } catch {
                print("Weather error:", error)
            }
        }
    }

    /// Quick emoji based on condition + day/night
    func emoji(for condition: WeatherCondition, isDay: Bool) -> String {
        switch condition {
        case .clear, .mostlyClear, .sunFlurries, .sunShowers:
            return isDay ? "☀️" : "🌕"
        case .partlyCloudy, .mostlyCloudy, .cloudy:
            return isDay ? "⛅️" : "☁️"
        case .rain, .heavyRain, .freezingRain, .drizzle, .freezingDrizzle:
            return "🌧️"
        case .isolatedThunderstorms, .scatteredThunderstorms, .thunderstorms:
            return "⛈"
        case .snow, .heavySnow, .blizzard, .flurries, .sleet, .hail:
            return "❄️"
        case .foggy, .haze:
            return "🌫"
        case .hurricane, .tropicalStorm:
            return "🌀"
        default:
            return "🌡"
        }
    }
}

// MARK: -- Individual widget views -------------------------------------------

struct AltitudeTiltWidget: View {
    @StateObject private var m = AltitudeTiltManager()
    var body: some View {
        WidgetBox("🗻 Alt & Tilt") {
            VStack {
                Text(String(format: "%.0f m", m.altitude))
                Text(String(format: "Pitch %.0f°", m.pitch))
                Text(String(format: "Roll  %.0f°", m.roll))
            }.font(.caption)
        }
    }
}

struct CompassWidget: View {
    @StateObject private var c = CompassManager()
    var body: some View {
        WidgetBox("🧭 Compass") {
            VStack {
                Image(systemName: "location.north.fill")
                    .resizable().scaledToFit()
                    .frame(width: 34, height: 34)
                    .rotationEffect(.degrees(-c.heading))
                Text(String(format: "%.0f°", c.heading))
            }
        }
    }
}

struct PitchWidget: View {
    @StateObject private var m = AltitudeTiltManager()
    var body: some View {
        WidgetBox("📐 Pitch") {
            Text(String(format: "%.1f°", m.pitch))
                .font(.title.bold())
        }
    }
}

struct RollWidget: View {
    @StateObject private var m = AltitudeTiltManager()
    var body: some View {
        WidgetBox("📏 Roll") {
            Text(String(format: "%.1f°", m.roll))
                .font(.title.bold())
        }
    }
}

struct SpeedWidget: View {
    @StateObject private var s = SpeedManager()
    var body: some View {
        WidgetBox("🛣️ Speed") {
            Text(String(format: "%.0f mph", s.speedMps * 2.23694))
                .font(.title2)
                .foregroundColor(.accentTeal)
        }
    }
}

struct GForceWidget: View {
    @StateObject private var m = MotionManager()
    var body: some View {
        WidgetBox("📱 G-Force") {
            Text(String(format: "%.2f g", m.g))
                .font(.title2.bold())
                .foregroundColor(m.g > 2.5 ? .accentRed : .textPrimary)
        }
    }
}

// MARK: - HUD overlay used inside CameraWidget

struct HUDOverlay: View {
    @ObservedObject private var drive = DriveManager.shared
    let isRecording: Bool

    var body: some View {
        HStack(spacing: 24) {
            VStack {
                Image(systemName: isRecording ? "circle.fill" : "pause.circle")
                    .font(.title2)
                    .foregroundColor(Color("AccentRed"))
            }
            if drive.uploadProgress > 0 && drive.uploadProgress < 1 {
                ProgressView(value: drive.uploadProgress)
                    .frame(width: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

struct CameraWidget: View {
    @EnvironmentObject var recorder: SegmentRecorder
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        WidgetBox("🎥 Camera") {
            ZStack {
                // Live camera feed
                Preview(session: recorder.session)
                    .scaledToFill()
                    .clipped()

                // HUD anchored to bottom
                VStack {
                    Spacer()
                    HUD
                        .padding(.bottom, 4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .aspectRatio(1, contentMode: .fit)
            .onAppear { startTimer() }
            .onDisappear { timer?.invalidate() }
            .onChange(of: recorder.isRecording) { oldValue, newValue in
                if newValue {
                    elapsed = 0
                    startTimer()
                } else {
                    timer?.invalidate()
                }
            }
        }
    }

    private var HUD: some View {
        HStack(spacing: 24) {
            Button(action: { recorder.toggle() }) {
                Image(systemName: recorder.isRecording ? "stop.fill" : "record.circle")
                    .font(.title2)
                    .foregroundColor(.accentRed)
            }

            Text(timeString(from: elapsed))
                .font(.title3.monospacedDigit())
                .bold()

            if DriveManager.shared.uploadProgress > 0 &&
               DriveManager.shared.uploadProgress < 1 {
                ProgressView(value: DriveManager.shared.uploadProgress)
                    .frame(width: 60)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func startTimer() {
        timer?.invalidate()
        guard recorder.isRecording else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsed += 1
        }
    }

    private func timeString(from seconds: TimeInterval) -> String {
        let s = Int(seconds) % 60
        let m = Int(seconds) / 60
        return String(format: "%02d:%02d", m, s)
    }

    /// Local UIViewRepresentable so we don't depend on ContentView's definition.
    struct Preview: UIViewRepresentable {
        let session: AVCaptureSession

        func makeUIView(context: Context) -> UIView {
            let view = UIView()
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(layer)
            return view
        }

        func updateUIView(_ uiView: UIView, context: Context) {
            guard let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer else { return }
            layer.frame = uiView.bounds
            if let connection = layer.connection {
                let orientation = UIApplication.shared.connectedScenes
                    .compactMap { ($0 as? UIWindowScene)?.interfaceOrientation }
                    .first ?? .portrait
                let angle: CGFloat = {
                    switch orientation {
                    case .portrait: return 0
                    case .landscapeLeft: return 270
                    case .landscapeRight: return 90
                    case .portraitUpsideDown: return 180
                    default: return 0
                    }
                }()
                if connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
            }
        }
    }
}

/// *Placeholder* – swap in your own weather service call.
struct WeatherWidget: View {
    @StateObject private var w = WeatherManager()

    var body: some View {
        let isDay = Calendar.current.component(.hour, from: Date()) < 18
        WidgetBox("\(w.emoji(for: w.condition, isDay: isDay)) Weather") {
            VStack(spacing: 4) {
                Text(String(format: "%.0f° F", w.temperatureF))
                    .font(.title)
                Text(w.condition.description.capitalized)
                    .font(.caption)
            }
        }
    }
}

/// *Placeholder* – feed your ETA calculation here.
struct ETAWidget: View {
    @State private var eta = "--:--"
    var body: some View {
        WidgetBox("⌛️ ETA") {
            Text(eta).font(.largeTitle.weight(.bold))
        }
    }
}

// MARK: -- Factory helper -----------------------------------------------------

@ViewBuilder
func widgetView(for kind: WidgetKind) -> some View {
    switch kind {
    case .altitudeTilt: AltitudeTiltWidget()
    case .compass:      CompassWidget()
    case .pitch:        PitchWidget()
    case .roll:         RollWidget()
    case .speed:        SpeedWidget()
    case .gForce:       GForceWidget()
    case .camera:       CameraWidget()
    case .weather:      WeatherWidget()
    case .eta:          ETAWidget()
    }
}

// MARK: -- Dashboard grid (drag-and-drop reorderable) ------------------------

// MARK: -- Conditional view modifier for drag/disable logic

extension View {
    @ViewBuilder func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content,
        else elseTransform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            elseTransform(self)
        }
    }
}

struct WidgetDashboard: View {
    @State private var layout: [WidgetKind] = [
        .weather, .camera, .compass, .speed,
        .altitudeTilt, .pitch, .roll, .eta
    ]
    @State private var editMode: EditMode = .inactive

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let portraitSide = (geo.size.width - 16 * 3) / 2   // two columns, spacing & padding
            let landscapeSide = geo.size.height * 0.8          // already matches camera
            let side = isLandscape ? landscapeSide : portraitSide

            if isLandscape {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(layout, id: \.self) { kind in
                            // common modifiers
                            let base = widgetView(for: kind)
                                .frame(width: side, height: side)
                                .overlay(
                                    editMode == .active
                                        ? RoundedRectangle(cornerRadius: 14)
                                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                        : nil
                                )

                            if kind == .camera && editMode != .active {
                                base
                            } else {
                                base
                                    .onDrag { NSItemProvider(object: kind.rawValue as NSString) }
                                    .disabled(editMode != .active)
                                    .onDrop(of: [.text], delegate: MoveDelegate(item: kind, list: $layout))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 16
                    ) {
                        ForEach(layout, id: \.self) { kind in
                            // common modifiers
                            let base = widgetView(for: kind)
                                .frame(width: side, height: side)
                                .overlay(
                                    editMode == .active
                                        ? RoundedRectangle(cornerRadius: 14)
                                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                        : nil
                                )

                            if kind == .camera && editMode != .active {
                                base
                            } else {
                                base
                                    .onDrag { NSItemProvider(object: kind.rawValue as NSString) }
                                    .disabled(editMode != .active)
                                    .onDrop(of: [.text], delegate: MoveDelegate(item: kind, list: $layout))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .environment(\.editMode, $editMode)
        .toolbar {
            Button(editMode == .active ? "Done" : "Edit") {
                withAnimation {
                    editMode = (editMode == .active ? .inactive : .active)
                }
            }
        }
    }
}

/// Simple `DropDelegate` that lets us reorder `layout` by dragging widgets.
private struct MoveDelegate: DropDelegate {
    let item: WidgetKind
    @Binding var list: [WidgetKind]

    func performDrop(info: DropInfo) -> Bool { true }

    func dropEntered(info: DropInfo) {
        guard
            let fromName = info.itemProviders(for: [.text]).first?.suggestedName,
            let fromKind = WidgetKind(rawValue: fromName),
            fromKind != item,
            let fromIndex = list.firstIndex(of: fromKind),
            let toIndex   = list.firstIndex(of: item)
        else { return }

        withAnimation {
            list.move(fromOffsets: IndexSet(integer: fromIndex),
                      toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
}

// MARK: -- Preview ------------------------------------------------------------

#Preview {
    WidgetDashboard()
}
*/
