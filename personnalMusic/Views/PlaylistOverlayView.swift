import SwiftUI

// MARK: - 播放列表弹窗视图
struct PlaylistOverlayView: View {
    @Binding var showPlaylist: Bool
    @ObservedObject var playerViewModel: PlayerViewModel
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationView {
            List {
                let folders = LocalMusicManager.shared.getMusicByFolders()
                let looseFiles = LocalMusicManager.shared.getAllMusicFiles().filter { $0.folderIdentifier == "loose" }

                // 文件夹分组
                ForEach(folders) { folder in
                    Section {
                        ForEach(folder.files) { file in
                            playlistRow(file)
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text(folder.path)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 零散文件
                if !looseFiles.isEmpty {
                    Section("文件") {
                        ForEach(looseFiles) { file in
                            playlistRow(file)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("播放列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showPlaylist = false
                    }
                }
            }
            .alert("确认清空", isPresented: $showClearConfirmation) {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive) { clearAllMusic() }
            } message: {
                Text("确定要清空所有音乐吗？此操作无法撤销。")
            }
        }
    }

    private func playlistRow(_ file: MusicFile) -> some View {
        Button(action: { playMusicFile(file) }) {
            HStack(spacing: 12) {
                Image(systemName: isCurrentFile(file) ? "speaker.wave.2.fill" : "music.note")
                    .font(.system(size: 16))
                    .foregroundColor(isCurrentFile(file) ? .accentColor : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(file.title).lineLimit(1).font(.system(size: 16)).foregroundColor(.primary)
                    Text(file.artist).font(.system(size: 13)).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
                Text(file.duration.formattedDuration).font(.system(size: 14)).foregroundColor(.secondary).monospacedDigit()
            }
            .padding(.vertical, 4)
        }
        .id(file.id)
    }

    private func isCurrentFile(_ file: MusicFile) -> Bool {
        guard let song = playerViewModel.currentSong else { return false }
        return song.folderIdentifier == file.folderIdentifier && song.relativePath == file.relativePath
    }

    private func playMusicFile(_ file: MusicFile) {
        guard let result = LocalMusicManager.shared.resolveFileURL(for: file) else { return }
        // 全部歌曲作为播放列表上下文
        playerViewModel.setPlaylist(from: LocalMusicManager.shared.getAllMusicFiles())
        let song = Song(
            title: file.title,
            artist: file.artist,
            duration: file.duration,
            url: result.url,
            securityScopedRootURL: result.rootURL,
            folderPath: file.folderPath,
            folderIdentifier: file.folderIdentifier,
            relativePath: file.relativePath
        )
        playerViewModel.playSong(song)
        showPlaylist = false
    }

    private func clearAllMusic() {
        playerViewModel.clearPlayback()
        LocalMusicManager.shared.clearAllMusic()
        showPlaylist = false
    }
}
