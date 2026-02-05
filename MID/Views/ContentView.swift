//
//  ContentView.swift
//  MID
//
//  Created by mosab abudeeb on 05/02/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var saveLocationManager: SaveLocationManager
    @StateObject private var downloadsViewModel: DownloadsViewModel

    @State private var showingAddSheet = false
    @State private var showingSettings = false

    init() {
        let slm = SaveLocationManager()
        _saveLocationManager = StateObject(wrappedValue: slm)
        _downloadsViewModel = StateObject(wrappedValue: DownloadsViewModel(saveLocationManager: slm))
    }

    var body: some View {
        NavigationStack {
            List {
                if downloadsViewModel.downloads.isEmpty {
                    ContentUnavailableView("No Downloads", systemImage: "arrow.down.circle", description: Text("Add a URL to start downloading."))
                } else {
                    ForEach(downloadsViewModel.downloads) { task in
                        DownloadRowView(
                            task: task,
                            onPause: { downloadsViewModel.pause(id: task.id) },
                            onResume: { downloadsViewModel.resume(id: task.id) },
                            onCancel: { downloadsViewModel.cancel(id: task.id) }
                        )
                    }
                }
            }
            .navigationTitle("Download Manager")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add URL", systemImage: "plus")
                    }

                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddURLSheet(
                    defaultFolder: saveLocationManager.defaultLocation.folder,
                    onAdd: { url, folder in
                        downloadsViewModel.addDownload(url: url, saveFolder: folder)
                    }
                )
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(saveLocationManager: saveLocationManager)
            }
        }
        .frame(minWidth: 820, minHeight: 520)
    }
}

#Preview {
    ContentView()
}
