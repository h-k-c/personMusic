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
    let favToggle: (() -> Void)?

    init(musicFile: MusicFile,
         action: @escaping () -> Void,
         onInfo: (() -> Void)? = nil,
         favToggle: (() -> Void)? = nil) {
        self.musicFile = musicFile
        self.action = action
        self.onInfo = onInfo
        self.favToggle = favToggle
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // 音乐图标
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: "music.note")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                }

                // 标题和艺术家
                VStack(alignment: .leading, spacing: 3) {
                    Text(musicFile.title)
                        .lineLimit(1)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    HStack(spacing: 6) {
                        Text(musicFile.artist)
                            .lineLimit(1)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        if musicFile.duration > 0 {
                            Text("·")
                                .foregroundColor(.secondary)
                            Text(musicFile.duration.formattedDuration)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                Spacer()

                // 收藏按钮（自带状态 + 弹跳动效）
                FavoriteButton(fileId: musicFile.id, isFavorite: musicFile.isFavorite, onToggle: favToggle)

                // 信息按钮
                if let onInfo = onInfo {
                    Button {
                        onInfo()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                    infoRow("艺术家", file.artist)
                    infoRow("格式", file.fileFormat)
                    infoRow("大小", file.fileSizeString)
                    infoRow("时长", file.duration.formattedDuration)
                }

                Section("存储位置") {
                    infoRow("文件夹", file.folderPath)
                    infoRow("路径", file.relativePath)
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
                .lineLimit(2)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    LocalMusicItemView(
        musicFile: MusicFile(
            id: "preview",
            fileName: "example.mp3",
            folderPath: "MyMusic",
            folderIdentifier: "preview-folder",
            relativePath: "example.mp3",
            title: "示例歌曲",
            artist: "未知艺术家",
            duration: 245,
            fileSize: 5_000_000
        ),
        action: {}
    )
    .padding()
}
