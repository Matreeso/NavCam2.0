//
//  DriveView.swift
//  NavCam2.0
//
//  Created by Shayaan Tanveer on 4/26/25.
//

import Foundation
import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import GoogleAPIClientForREST_Drive
import GTMSessionFetcherFull
import UniformTypeIdentifiers
import AVKit
import AVFoundation
import UIKit
import Combine

extension Notification.Name {
    static let uploadFailed = Notification.Name("DriveManagerUploadFailed")
    static let uploadSucceeded = Notification.Name("DriveManagerUploadSucceeded")
}

extension URL: Identifiable {
    public var id: URL { self }
}

/// Manages Google Drive API interactions, including uploads
final class DriveManager: ObservableObject {
    static let shared = DriveManager()
    private init() { }
    
    let service = GTLRDriveService()
    @Published var uploadFolderID: String?
    @Published var uploadProgress: Double = 0
    @Published var isFolderReady = false

    /// Call after sign-in to authorize Drive calls
    func configure(with user: GIDGoogleUser) {
        service.authorizer = user.fetcherAuthorizer
    }
    

    private func getFolderID(name: String,
                             user: GIDGoogleUser,
                             completion: @escaping (String?) -> Void) {
        let query = GTLRDriveQuery_FilesList.query()
        query.spaces = "drive"
        query.corpora = "user"
        query.q = "name = '\(name)' and mimeType = 'application/vnd.google-apps.folder' and '\(user.profile!.email)' in owners"

        service.executeQuery(query) { _, result, error in
            if let error = error {
                print("Drive list error: \(error.localizedDescription)")
                completion(nil); return
            }
            let list = (result as? GTLRDrive_FileList)?.files
            completion(list?.first?.identifier)
        }
    }

    /// Upload a file URL to the given folderID, reporting progress
    func uploadFile(
        name: String,
        folderID: String,
        fileURL: URL,
        mimeType: String
    ) {
        let file = GTLRDrive_File()
        file.name = name
        file.parents = [folderID]

        let uploadParams = GTLRUploadParameters(fileURL: fileURL, mimeType: mimeType)
        let query = GTLRDriveQuery_FilesCreate.query(
            withObject: file,
            uploadParameters: uploadParams
        )

        service.uploadProgressBlock = { _, uploaded, total in
            DispatchQueue.main.async {
                self.uploadProgress = Double(uploaded) / Double(max(total, 1))
            }
        }

        service.executeQuery(query) { _, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Upload failed: \(error.localizedDescription)")
                } else {
                    // complete!
                    self.uploadProgress = 1
                }
            }
        }
    }

    private var pendingQueue: [URL] = []

    // call from ContentView
    func enqueueOrUpload(url: URL) {
        if let id = uploadFolderID {
            uploadFile(name: url.lastPathComponent,
                       folderID: id,
                       fileURL: url,
                       mimeType: "video/quicktime")
        } else {
            pendingQueue.append(url)
            print("Queued clip – Drive not ready yet")
        }
    }

    func ensureFolder(named name: String, for user: GIDGoogleUser) {
        getFolderID(name: name, user: user) { [weak self] id in
            guard let self else { return }
            if let id {
                DispatchQueue.main.async {
                    self.uploadFolderID = id
                    self.isFolderReady  = true
                    self.flushQueue()
                }
            } else {
                self.createFolder(name: name)
            }
        }
    }

    private func createFolder(name: String) {
        let folder = GTLRDrive_File()
        folder.name     = name
        folder.mimeType = "application/vnd.`googl`e-apps.folder"

        let q = GTLRDriveQuery_FilesCreate.query(withObject: folder,
                                                 uploadParameters: nil)
        q.fields = "id"
        service.executeQuery(q) { [weak self] _, result, error in
            guard let self, error == nil,
                  let id = (result as? GTLRDrive_File)?.identifier else { return }
            DispatchQueue.main.async {
                self.uploadFolderID = id
                self.isFolderReady  = true
                self.flushQueue()
            }
        }
    }

    private func flushQueue() {
        guard let id = uploadFolderID else { return }
        for url in pendingQueue {
            print("Uploading cached clip:", url.lastPathComponent)
            uploadFile(name: url.lastPathComponent,
                       folderID: id,
                       fileURL: url,
                       mimeType: "video/quicktime")
        }
        pendingQueue.removeAll()
    }


    // security-scoped helper
    func localCopy(of remoteURL: URL) throws -> URL {
        guard remoteURL.startAccessingSecurityScopedResource() else {
            throw CocoaError(.fileReadNoPermission)
        }
        defer { remoteURL.stopAccessingSecurityScopedResource() }

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(remoteURL.pathExtension)

        try FileManager.default.copyItem(at: remoteURL, to: temp)
        return temp
    }
}

