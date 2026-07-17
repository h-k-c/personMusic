//
//  LocalMusicView.swift
//  personnalMusic
//
//  本地音乐视图：文件夹卡片 + 文件列表，支持文件夹树结构导航

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct LocalMusicView: View {
    var playerViewModel: PlayerViewModel  // 不观察，避免播放进度刷新阻断导航点击
    @StateObject private var viewModel = LocalMusicViewModel()
    @State private var showingFilePicker = false
    @State private var showingFolderPicker = false
    @State private var showClearConfirmation = false
    @State private var fileToDelete: MusicFile?
    @State private var fileForInfo: MusicFile?
    @Binding var selectedTab: Int

    var body: some View {
        NavigationView {
            List {
                if viewModel.musicFolders.isEmpty && looseFiles.isEmpty {
                    emptyView
                } else {
                    folderSection
                    looseFilesSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
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
                    FolderDetailView(folder: folder, parentPath: "", playerViewModel: playerViewModel, selectedTab: $selectedTab, fileToDelete: $fileToDelete, fileForInfo: $fileForInfo)
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
        ToolbarItem(placement: .navigationBarLeading) {
            Menu {
                Button(action: { showingFolderPicker = true }) {
                    Label("添加文件夹", systemImage: "folder.badge.plus")
                }
                Button(action: { showingFilePicker = true }) {
                    Label("添加文件", systemImage: "doc.badge.plus")
                }
            } label: {
                Image(systemName: "plus").imageScale(.large)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) { Button(action: { showClearConfirmation = true }) { Image(systemName: "trash").foregroundColor(.red).imageScale(.large) } }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 50)).foregroundColor(.gray)
            Text("还没有添加本地音乐").foregroundColor(.gray)
            Menu {
                Button(action: { showingFolderPicker = true }) {
                    Label("添加文件夹", systemImage: "folder.badge.plus")
                }
                Button(action: { showingFilePicker = true }) {
                    Label("添加文件", systemImage: "doc.badge.plus")
                }
            } label: {
                Text("添加音乐")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowBackground(Color.clear)
    }
}


#Preview {
    NavigationView {
        LocalMusicView(playerViewModel: PlayerViewModel(), selectedTab: .constant(0))
    }
}
