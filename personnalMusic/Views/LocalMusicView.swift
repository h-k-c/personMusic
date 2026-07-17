//
//  LocalMusicView.swift
//  personnalMusic
//
//  本地音乐视图：文件夹卡片 + 文件列表，支持文件夹树结构导航

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct LocalMusicView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @StateObject private var viewModel = LocalMusicViewModel()
    @State private var showingFilePicker = false
    @State private var showingFolderPicker = false
    @State private var showingActionSheet = false
    @State private var showClearConfirmation = false
    @State private var fileToDelete: MusicFile?
    @State private var fileForInfo: MusicFile?
    @State private var folderToDelete: MusicFolder?
    @Binding var selectedTab: Int

    var body: some View {
        NavigationView {
            List {
                if viewModel.musicFolders.isEmpty && looseFiles.isEmpty {
                    emptyView
                } else {
                    favoritesSection
                    folderSection
                    looseFilesSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .confirmationDialog("添加音乐", isPresented: $showingActionSheet) {
                Button("添加文件夹") { showingFolderPicker = true }
                Button("添加文件") { showingFilePicker = true }
                Button("取消", role: .cancel) {}
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker(allowedContentTypes: [.audio], allowsMultipleSelection: true) { viewModel.addMusicFiles($0) }
            }
            .sheet(isPresented: $showingFolderPicker) {
                DocumentPicker(allowedContentTypes: [.folder], allowsMultipleSelection: false) {
                    if let url = $0.first { viewModel.addMusicFolder(url) }
                }
            }
            .alert("确认清空", isPresented: $showClearConfirmation) {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive) { viewModel.clearAllMusic(playerViewModel: playerViewModel) }
            } message: { Text("确定要清空所有音乐吗？此操作无法撤销。") }
            .alert("确认删除", isPresented: deleteAlertBinding) {
                Button("取消", role: .cancel) { fileToDelete = nil }
                Button("删除", role: .destructive) { deleteCurrentFile() }
            } message: { Text(fileToDelete.map { "确定要删除「\($0.title)」吗？" } ?? "") }
            .alert("删除文件夹", isPresented: Binding(get: { folderToDelete != nil }, set: { if !$0 { folderToDelete = nil } })) {
                Button("取消", role: .cancel) { folderToDelete = nil }
                Button("删除", role: .destructive) { deleteCurrentFolder() }
            } message: {
                if let f = folderToDelete {
                    Text("确定要删除「\(f.path)」及其全部 \(f.files.count) 首歌曲吗？")
                }
            }
            .sheet(item: $fileForInfo) { FileInfoSheet(file: $0) }
            .onAppear { viewModel.refreshMusicList() }
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(get: { fileToDelete != nil }, set: { if !$0 { fileToDelete = nil } })
    }

    private func deleteCurrentFile() {
        guard let file = fileToDelete else { return }
        viewModel.deleteFile(file, playerViewModel: playerViewModel)
        fileToDelete = nil
    }

    private func deleteCurrentFolder() {
        guard let folder = folderToDelete else { return }
        for file in folder.files {
            viewModel.deleteFile(file, playerViewModel: playerViewModel)
        }
        folderToDelete = nil
    }

    private var favoritesSection: some View {
        let favs = LocalMusicManager.shared.getFavorites()
        if favs.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            Section {
                ForEach(favs) { file in
                    fileRow(file)
                }
            } header: {
                Label("收藏", systemImage: "heart.fill")
                    .foregroundColor(.red)
            }
        )
    }

    private var folderSection: some View {
        Section("文件夹") {
            ForEach(viewModel.musicFolders) { folder in
                NavigationLink {
                    FolderDetailView(folder: folder, parentPath: "", playerViewModel: playerViewModel, selectedTab: $selectedTab, fileToDelete: $fileToDelete, fileForInfo: $fileForInfo)
                } label: {
                    folderRow(folder)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        folderToDelete = folder
                    } label: { Label("删除文件夹", systemImage: "trash") }
                }
            }
        }
    }

    private func folderRow(_ folder: MusicFolder) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill").font(.system(size: 22)).foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(folder.path).font(.system(size: 16, weight: .medium))
                Text("\(folder.files.count) 首").font(.system(size: 13)).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var looseFiles: [MusicFile] {
        LocalMusicManager.shared.getAllMusicFiles()
            .filter { $0.folderIdentifier == "loose" }
    }

    @ViewBuilder
    private var looseFilesSection: some View {
        if !looseFiles.isEmpty {
            Section("文件") {
                ForEach(looseFiles) { file in
                    fileRow(file)
                }
            }
        }
    }

    private func fileRow(_ file: MusicFile) -> some View {
        LocalMusicItemView(
            musicFile: file,
            action: { viewModel.playMusic(file, playerViewModel: playerViewModel, selectedTab: $selectedTab) },
            onInfo: { fileForInfo = file },
            onFavorite: { LocalMusicManager.shared.toggleFavorite(file.id); viewModel.refreshMusicList() }
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { fileToDelete = file } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) { Text("本地音乐").font(.system(size: 18, weight: .semibold)) }
        ToolbarItem(placement: .navigationBarLeading) { Button(action: { showingActionSheet = true }) { Image(systemName: "plus").imageScale(.large) } }
        ToolbarItem(placement: .navigationBarTrailing) { Button(action: { showClearConfirmation = true }) { Image(systemName: "trash").foregroundColor(.red).imageScale(.large) } }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 50)).foregroundColor(.gray)
            Text("还没有添加本地音乐").foregroundColor(.gray)
            Button(action: { showingActionSheet = true }) {
                Text("添加音乐")
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.accentColor).foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowBackground(Color.clear)
    }
}

// MARK: - 文件夹详情视图（支持树结构导航）

struct FolderDetailView: View {
    let folder: MusicFolder
    let parentPath: String  // 累积路径，如 "" 或 "subdir/" 或 "subdir/deeper/"
    @ObservedObject var playerViewModel: PlayerViewModel
    @Binding var selectedTab: Int
    @Binding var fileToDelete: MusicFile?
    @Binding var fileForInfo: MusicFile?

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
            }
            ForEach(directFiles) { file in
                LocalMusicItemView(musicFile: file, action: {
                    playInFolder(file)
                }, onInfo: { fileForInfo = file },
                   onFavorite: { LocalMusicManager.shared.toggleFavorite(file.id) })
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { fileToDelete = file } label: { Label("删除", systemImage: "trash") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(folder.path)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func playInFolder(_ file: MusicFile) {
        guard let result = LocalMusicManager.shared.resolveFileURL(for: file) else { return }
        LocalMusicManager.shared.saveLastPlayedSong(id: file.id)
        let song = Song(title: file.title, artist: file.artist, duration: file.duration,
                        url: result.url, securityScopedRootURL: result.rootURL,
                        folderPath: file.folderPath, folderIdentifier: file.folderIdentifier,
                        relativePath: file.relativePath)
        playerViewModel.playSong(song)
        selectedTab = 0
    }
}

// MARK: - 文件选择器

struct DocumentPicker: UIViewControllerRepresentable {
    let allowedContentTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes)
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls)
        }
    }
}

#Preview {
    NavigationView {
        LocalMusicView(playerViewModel: PlayerViewModel(), selectedTab: .constant(0))
    }
}
