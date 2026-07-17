import SwiftUI
import UniformTypeIdentifiers

// MARK: - 文件夹详情视图（支持树结构导航）

struct FolderDetailView: View {
    let folder: MusicFolder
    let parentPath: String  // 累积路径，如 "" 或 "subdir/" 或 "subdir/deeper/"
    @ObservedObject var playerViewModel: PlayerViewModel
    @Binding var selectedTab: Int
    @Binding var fileToDelete: MusicFile?
    @Binding var fileForInfo: MusicFile?
    @State private var refreshID = UUID()

    // 当前层级的直接文件（relativePath 去掉 parentPath 后不含 "/"）
    private var directFiles: [MusicFile] {
        let prefix = parentPath
        return folder.files.filter { file in
            let rel = file.relativePath
            guard rel.hasPrefix(prefix) else { return false }
            let sub = String(rel.dropFirst(prefix.count))
            return !sub.contains("/")
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    // 当前层级的子目录
    private var subfolders: [(name: String, files: [MusicFile])] {
        let prefix = parentPath
        var dirs: [String: [MusicFile]] = [:]
        for file in folder.files {
            let rel = file.relativePath
            guard rel.hasPrefix(prefix) else { continue }
            let sub = String(rel.dropFirst(prefix.count))
            let parts = sub.components(separatedBy: "/")
            if parts.count > 1 {
                dirs[parts[0], default: []].append(file)
            }
        }
        return dirs.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    var body: some View {
        List {
            ForEach(subfolders, id: \.name) { sub in
                let subfolder = MusicFolder(path: sub.name, files: sub.files)
                let childPath = parentPath + sub.name + "/"
                NavigationLink {
                    FolderDetailView(folder: subfolder, parentPath: childPath, playerViewModel: playerViewModel, selectedTab: $selectedTab, fileToDelete: $fileToDelete, fileForInfo: $fileForInfo)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.fill").foregroundColor(.accentColor)
                        Text(sub.name).font(.system(size: 16))
                        Spacer()
                        Text("\(sub.files.count) 项").font(.system(size: 13)).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        for f in sub.files {
                            LocalMusicManager.shared.removeMusicFile(f)
                        }
                        refreshID = UUID()
                    } label: { Label("删除", systemImage: "trash") }
                }
            }
            ForEach(directFiles) { file in
                LocalMusicItemView(musicFile: file, action: {
                    playInFolder(file)
                }, onInfo: { fileForInfo = file },
                   onFavorite: { LocalMusicManager.shared.toggleFavorite(file.id); refreshID = UUID() })
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { fileToDelete = file } label: { Label("删除", systemImage: "trash") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .id(refreshID)
        .navigationTitle(folder.path)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func playInFolder(_ file: MusicFile) {
        guard let result = LocalMusicManager.shared.resolveFileURL(for: file) else { return }
        LocalMusicManager.shared.saveLastPlayedSong(id: file.id)
        // 当前文件夹作为播放列表上下文
        playerViewModel.setPlaylist(from: folder.files)
        let song = Song(title: file.title, artist: file.artist, duration: file.duration,
                        url: result.url, securityScopedRootURL: result.rootURL,
                        folderPath: file.folderPath, folderIdentifier: file.folderIdentifier,
                        relativePath: file.relativePath)
        playerViewModel.playSong(song)
        selectedTab = 0
    }
}

