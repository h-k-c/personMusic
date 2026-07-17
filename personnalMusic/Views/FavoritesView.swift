import SwiftUI

struct FavoritesView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @Binding var selectedTab: Int
    @State private var fileForInfo: MusicFile?
    @State private var fileToDelete: MusicFile?
    @State private var refreshID = UUID()

    var body: some View {
        NavigationView {
            Group {
                let favs = LocalMusicManager.shared.getFavorites()
                if favs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 50)).foregroundColor(.gray)
                        Text("还没有收藏歌曲").foregroundColor(.gray)
                        Text("在本地音乐中点击 ♡ 添加收藏")
                            .font(.system(size: 13)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(favs) { file in
                                LocalMusicItemView(
                                    musicFile: file,
                                    action: { playFile(file) },
                                    onInfo: { fileForInfo = file },
                                    favToggle: { refreshID = UUID() }
                                )
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { fileToDelete = file }
                                        label: { Label("删除", systemImage: "trash") }
                                }
                            }
                        } header: {
                            Label("\(favs.count) 首收藏", systemImage: "heart.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("收藏")
            .navigationBarTitleDisplayMode(.inline)
            .id(refreshID)
            .sheet(item: $fileForInfo) { FileInfoSheet(file: $0) }
            .alert("确认删除", isPresented: Binding(get: { fileToDelete != nil }, set: { if !$0 { fileToDelete = nil } })) {
                Button("取消", role: .cancel) { fileToDelete = nil }
                Button("删除", role: .destructive) {
                    if let f = fileToDelete {
                        LocalMusicManager.shared.removeMusicFile(f)
                        fileToDelete = nil
                    }
                }
            } message: {
                Text(fileToDelete.map { "确定要删除「\($0.title)」吗？" } ?? "")
            }
            .onAppear {
                // 触发刷新以更新收藏列表
            }
        }
    }

    private func playFile(_ file: MusicFile) {
        guard let result = LocalMusicManager.shared.resolveFileURL(for: file) else { return }
        LocalMusicManager.shared.saveLastPlayedSong(id: file.id)
        playerViewModel.setPlaylist(from: LocalMusicManager.shared.getFavorites())
        let song = Song(title: file.title, artist: file.artist, duration: file.duration,
                        url: result.url, securityScopedRootURL: result.rootURL,
                        folderPath: file.folderPath, folderIdentifier: file.folderIdentifier,
                        relativePath: file.relativePath)
        playerViewModel.playSong(song)
        selectedTab = 0
    }
}
