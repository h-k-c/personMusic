//
//  LocalMusicView.swift
//  personnalMusic
//
//  本地音乐视图：显示本地音乐源列表和文件选择器

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct LocalMusicView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @StateObject private var viewModel = LocalMusicViewModel()
    @State private var showingFilePicker = false
    @State private var showingFolderPicker = false
    @State private var showingActionSheet = false
    @State private var showingClearConfirmation = false
    @Binding var selectedTab: Int  // 添加标签页绑定
    
    var body: some View {
        List {
            if viewModel.musicFolders.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("还没有添加本地音乐")
                        .foregroundColor(.gray)
                    Button(action: { showingActionSheet = true }) {
                        Text("添加音乐")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.musicFolders) { folder in
                    Section(header: Text(folder.path)) {
                        ForEach(folder.files) { file in
                            LocalMusicItemView(musicFile: file) {
                                viewModel.playMusic(file, playerViewModel: playerViewModel, selectedTab: $selectedTab)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("本地音乐")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: { showingClearConfirmation = true }) {
                        Image(systemName: "trash")
                    }
                    
                    Button(action: { showingActionSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .confirmationDialog("添加音乐", isPresented: $showingActionSheet) {
            Button("选择文件夹") {
                showingFolderPicker = true
            }
            Button("选择文件") {
                showingFilePicker = true
            }
            Button("取消", role: .cancel) {}
        }
        .alert("清空音乐", isPresented: $showingClearConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                viewModel.clearAllMusic(playerViewModel: playerViewModel)
            }
        } message: {
            Text("确定要清空所有本地音乐和播放记录吗？此操作无法撤销。")
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.addMusicFiles(urls)
            case .failure(let error):
                print("文件选择错误: \(error)")
            }
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let folderURL = urls.first {
                    viewModel.addMusicFolder(folderURL)
                }
            case .failure(let error):
                print("文件夹选择错误: \(error)")
            }
        }
        .onAppear {
            viewModel.refreshMusicList()
        }
    }
}

#Preview {
    NavigationView {
        LocalMusicView(
            playerViewModel: PlayerViewModel(),
            selectedTab: .constant(0)
        )
    }
}

