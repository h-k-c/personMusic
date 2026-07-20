import SwiftUI

// MARK: - 播放列表弹窗视图（当前上下文平铺列表）
struct PlaylistOverlayView: View {
    @Binding var showPlaylist: Bool
    @ObservedObject var playerViewModel: PlayerViewModel

    var body: some View {
        NavigationView {
            List {
                ForEach(playerViewModel.playlist) { song in
                    playlistRow(song)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("播放列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .destructive) {
                        playerViewModel.clearPlayback()
                        showPlaylist = false
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
        }
    }

    private func playlistRow(_ song: Song) -> some View {
        Button(action: { playSong(song) }) {
            HStack(spacing: 12) {
                Image(systemName: isCurrentSong(song) ? "speaker.wave.2.fill" : "music.note")
                    .font(.system(size: 16))
                    .foregroundColor(isCurrentSong(song) ? .accentColor : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title).lineLimit(1).font(.system(size: 16)).foregroundColor(.primary)
                    Text(song.artist).font(.system(size: 13)).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
                Text(song.duration.formattedDuration)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            .padding(.vertical, 4)
        }
        .id(song.id)
    }

    private func isCurrentSong(_ song: Song) -> Bool {
        guard let current = playerViewModel.currentSong else { return false }
        return current.folderIdentifier == song.folderIdentifier && current.relativePath == song.relativePath
    }

    private func playSong(_ song: Song) {
        // 解析 URL（如果歌曲来自播放列表，url 可能为 nil）
        var resolvedSong = song
        if resolvedSong.url == nil,
           let folderId = song.folderIdentifier,
           let relativePath = song.relativePath,
           let result = LocalMusicManager.shared.resolveFileURL(folderIdentifier: folderId, relativePath: relativePath) {
            resolvedSong = Song(
                title: song.title, artist: song.artist, duration: song.duration,
                url: result.url, securityScopedRootURL: result.rootURL,
                folderPath: song.folderPath, folderIdentifier: folderId, relativePath: relativePath
            )
        }
        playerViewModel.playSong(resolvedSong)
        showPlaylist = false
    }

}
