//
//  ContentView.swift
//  NavCam2.0
//
//  Created by Tanishq Tyagi on 4/26/25.
//

import SwiftUI
import MapKit
import AVFoundation
import CoreLocation
import Combine

struct ContentView: View {
    
    // MARK: - Location Manager
    class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
        let manager = CLLocationManager()
        override init() {
            super.init()
            manager.delegate = self
            manager.requestWhenInUseAuthorization()
            manager.startUpdatingLocation()
        }
    }

    // MARK: - Search ViewModel
    class SearchViewModel: ObservableObject {
        @Published var query = ""
        @Published var results: [MKMapItem] = []
        private var bag = Set<AnyCancellable>()

        init() {
            $query
                .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
                .removeDuplicates()
                .sink { [weak self] text in
                    guard let self = self, !text.isEmpty else {
                        self?.results = []
                        return
                    }
                    let request = MKLocalSearch.Request()
                    request.naturalLanguageQuery = text
                    MKLocalSearch(request: request).start { response, _ in
                        self.results = response?.mapItems ?? []
                    }
                }
                .store(in: &bag)
        }
    }

    // MARK: - State
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var position: MapCameraPosition = .userLocation(
        followsHeading: false,
        fallback: .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )
    )
    @StateObject private var locationManager = LocationManager()
    @StateObject private var searchVM = SearchViewModel()
    @StateObject private var recorder = SegmentRecorder()
    @StateObject private var driveManager = DriveManager.shared
    @State private var showResults = false
    @State private var showSettings = false
    @State private var showDrive = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        let columns = horizontalSizeClass == .compact ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())]

        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.05) // Very dark background
                    .ignoresSafeArea()
            ScrollView {
                LazyVGrid(columns: columns, spacing: 24) {
                    WidgetContainer(defaultWidget: .altitudeTilt)
                    WidgetContainer(defaultWidget: .compass)
                }
                .padding()
            }
            .padding(.top, 10)
            // MARK: - Camera Overlay
                CameraPreview(session: recorder.session)
                    .frame(width: 120, height: 160)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.7), lineWidth: 1)
                    )
                    .shadow(radius: 4)
                    .padding(.top, 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                // MARK: - Top Buttons
                HStack {
                    // Settings Button - top left
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .padding(8)
                            .background(.thinMaterial, in: Circle())
                    }
                    .padding([.top, .leading], 16)
                    .sheet(isPresented: $showSettings) {
                        SettingsView(recorder: recorder)
                            .presentationDetents([.medium])
                    }

                    Spacer()

                    // Drive Upload Button - top right
                    Button {
                        showDrive = true
                    } label: {
                        Image(systemName: "tray.and.arrow.up.fill")
                            .font(.title2)
                            .padding(8)
                            .background(.thinMaterial, in: Circle())
                    }
                    .padding([.top, .trailing], 16)
                    .sheet(isPresented: $showDrive) {
                        DriveView()
                            .presentationDetents([.medium, .large])
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // MARK: - Bottom Record Button
                HUDOverlay(isRecording: recorder.isRecording)
                    .scaleEffect(0.8)
                    .padding(.top, 30)
                    .onTapGesture { recorder.toggle() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        
        }
        /*
        ZStack(alignment: .topTrailing) {

            // MARK: - Map
            if #available(iOS 17.0, *) {
                Map(position: $position, interactionModes: .all) {
                    UserAnnotation()
                }
                .ignoresSafeArea()
            } else {
                Map(coordinateRegion: $region,
                    interactionModes: .all,
                    showsUserLocation: true,
                    userTrackingMode: .constant(.follow))
                .ignoresSafeArea()
            }

            // MARK: - Drive Button
            Button {
                showDrive = true
            } label: {
                Image(systemName: "tray.and.arrow.up.fill")
                    .font(.title2)
                    .padding(8)
                    .background(.thinMaterial, in: Circle())
            }
            .padding([.top, .trailing], 16)
            .sheet(isPresented: $showDrive) {
                DriveView()    // make sure DriveView.swift is in your target
                    .presentationDetents([.medium, .large])
            }

            // MARK: - Settings Button
            Button {
                showSettings = true
            } label: {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .padding(8)
                    .background(.thinMaterial, in: Circle())
            }
            .padding([.top, .leading], 16)
            .frame(maxWidth: .infinity,
                   maxHeight: .infinity,
                   alignment: .topLeading)
            .sheet(isPresented: $showSettings) {
                SettingsView(recorder: recorder)
                    .presentationDetents([.medium])
            }

            // MARK: - Camera Overlay
            CameraPreview(session: recorder.session)
                .frame(width: 120, height: 160)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12,
                                           style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
                .shadow(radius: 4)
                .padding(.trailing, 16)
                .padding(.top, 60)

            // MARK: - Recenter Button
            if #available(iOS 17.0, *) {
                MapUserLocationButton()
                    .padding()
                    .frame(maxWidth: .infinity,
                           maxHeight: .infinity,
                           alignment: .bottomTrailing)
            }

            // MARK: - Search Bar & Results
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    TextField("Search for a place or address",
                              text: $searchVM.query,
                              onEditingChanged: { editing in showResults = editing })
                        .submitLabel(.search)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(.thinMaterial,
                            in: RoundedRectangle(cornerRadius: 14,
                                                style: .continuous))
                .padding(.horizontal, 32)

                if showResults && !searchVM.results.isEmpty {
                    List(searchVM.results, id: \.self) { item in
                        Button {
                            let span = MKCoordinateSpan(latitudeDelta: 0.02,
                                                        longitudeDelta: 0.02)
                            position = .region(MKCoordinateRegion(
                                center: item.placemark.coordinate,
                                span: span
                            ))
                            showResults = false
                            searchVM.query = ""
                        } label: {
                            VStack(alignment: .leading) {
                                Text(item.name ?? "Unknown")
                                    .font(.body)
                                if let subtitle = item.placemark.title {
                                    Text(subtitle)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                    .listStyle(.plain)
                    .clipShape(RoundedRectangle(cornerRadius: 14,
                                                style: .continuous))
                    .padding(.horizontal, 32)
                }
            }
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity,
                   maxHeight: .infinity,
                   alignment: .bottom)

            // MARK: - HUD Overlay
            HUDOverlay(isRecording: recorder.isRecording)
                .scaleEffect(0.8)
                .padding(.bottom, 80)
                .frame(maxWidth: .infinity,
                       maxHeight: .infinity,
                       alignment: .bottom)
                .onTapGesture { recorder.toggle() }
            
                .onReceive(recorder.$finishedClipURL.compactMap { $0 }) { url in
                    guard let folderID = driveManager.uploadFolderID else {
                        print("Drive folder not ready – clip cached locally"); return
                    }
                    let mime = "video/quicktime"      // .mov default
                    driveManager.uploadFile(
                        name: url.lastPathComponent,
                        folderID: folderID,
                        fileURL: url,
                        mimeType: mime
                    )
                    driveManager.enqueueOrUpload(url: url)
                }
        }*/
    }


// MARK: - CameraPreview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.previewLayer.frame = uiView.bounds

        if let connection = uiView.previewLayer.connection,
           connection.isVideoOrientationSupported {
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            if let orientation = scene?.interfaceOrientation {
                switch orientation {
                case .portrait:
                    connection.videoRotationAngle = 0
                case .landscapeLeft:
                    connection.videoRotationAngle = 270
                case .landscapeRight:
                    connection.videoRotationAngle = 90
                case .portraitUpsideDown:
                    connection.videoRotationAngle = 180
                default:
                    break
                }
            }
        }
    }

}

class CameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

// MARK: - HUD Overlay

struct HUDOverlay: View {
    @ObservedObject private var drive = DriveManager.shared
    let isRecording: Bool
    var body: some View {
        HStack(spacing: 24) {
            VStack {
                Image(systemName: isRecording ? "circle.fill" : "pause.circle")
                    .font(.title2)
                    .foregroundColor(.red)
                //Text(isRecording ? "REC" : "PAUSED")
            }
            SpeedView()
            //ETAView()
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

struct SpeedView: View {
    var body: some View {
        VStack {
            Text("0 mph")
                .font(.title2)
                .bold()
        }
    }
}

struct ETAView: View {
    var body: some View {
        VStack {
            Text("ETA: --:--")
                .font(.subheadline)
        }
    }
}

// SwiftUI preview
#Preview {
    ContentView()
}
