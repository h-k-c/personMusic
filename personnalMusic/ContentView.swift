//
//  ContentView.swift
//  personnalMusic
//
//  Created by 胡开成 on 2025/3/6.
//
//  主视图：包含音乐播放器的主要界面元素和布局

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var playerViewModel = PlayerViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 播放器标签页
            PlayerContentView(playerViewModel: playerViewModel, selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "play.circle.fill")
                    Text("播放器")
                }
                .tag(0)
            
            // 本地音乐标签页
            LocalMusicView(playerViewModel: playerViewModel, selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("本地音乐")
                }
                .tag(1)
        }
        .accentColor(.primary)
        .onAppear {
            // 激活音频会话（后台播放必须）
            try? AVAudioSession.sharedInstance().setActive(true)
            // 恢复上次播放
            playerViewModel.restoreLastPlayback()
        }
    }
}

// 播放器主视图
struct PlayerContentView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @Binding var selectedTab: Int
    @State private var showPlaylist = false

    var body: some View {
        Group {
            if playerViewModel.currentSong == nil {
                emptyStateView
            } else {
                playerUIView
            }
        }
    }

    // MARK: - 空状态引导页
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 120, height: 120)
                Image(systemName: "headphones")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 8) {
                Text("个播")
                    .font(.title)
                    .bold()
                Text("你的随身音频播放器")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "folder.badge.plus", text: "导入本地音频文件或文件夹")
                featureRow(icon: "goforward.plus", text: "6 档变速播放，学习听课更高效")
                featureRow(icon: "clock.arrow.circlepath", text: "自动记忆每个文件的播放位置")
                featureRow(icon: "lock.display", text: "锁屏控制 + 后台持续播放")
            }
            .padding(.horizontal, 40)

            Spacer()

            Button {
                selectedTab = 1
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("导入音频")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .cornerRadius(12)
            }

            Spacer()
        }
        .padding()
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }

    // MARK: - 播放界面
    private var playerUIView: some View {
        VStack(spacing: 20) {
            // 标题
            Text("我的音乐")
                .font(.title)
                .padding(.top, 20)

            // 专辑封面
            AlbumCoverView(isRotating: playerViewModel.isPlaying)
                .padding(.top, 10)

            // 歌曲信息
            VStack(spacing: 8) {
                Text(playerViewModel.currentSong?.title ?? "未在播放")
                    .font(.title2)
                    .bold()
                Text(playerViewModel.currentSong?.artist ?? "")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.top, 5)

            // 播放进度
            PulsingProgressView(
                progress: Double(playerViewModel.progress),
                isPlaying: playerViewModel.isPlaying,
                onSeek: { progress in
                    playerViewModel.seek(to: Float(progress))
                },
                currentTime: playerViewModel.currentTimeString,
                duration: playerViewModel.durationString
            )
            .padding(.horizontal)

            // 播放控制
            PlaybackControlsView(playerViewModel: playerViewModel)
                .padding(.top, 10)

            // 播放列表按钮
            Button {
                showPlaylist = true
            } label: {
                HStack {
                    Image(systemName: "music.note.list")
                    Text("播放列表")
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 20)
                .background(Color.black.opacity(0.1))
                .cornerRadius(20)
            }
            .padding(.top, 40)

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showPlaylist) {
            PlaylistOverlayView(showPlaylist: $showPlaylist, playerViewModel: playerViewModel)
                .presentationDetents([.medium, .large])
        }
    }
}

// 播放列表项视图
struct PlaylistItemView: View {
    let song: Song
    let isPlaying: Bool
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 播放状态图标
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.black.opacity(0.1) : Color.clear)
                        .frame(width: 40, height: 40)
                    
                    if isPlaying {
                        Image(systemName: "play.fill")
                            .foregroundColor(.black)
                    } else {
                        Image(systemName: "music.note")
                            .foregroundColor(isSelected ? .black : .gray)
                    }
                }
                
                // 歌曲信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    Text(song.artist)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // 歌曲时长
                Text(song.duration.formattedDuration)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    ContentView()
}

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
