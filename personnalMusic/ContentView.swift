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
            PlayerContentView(playerViewModel: playerViewModel)
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
    @State private var showPlaylist = false
    
    var body: some View {
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
            
            // 播放控制
            PlayerControlsView(playerViewModel: playerViewModel)
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
        .onAppear {
            // 加载所有本地音乐文件到播放列表
            let allFiles = LocalMusicManager.shared.getAllMusicFiles()
            let songs = allFiles.compactMap { file -> Song? in
                guard let url = LocalMusicManager.shared.getAccessibleURL(for: file) else {
                    return nil
                }
                return Song(
                    title: file.title,
                    artist: file.artist,
                    duration: file.duration,
                    url: url
                )
            }
            
            // 更新播放列表
            if !songs.isEmpty {
                print("正在加载 \(songs.count) 首歌曲到播放列表")
                playerViewModel.playlist = songs
                
                // 如果当前没有正在播放的歌曲，设置第一首歌
                if playerViewModel.currentSong == nil, let firstSong = songs.first {
                    print("设置第一首歌曲：\(firstSong.title)")
                    playerViewModel.currentSong = firstSong
                    playerViewModel.duration = firstSong.duration
                }
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
                Text(formatDuration(song.duration))
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
        }
    }
    
    // 格式化时长
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView()
}

// MARK: - 播放器视图
struct PlayerView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var syncManager = SyncManager.shared
    @State private var showThemePicker = false
    @State private var showSyncStatus = false
    @State private var showPlaylist = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景渐变
                themeManager.currentTheme.primaryGradient
                    .opacity(0.1)
                    .ignoresSafeArea()
                
                // 主内容
                VStack(spacing: 20) {
                    // 自定义标题栏
                    CustomTitleBar(
                        title: "我的音乐",
                        syncManager: syncManager,
                        themeManager: themeManager,
                        onSyncTap: { showSyncStatus = true },
                        onThemeTap: { showThemePicker = true }
                    )
                    
                    // 专辑封面区域
                    AlbumCoverView(isRotating: playerViewModel.isPlaying)
                        .padding(.top, 10)
                    
                    // 歌曲信息显示区域
                    SongInfoView(song: playerViewModel.currentSong)
                    
                    // 播放控制区域
                    PlayerControlsView(
                        playerViewModel: playerViewModel
                    )
                    
                    Spacer()
                    
                    // 播放列表按钮
                    PlaylistButton(
                        themeManager: themeManager,
                        onTap: { showPlaylist = true }
                    )
                }
                .padding()
                .navigationBarHidden(true)
                
                // 主题选择弹窗
                if showThemePicker {
                    themePickerOverlay
                }
                
                // 同步状态弹窗
                if showSyncStatus {
                    syncStatusOverlay
                }
                
                // 播放列表弹窗
                if showPlaylist {
                    playlistOverlay
                }
                
                // 同步消息提示
                if syncManager.showSyncMessage {
                    syncMessageOverlay
                }
            }
        }
    }
    
    // MARK: - 提取的弹窗视图
    
    private var themePickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    showThemePicker = false
                }
            
            VStack(spacing: 20) {
                Text("选择主题")
                    .font(.system(size: 16, weight: .medium))
                
                HStack(spacing: 20) {
                    ForEach(AppTheme.allCases) { theme in
                        themeCircle(theme)
                    }
                }
            }
            .padding(25)
            .background(Color(.systemBackground))
            .cornerRadius(15)
            .shadow(radius: 10, x: 0, y: 5)
        }
    }
    
    private func themeCircle(_ theme: AppTheme) -> some View {
        Circle()
            .fill(theme.primaryGradient)
            .frame(width: 36, height: 36)
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(themeManager.currentTheme == theme ? 1 : 0), lineWidth: 2)
            )
            .shadow(color: theme.accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    themeManager.setTheme(theme)
                    showThemePicker = false
                }
            }
    }
    
    private var syncStatusOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    if !syncManager.isSyncing {
                        showSyncStatus = false
                    }
                }
            
            VStack(spacing: 20) {
                if syncManager.isSyncing {
                    syncingContent
                } else {
                    syncedContent
                }
            }
            .padding(25)
            .background(Color(.systemBackground))
            .cornerRadius(15)
            .shadow(radius: 10, x: 0, y: 5)
            .frame(width: 280)
        }
    }
    
    private var syncingContent: some View {
        VStack(spacing: 15) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            
            Text("正在同步...")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
    }
    
    private var syncedContent: some View {
        VStack(spacing: 15) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 30))
                .foregroundColor(themeManager.currentTheme.iconColor)
            
            Text(syncManager.formattedLastSyncTime())
                .font(.system(size: 14))
                .foregroundColor(themeManager.currentTheme.iconColor)
            
            Button(action: {
                syncManager.sync()
            }) {
                Text("同步")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 120)
                    .padding(.vertical, 8)
                    .background(themeManager.currentTheme.iconColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }
    
    private var playlistOverlay: some View {
        PlaylistOverlayView(
            showPlaylist: $showPlaylist,
            playerViewModel: playerViewModel
        )
    }
    
    private var syncMessageOverlay: some View {
        VStack {
            Spacer()
            
            Text(syncManager.syncMessage ?? "")
                .font(.system(size: 14))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(radius: 5, x: 0, y: 2)
                .padding(.bottom, 20)
        }
    }
}

