//
//  AddURLSheet.swift
//  MID
//
//  Created by mosab abudeeb on 05/02/2026.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AddURLSheet: View {
    let defaultFolder: URL
    let onAdd: (URL, URL?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var urlString = ""
    @State private var selectedFolder: URL?
    @State private var validationMessage: String?
    @State private var showingFolderImporter = false

    init(defaultFolder: URL, onAdd: @escaping (URL, URL?) -> Void) {
        self.defaultFolder = defaultFolder
        self.onAdd = onAdd
        self._selectedFolder = State(initialValue: nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Download")
                .font(.title2)

            VStack(alignment: .leading, spacing: 8) {
                Text("URL")
                    .font(.headline)

                HStack {
                    TextField("https://example.com/file.zip", text: $urlString)
                        .textFieldStyle(.roundedBorder)

                    Button("Paste") {
                        if let string = NSPasteboard.general.string(forType: .string) {
                            urlString = string.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                }

                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Save Folder")
                    .font(.headline)

                HStack {
                    Text(folderDisplayPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Choose…") {
                        showingFolderImporter = true
                    }

                    if selectedFolder != nil {
                        Button("Use Default") {
                            selectedFolder = nil
                        }
                    }
                }
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button("Add") {
                    add()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 560, height: 280)
        .fileImporter(
            isPresented: $showingFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                selectedFolder = urls.first
            case .failure:
                break
            }
        }
    }

    private func add() {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            url.host != nil
        else {
            validationMessage = "Enter a valid http/https URL."
            return
        }

        validationMessage = nil
        onAdd(url, selectedFolder)
        dismiss()
    }

    private var folderDisplayPath: String {
        let folder = selectedFolder ?? defaultFolder
        return folder.path + (selectedFolder == nil ? " (Default)" : "")
    }
}

#Preview {
    AddURLSheet(defaultFolder: FileManager.default.temporaryDirectory) { _, _ in }
}
