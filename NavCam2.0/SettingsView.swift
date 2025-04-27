//
//  SettingsView 2.swift
//  NavCam2.0
//
//  Created by Tanishq Tyagi on 4/26/25.
//


//
//  SettingsView.swift
//  NavCam2.0
//
//  Created by ChatGPT on 4/26/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var recorder: SegmentRecorder

    @AppStorage("clipLength") private var storedClipLength: Double = 30
    @AppStorage("frameRate") private var storedFrameRate: Int = 30
    @AppStorage("resolutionTag") private var storedResolutionTag: String = "1280×720"
    @AppStorage("maxStorageMB") private var storedMaxStorageMB: Int = 100

    /// Fixed order for resolution options
    private let resolutionOptions = ["1280×720", "1920×1080", "3840×2160"]

    // Simple presets for resolution
    private let resolutionTags = [
        "1280×720": CGSize(width: 1280, height: 720),
        "1920×1080": CGSize(width: 1920, height: 1080),
        "3840×2160": CGSize(width: 3840, height: 2160)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0x12/255.0, green: 0x12/255.0, blue: 0x12/255.0)
                    .ignoresSafeArea()
                Form {
                    Section(header:
                        Text("Clip Length (\(Int(storedClipLength))s)")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(Color(red: 0xB3/255.0, green: 0xB3/255.0, blue: 0xB3/255.0))
                    ) {
                        Slider(value: $storedClipLength, in: 5...120, step: 5)
                            .tint(Color(red: 0x1A/255.0, green: 0xBC/255.0, blue: 0x9C/255.0))
                            .padding(.vertical, 8)
                            .onChange(of: storedClipLength) { recorder.clipLength = $0 }
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0x1E/255.0, green: 0x1E/255.0, blue: 0x1E/255.0))
                    )
                    .listRowSeparator(.hidden)

                    Section(header:
                        Text("Frame Rate")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(Color(red: 0xB3/255.0, green: 0xB3/255.0, blue: 0xB3/255.0))
                    ) {
                        Picker("Frame Rate", selection: $storedFrameRate) {
                            Text("30 fps").tag(30)
                            Text("60 fps").tag(60)
                        }
                        .pickerStyle(.segmented)
                        .tint(Color(red: 0x1A/255.0, green: 0xBC/255.0, blue: 0x9C/255.0))
                        .padding(.vertical, 8)
                        .onChange(of: storedFrameRate) { oldValue, newValue in
                            recorder.frameRate = newValue
                        }
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0x1E/255.0, green: 0x1E/255.0, blue: 0x1E/255.0))
                    )
                    .listRowSeparator(.hidden)

                    Section(header:
                        Text("Resolution")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(Color(red: 0xB3/255.0, green: 0xB3/255.0, blue: 0xB3/255.0))
                    ) {
                        Picker("Resolution", selection: $storedResolutionTag) {
                            ForEach(resolutionOptions, id: \.self) { tag in
                                Text(tag).tag(tag)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(Color(red: 0x1A/255.0, green: 0xBC/255.0, blue: 0x9C/255.0))
                        .padding(.vertical, 8)
                        .onChange(of: storedResolutionTag) { oldTag, newTag in
                            recorder.resolution = resolutionTags[newTag] ?? CGSize(width: 1280, height: 720)
                        }
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0x1E/255.0, green: 0x1E/255.0, blue: 0x1E/255.0))
                    )
                    .listRowSeparator(.hidden)

                    Section(header:
                        Text("Max Storage (\(storedMaxStorageMB) MB)")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(Color(red: 0xB3/255.0, green: 0xB3/255.0, blue: 0xB3/255.0))
                    ) {
                        Slider(
                            value: Binding(
                                get: { Double(storedMaxStorageMB) },
                                set: { newMB in
                                    storedMaxStorageMB = Int(newMB)
                                    recorder.maxStorageBytes = Int64(storedMaxStorageMB * 1_000_000)
                                }
                            ),
                            in: 100...2000,
                            step: 100
                        )
                        .tint(Color(red: 0x1A/255.0, green: 0xBC/255.0, blue: 0x9C/255.0))
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0x1E/255.0, green: 0x1E/255.0, blue: 0x1E/255.0))
                    )
                    .listRowSeparator(.hidden)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("Recording Settings")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            recorder.clipLength = storedClipLength
            recorder.frameRate = storedFrameRate
            recorder.resolution = resolutionTags[storedResolutionTag] ?? CGSize(width:1280, height:720)
            recorder.maxStorageBytes = Int64(storedMaxStorageMB * 1_000_000)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(recorder: SegmentRecorder())
    }
}