struct VideoThumbnailView: View {
    let url: URL
    @State private var thumb: UIImage?

    var body: some View {
        Group {
            if let image = thumb {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .onAppear {
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 0.1, preferredTimescale: 600)
            DispatchQueue.global().async {
                if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                    let ui = UIImage(cgImage: cgImage)
                    DispatchQueue.main.async {
                        thumb = ui
                    }
                }
            }
        }
    }
}

struct VideoGridCell: View {
    let url: URL
    @State private var durationText: String = ""
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                VideoThumbnailView(url: url)
                    .frame(height: 100)
                    .clipped()
                Text(durationText)
                    .font(.caption2)
                    .padding(4)
                    .background(
                        Color(red:   0x00/255,
                              green: 0x00/255,
                              blue:  0x00/255)
                            .opacity(0.6)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .padding(6)
            }
            Text(url.lastPathComponent)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(.white)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    Color(red:   0x1E/255,
                          green: 0x1E/255,
                          blue:  0x1E/255)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    Color(red:   0x2C/255,
                          green: 0x2C/255,
                          blue:  0x2C/255),
                    lineWidth: 1
                )
        )
        .onAppear {
            let asset = AVAsset(url: url)
            let dur = CMTimeGetSeconds(asset.duration)
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = dur >= 3600
                ? [.hour, .minute, .second]
                : [.minute, .second]
            formatter.zeroFormattingBehavior = .pad
            durationText = formatter.string(from: dur) ?? "--:--"
        }
    }
}

struct PlayerView: View {
    let url: URL
    @State private var player: AVPlayer?
    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .onAppear { player.play() }
                    .edgesIgnoringSafeArea(.all)
            } else {
                ProgressView()
                    .onAppear {
                        let p = AVPlayer(url: url)
                        player = p
                    }
            }
        }
    }
}

struct DriveView: View {
    @StateObject private var driveManager = DriveManager.shared
    @State private var isSignedIn = false

    @EnvironmentObject var recorder: SegmentRecorder
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @State private var selectedClipURL: URL?
    @State private var isSelecting = false
    @State private var selectedClipURLs = Set<URL>()
    @State private var uploadedClips: [String] = UserDefaults.standard.stringArray(forKey: "uploadedClips") ?? []
    @AppStorage("autoBackup") private var autoBackup = false
    @AppStorage("wifiOnlyBackup") private var wifiOnlyBackup = false
    @State private var failedClips: Set<String> = []

    private var headerView: some View {
        HStack {
            Text("NavCam Clips")
                .font(.largeTitle.weight(.bold))
                .foregroundColor(.white)
            Spacer()
            Button(isSelecting ? "Done" : "Select") {
                withAnimation { isSelecting.toggle() }
                if !isSelecting { selectedClipURLs.removeAll() }
            }
            .foregroundColor(
                Color(red:   0x1A/255,
                      green: 0xBC/255,
                      blue:  0x9C/255)
            )
        }
        .padding(.horizontal)
        .padding(.top, 32)
        .padding(.bottom, 8)
    }

