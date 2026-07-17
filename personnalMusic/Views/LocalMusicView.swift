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
    @State private var selectedFolder: MusicFolder? = nil
    @Binding var selectedTab: Int

    var body: some View {
        NavigationView {
            List {
                if viewModel.musicFolders.isEmpty {
                    emptyView
                } else {
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

    private var folderSection: some View {
        Section("文件夹") {
            ForEach(viewModel.musicFolders) { folder in
                NavigationLink {
                    FolderDetailView(folder: folder, playerViewModel: playerViewModel, selectedTab: $selectedTab, fileToDelete: $fileToDelete, fileForInfo: $fileForInfo)
                } label: {
                    folderRow(folder)
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
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 14)).foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var looseFiles: [MusicFile] {
        viewModel.musicFolders
            .flatMap { $0.files }
            .filter { $0.folderIdentifier == "imported-files" }
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
            onInfo: { fileForInfo = file }
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
    @ObservedObject var playerViewModel: PlayerViewModel
    @Binding var selectedTab: Int
    @Binding var fileToDelete: MusicFile?
    @Binding var fileForInfo: MusicFile?

    private var subfolders: [(name: String, files: [MusicFile])] {
        var dirs: [String: [MusicFile]] = [:]
        for file in folder.files {
            let parts = file.relativePath.components(separatedBy: "/")
            if parts.count > 1 {
                let subDir = parts[0]
                var f = file
                f.relativePath = parts.dropFirst().joined(separator: "/")
                dirs[subDir, default: []].append(f)
            }
        }
        return dirs.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    private var directFiles: [MusicFile] {
        folder.files.filter { !$0.relativePath.contains("/") }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        List {
            ForEach(subfolders, id: \.name) { sub in
                let subfolder = MusicFolder(path: sub.name, files: sub.files)
                NavigationLink {
                    FolderDetailView(folder: subfolder, playerViewModel: playerViewModel, selectedTab: $selectedTab, fileToDelete: $fileToDelete, fileForInfo: $fileForInfo)
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
                }, onInfo: { fileForInfo = file })
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