// MARK: - 自定义标题栏
struct CustomTitleBar: View {
    let title: String
    let syncManager: SyncManager
    let themeManager: ThemeManager
    let onSyncTap: () -> Void
    let onThemeTap: () -> Void
    
    var body: some View {
        HStack {
            // 左侧同步按钮
            Button(action: onSyncTap) {
                Image(systemName: syncManager.isSyncing ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath")
                    .foregroundColor(themeManager.currentTheme.iconColor)
                    .imageScale(.large)
            }
            
            Spacer()
            
            // 标题
            Text(title)
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.iconColor)
            
            Spacer()
            
            // 右侧主题按钮
            Button(action: onThemeTap) {
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundColor(themeManager.currentTheme.iconColor)
                    .imageScale(.large)
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

// MARK: - 歌曲信息视图
struct SongInfoView: View {
    let song: Song?
    
    var body: some View {
        VStack(spacing: 8) {
            Text(song?.title ?? "未在播放")
                .font(.title2)
                .bold()
            Text(song?.artist ?? "")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.top, 5)
    }
}

// MARK: - 播放控制区域
struct PlayerControlsView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @State private var showSpeedPicker = false
    
    var body: some View {
        VStack(spacing: 15) {
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
            
            // 播放控制按钮
            HStack(spacing: 40) {
                // 上一首按钮
                Button(action: {
                    playerViewModel.previousTrack()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 32))
                        .frame(width: 50, height: 50)
                }
                
                // 播放/暂停按钮
                Button(action: {
                    playerViewModel.togglePlayPause()
                }) {
                    Image(systemName: playerViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                        .frame(width: 70, height: 70)
                }
                
                // 下一首按钮
                Button(action: {
                    playerViewModel.nextTrack()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 32))
                        .frame(width: 50, height: 50)
                }
            }
            .foregroundColor(.primary)
        }
    }
}

// MARK: - 播放列表按钮
struct PlaylistButton: View {
    let themeManager: ThemeManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 18, weight: .medium))
                Text("播放列表")
                    .font(.system(size: 16, weight: .medium))
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(themeManager.currentTheme.iconColor.opacity(0.15))
                    .shadow(
                        color: themeManager.currentTheme.iconColor.opacity(0.1),
                        radius: 5, x: 0, y: 2
                    )
            )
            .foregroundColor(themeManager.currentTheme.iconColor)
        }
        .padding(.bottom, 20)
    }
}

// MARK: - 播放指示器
struct PlayingIndicator: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Image(systemName: "play.circle.fill")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(themeManager.currentTheme.iconColor)
            .shadow(color: themeManager.currentTheme.iconColor.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 预览提供者
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
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
                        LazyVStack(spacing: 0) {
                            // 使用 LocalMusicManager 获取的音乐文件列表，保持顺序一致
                            ForEach(LocalMusicManager.shared.getAllMusicFiles()) { file in
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
                                            Text(formatDuration(file.duration))
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                    }
                                    .id(file.id)
                                    
                                    if file.id != LocalMusicManager.shared.getAllMusicFiles().last?.id {
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
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
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



