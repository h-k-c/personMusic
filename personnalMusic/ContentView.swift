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
            NavigationView {
                PlaylistOverlayView(showPlaylist: $showPlaylist, playerViewModel: playerViewModel)
            }
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
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var showClearConfirmation = false
    
    var body: some View {
        ZStack {
            // 背景遮罩
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    showPlaylist = false
                }
            
            // 播放列表内容
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Text("播放列表")
                        .font(.headline)
                    
                    Spacer()
                    
                    // 清空按钮
                    Button(action: {
                        showClearConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .imageScale(.large)
                    }
                    .padding(.trailing, 8)
                    
                    Button(action: {
                        showPlaylist = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .imageScale(.large)
                    }
                }
                .padding()
                .background(Color(.systemBackground).opacity(0.9))
                
                // 列表内容
                ScrollViewReader { proxy in
                    ScrollView {
                        // 缓存文件列表，避免 ForEach 中反复反序列化 UserDefaults
                        let musicFiles = LocalMusicManager.shared.getAllMusicFiles()
                        LazyVStack(spacing: 0) {
                            ForEach(musicFiles) { file in
                                VStack(spacing: 0) {
                                    Button(action: {
                                        playMusicFile(file)
                                    }) {
                                        HStack {
                                            // 播放指示器
                                            if playerViewModel.currentSong?.title == file.title {
                                                Image(systemName: "play.fill")
                                                    .foregroundColor(.accentColor)
                                            } else {
                                                Image(systemName: "music.note")
                                                    .foregroundColor(.gray)
                                            }

                                            // 歌曲信息
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(file.title)
                                                    .lineLimit(1)
                                                    .foregroundColor(.primary)
                                                Text(file.artist)
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                                    .lineLimit(1)
                                            }

                                            Spacer()

                                            // 时长
                                            Text(file.duration.formattedDuration)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                    }
                                    .id(file.id)

                                    if file.id != musicFiles.last?.id {
                                        Divider()
                                            .padding(.leading, 60)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onAppear {
                        scrollProxy = proxy
                        scrollToCurrentSong()
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(15)
            .shadow(radius: 20)
            .frame(maxWidth: .infinity, maxHeight: 400)
            .padding(.horizontal, 20)
            .alert(isPresented: $showClearConfirmation) {
                Alert(
                    title: Text("确认清空"),
                    message: Text("确定要清空所有音乐吗？此操作无法撤销。"),
                    primaryButton: .destructive(Text("清空")) {
                        clearAllMusic()
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
        }
    }
    
    private func scrollToCurrentSong() {
        guard let currentSong = playerViewModel.currentSong,
              let currentFile = LocalMusicManager.shared.getAllMusicFiles().first(where: { $0.title == currentSong.title }) else {
            return
        }
        
        withAnimation {
            scrollProxy?.scrollTo(currentFile.id, anchor: .center)
        }
    }
    
    private func playMusicFile(_ file: MusicFile) {
        if let url = LocalMusicManager.shared.getAccessibleURL(for: file) {
            let song = Song(
                title: file.title,
                artist: file.artist,
                duration: file.duration,
                url: url
            )
            playerViewModel.playSong(song)
            showPlaylist = false
        }
    }
    
    // 清空所有音乐
    private func clearAllMusic() {
        // 停止当前播放
        playerViewModel.clearPlayback()
        // 清空本地音乐管理器中的音乐文件
        LocalMusicManager.shared.clearAllMusic()
        // 关闭播放列表
        showPlaylist = false
    }
}



