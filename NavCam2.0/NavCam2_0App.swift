//
//  NavCam2_0App.swift
//  NavCam2.0
//
//  Created by Tanishq Tyagi on 4/26/25.
//

import SwiftUI
import Network
import AVFoundation

final class NetworkMonitor: ObservableObject {
    @Published var isWifi: Bool = false
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isWifi = path.usesInterfaceType(.wifi)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

@main
struct NavCam2_0App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var recorder        = SegmentRecorder()
    @StateObject private var networkMonitor  = NetworkMonitor()
    @AppStorage("autoBackup")     private var autoBackup     = false
    @AppStorage("wifiOnlyBackup") private var wifiOnlyBackup = false
    @State        private var pendingWifiURLs: [URL] = []

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recorder)
                .environmentObject(networkMonitor)
                .onReceive(recorder.$finishedClipURL.compactMap { $0 }) { url in
                    guard autoBackup else { return }
                    if wifiOnlyBackup {
                        if networkMonitor.isWifi {
                            DriveManager.shared.enqueueOrUpload(url: url)
                        } else {
                            pendingWifiURLs.append(url)
                        }
                    } else {
                        DriveManager.shared.enqueueOrUpload(url: url)
                    }
                }
                .onReceive(networkMonitor.$isWifi) { isWifi in
                    guard isWifi, !pendingWifiURLs.isEmpty else { return }
                    for url in pendingWifiURLs {
                        DriveManager.shared.enqueueOrUpload(url: url)
                    }
                    pendingWifiURLs.removeAll()
                }
        }
    }
}
