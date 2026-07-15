//
//  LocalMusicItemView.swift
//  personnalMusic
//
//  本地音乐列表项视图：显示单个音乐文件的信息

import SwiftUI

struct LocalMusicItemView: View {
    let musicFile: MusicFile
    let action: () -> Void
    let onInfo: (() -> Void)?
    let onDelete: (() -> Void)?

    init(musicFile: MusicFile,
         action: @escaping () -> Void,
         onInfo: (() -> Void)? = nil,
         onDelete: (() -> Void)? = nil) {
        self.musicFile = musicFile
        self.action = action
        self.onInfo = onInfo
        self.onDelete = onDelete
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 格式图标
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                    Text(musicFile.fileFormat)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }

                // 标题和副信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(musicFile.title)
                        .lineLimit(1)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    HStack(spacing: 8) {
                        Text(musicFile.fileSizeString)
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("·")
                            .foregroundColor(.gray)
                        Text(musicFile.duration.formattedDuration)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // 信息按钮
                if let onInfo = onInfo {
                    Button {
                        onInfo()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

// MARK: - 文件详情弹窗
struct FileInfoSheet: View {
    let file: MusicFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("基本信息") {
                    infoRow("文件名", file.fileName)
                    infoRow("标题", file.title)
                    infoRow("格式", file.fileFormat)
                    infoRow("大小", file.fileSizeString)
                    infoRow("时长", file.duration.formattedDuration)
                }

                Section("存储位置") {
                    infoRow("文件夹", file.folderPath)
                }
            }
            .navigationTitle("文件信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    LocalMusicItemView(
        musicFile: MusicFile(
            url: URL(string: "file:///example.mp3")!
        ),
        action: {}
    )
    .previewLayout(.sizeThatFits)
    .padding()
}