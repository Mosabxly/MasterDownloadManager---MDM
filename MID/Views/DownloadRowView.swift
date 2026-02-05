//
//  DownloadRowView.swift
//  MID
//
//  Created by mosab abudeeb on 05/02/2026.
//

import SwiftUI

struct DownloadRowView: View {
    let task: DownloadItem

    let onPause: () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.fileName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(task.url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(task.state.displayText)
                    .font(.caption)
                    .foregroundStyle(taskStateColor)
            }

            progressView

            HStack(spacing: 14) {
                Text(progressText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Text(ByteFormatter.speed(task.speedBytesPerSecond))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Text("ETA \(etaText)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Spacer()

                actionButtons
            }
            .font(.caption)

            if case .failed(let message) = task.state {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch task.state {
        case .downloading:
            Button("Pause", action: onPause)
            Button("Cancel", role: .destructive, action: onCancel)
        case .queued:
            Button("Pause", action: onPause)
            Button("Cancel", role: .destructive, action: onCancel)
        case .pausing:
            Button("Cancel", role: .destructive, action: onCancel)
        case .paused:
            Button("Resume", action: onResume)
            Button("Cancel", role: .destructive, action: onCancel)
        case .finishing:
            EmptyView()
        case .completed:
            EmptyView()
        case .failed:
            Button("Retry", action: onResume)
            Button("Cancel", role: .destructive, action: onCancel)
        case .canceled:
            EmptyView()
        }
    }

    private var progressView: some View {
        Group {
            if let p = task.progress {
                ProgressView(value: p)
            } else {
                ProgressView()
            }
        }
        .progressViewStyle(.linear)
    }

    private var progressText: String {
        guard let p = task.progress else { return "—" }
        return "\(Int((p * 100).rounded()))%"
    }

    private var etaText: String {
        guard let eta = task.etaSeconds else { return "—" }
        return TimeFormatter.compact(eta)
    }

    private var taskStateColor: Color {
        switch task.state {
        case .failed:
            return .red
        case .completed:
            return .green
        default:
            return .secondary
        }
    }
}

#Preview {
    let url = URL(string: "https://example.com/file.zip") ?? URL(fileURLWithPath: "/")
    DownloadRowView(
        task: .init(url: url, fileName: "file.zip", saveLocation: .init(folder: FileManager.default.temporaryDirectory, bookmarkData: nil), state: .downloading, progress: 0.42, speedBytesPerSecond: 2_000_000, etaSeconds: 72),
        onPause: {},
        onResume: {},
        onCancel: {}
    )
    .padding()
    .frame(width: 820)
}
