//
//  SettingsView.swift
//  MID
//
//  Created by mosab abudeeb on 05/02/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var saveLocationManager: SaveLocationManager

    @Environment(\.dismiss) private var dismiss

    @State private var errorMessage: String?
    @State private var showingFolderImporter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2)

            VStack(alignment: .leading, spacing: 8) {
                Text("Default Save Folder")
                    .font(.headline)

                HStack {
                    Text(saveLocationManager.defaultLocation.folder.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Change…") {
                        showingFolderImporter = true
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 560, height: 220)
        .fileImporter(
            isPresented: $showingFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let folder = urls.first else { return }
                do {
                    try saveLocationManager.setDefaultFolder(folder)
                    errorMessage = nil
                } catch {
                    errorMessage = "Could not save folder permission."
                }
            case .failure:
                break
            }
        }
    }
}

#Preview {
    SettingsView(saveLocationManager: SaveLocationManager())
}
