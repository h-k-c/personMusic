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
    @State private var showingFilePicker = false
    @State private var showingFolderPicker = false
    @State private var musicFolders: [MusicFolder] = []
    @State private var showingActionSheet = false
    
    var body: some View {
        List {
            if musicFolders.isEmpty {
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
                ForEach(musicFolders) { folder in
                    Section(header: Text(folder.path)) {
                        ForEach(folder.files) { file in
                            LocalMusicItemView(musicFile: file) {
                                playMusic(file)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("本地音乐")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingActionSheet = true }) {
                    Image(systemName: "plus")
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
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                LocalMusicManager.shared.addMusicFiles(urls)
                refreshMusicList()
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
                    LocalMusicManager.shared.addMusicFolder(folderURL)
                    refreshMusicList()
                }
            case .failure(let error):
                print("文件夹选择错误: \(error)")
            }
        }
        .onAppear {
            refreshMusicList()
        }
    }
    
    private func refreshMusicList() {
        musicFolders = LocalMusicManager.shared.getMusicByFolders()
    }
    
    private func playMusic(_ musicFile: MusicFile) {
        if let url = LocalMusicManager.shared.getAccessibleURL(for: musicFile) {
            let song = Song(
                title: musicFile.title,
                artist: musicFile.artist,
                duration: musicFile.duration,
                url: url
            )
            playerViewModel.playSong(song)
        }
    }
}

struct LocalMusicItemView: View {
    let musicFile: MusicFile
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(musicFile.title)
                        .lineLimit(1)
                    Text(musicFile.artist)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                Spacer()
                Text(formatDuration(musicFile.duration))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