    private var signInSection: some View {
        Group {
            if !isSignedIn {
                GoogleSignInButton { signInWithDriveScope() }
                    .frame(width: 200, height: 44)
                Text("Signing in with Google allows cloud backup to your Drive.")
                    .font(.caption)
                    .foregroundColor(
                        Color(red:   0xB3/255,
                              green: 0xB3/255,
                              blue:  0xB3/255)
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            } else {
                if let user = GIDSignIn.sharedInstance.currentUser {
                    HStack(spacing: 8) {
                        if let profile = user.profile,
                           let avatarURL = profile.imageURL(withDimension: 64) {
                            AsyncImage(url: avatarURL) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Signed in as")
                                .font(.caption2)
                                .foregroundColor(
                                    Color(red:   0xB3/255,
                                          green: 0xB3/255,
                                          blue:  0xB3/255)
                                )
                            Text(user.profile?.email ?? "Unknown")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Button("Sign Out") {
                            GIDSignIn.sharedInstance.signOut()
                            isSignedIn = false
                            driveManager.uploadFolderID = nil
                        }
                        .font(.caption2)
                        .foregroundColor(
                            Color(red:   0x1A/255,
                                  green: 0xBC/255,
                                  blue:  0x9C/255)
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private var togglesSection: some View {
        VStack {
            Toggle("Automatic Backup", isOn: $autoBackup)
                .foregroundColor(.white)
                .toggleStyle(
                    SwitchToggleStyle(
                        tint: Color(red:   0x1A/255,
                                    green: 0xBC/255,
                                    blue:  0x9C/255)
                    )
                )
            Toggle("Only backup on Wi-Fi", isOn: $wifiOnlyBackup)
                .foregroundColor(.white)
                .toggleStyle(
                    SwitchToggleStyle(
                        tint: Color(red:   0x1A/255,
                                    green: 0xBC/255,
                                    blue:  0x9C/255)
                    )
                )
        }
        .padding(.horizontal)
    }

    private var clipsGrid: some View {
        ScrollView {
            let clipsDir = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("NavCamClips", isDirectory: true)
            let clipURLs = (try? FileManager.default
                .contentsOfDirectory(at: clipsDir,
                                      includingPropertiesForKeys: [.creationDateKey],
                                      options: [.skipsHiddenFiles])) ?? []

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(clipURLs.sorted { urlA, urlB in
                    let dateA = (try? urlA.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                    let dateB = (try? urlB.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                    return dateA > dateB
                }, id: \.self) { url in
                    ZStack {
                        VideoGridCell(url: url)
                            .overlay(
                                Group {
                                    if uploadedClips.contains(url.lastPathComponent) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                            .padding(4)
                                    } else if failedClips.contains(url.lastPathComponent) {
                                        Image(systemName: "xmark.seal.fill")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                            .padding(4)
                                    } else if autoBackup && wifiOnlyBackup && !networkMonitor.isWifi {
                                        Image(systemName: "pause.circle")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                            .padding(4)
                                    }
                                },
                                alignment: .topTrailing
                            )
                            .overlay(
                                isSelecting && selectedClipURLs.contains(url)
                                    ? Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                        .padding(4)
                                    : nil,
                                alignment: .topTrailing
                            )
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isSelecting {
                            if selectedClipURLs.contains(url) {
                                selectedClipURLs.remove(url)
                            } else {
                                selectedClipURLs.insert(url)
                            }
                        } else {
                            selectedClipURL = url
                        }
                    }
                    .contextMenu {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var selectionBar: some View {
        Group {
            if isSelecting && !selectedClipURLs.isEmpty {
                HStack(spacing: 24) {
                    Button(role: .destructive) {
                        for url in selectedClipURLs {
                            try? FileManager.default.removeItem(at: url)
                        }
                        selectedClipURLs.removeAll()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    ShareLink(items: Array(selectedClipURLs)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                .padding()
            }
        }
    }

    var body: some View {
        // typed publishers to simplify onReceive
        let failedPublisher: AnyPublisher<String, Never> = NotificationCenter
            .default
            .publisher(for: .uploadFailed)
            .compactMap { (n: Notification) -> String? in n.object as? String }
            .eraseToAnyPublisher()

        let successPublisher: AnyPublisher<String, Never> = NotificationCenter
            .default
            .publisher(for: .uploadSucceeded)
            .compactMap { (n: Notification) -> String? in n.object as? String }
            .eraseToAnyPublisher()

        // Build the main layout first
        let content = VStack(spacing: 16) {
            headerView
            signInSection
            togglesSection
            Text("Local Files")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            clipsGrid
            selectionBar
        }

        return ZStack {
            Color(red:   0x12/255,
                  green: 0x12/255,
                  blue:  0x12/255)
                .ignoresSafeArea()
            content
                .padding()
        }
        .sheet(item: $selectedClipURL) { clip in
            PlayerView(url: clip)
        }
        .onAppear {
            if let user = GIDSignIn.sharedInstance.currentUser {
                isSignedIn = true
                driveManager.configure(with: user)
                driveManager.ensureFolder(named: "NavCamClips", for: user)
            }
        }
        .onReceive(recorder.$finishedClipURL.compactMap { $0 }) { (url: URL) in
            guard autoBackup, isSignedIn else { return }
            let name = url.lastPathComponent
            guard !uploadedClips.contains(name) else { return }
            driveManager.enqueueOrUpload(url: url)
            uploadedClips.append(name)
            UserDefaults.standard.set(uploadedClips, forKey: "uploadedClips")
        }
        .onReceive(failedPublisher) { name in
            failedClips.insert(name)
        }
        .onReceive(successPublisher) { (name: String) in
            if !uploadedClips.contains(name) {
                uploadedClips.append(name)
                UserDefaults.standard.set(uploadedClips, forKey: "uploadedClips")
            }
            failedClips.remove(name)
        }
    }

    private func signInWithDriveScope() {
        guard let root = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: \.isKeyWindow)?
                .rootViewController else {
            return
        }

        GIDSignIn.sharedInstance.signIn(
                withPresenting: root,
                hint: nil,
                additionalScopes: [kGTLRAuthScopeDrive]
            ) { result, error in
                guard error == nil, let user = result?.user else {
                    print("Sign-in error:", error?.localizedDescription ?? "nil"); return
                }
                isSignedIn = true
                driveManager.configure(with: user)
                driveManager.ensureFolder(named: "Your Clips", for: user)
            }
    }

    private func lookupMimeType(for url: URL) -> String {
        if let ut = UTType(filenameExtension: url.pathExtension),
           let mime = ut.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }
}
