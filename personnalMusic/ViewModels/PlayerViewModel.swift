//
//  PlayerViewModel.swift
//  personnalMusic
//
//  播放器视图模型：负责管理音乐播放的核心逻辑和状态

import Foundation
import AVFoundation
import MediaPlayer
import SwiftUI

/// 音乐播放器的视图模型类
/// 负责处理播放逻辑和状态管理
class PlayerViewModel: ObservableObject {
    // MARK: - Published 属性
    /// 当前播放的歌曲
    @Published var currentSong: Song?
    /// 播放列表
    @Published var playlist: [Song] = []
    /// 是否正在播放
    @Published var isPlaying: Bool = false
    /// 当前播放时间（秒）
    @Published var currentTime: TimeInterval = 0
    /// 当前歌曲总时长（秒）
    @Published var duration: TimeInterval = 30.0
    /// 播放进度（0-1之间的值）
    @Published var progress: Float = 0.0
    /// 音量
    @Published var volume: Double = 0.5
    /// 是否启用随机播放
    @Published var isShuffleEnabled = false
    /// 重复模式
    @Published var repeatMode: RepeatMode = .none
    /// 播放速度
    @Published var playbackRate: PlaybackRate = .normal
    
    // MARK: - 私有属性
    /// AVPlayer 实例，用于实际的音频播放
    var player: AVPlayer?
    /// 时间观察器，用于监控播放进度
    private var timeObserver: Any?
    /// 原始播放列表
    private var originalPlaylist: [Song] = []
    /// 随机播放列表
    private var shuffledPlaylist: [Song] = []
    
    // MARK: - 枚举
    enum RepeatMode {
        case none
        case all
        case one
    }
    
    enum PlaybackRate: Double, CaseIterable, Identifiable {
        case slow75 = 0.75
        case normal = 1.0
        case fast125 = 1.25
        case fast150 = 1.5
        case fast175 = 1.75
        case fast200 = 2.0
        
        var id: Double { self.rawValue }
        
        var label: String {
            switch self {
            case .slow75: return "0.75x"
            case .normal: return "1.0x"
            case .fast125: return "1.25x"
            case .fast150: return "1.5x"
            case .fast175: return "1.75x"
            case .fast200: return "2.0x"
            }
        }
    }
    
    // MARK: - 初始化方法
    init() {
        self.isPlaying = false
        self.progress = 0.0
        self.currentTime = 0
        self.duration = 30.0
        self.playlist = []
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    /// 设置音频会话
    /// 配置应用程序的音频行为
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("设置音频会话失败: \(error)")
        }
    }
    
    // MARK: - 远程控制设置
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }
    }
    
    // MARK: - 播放控制方法
    /// 切换播放/暂停状态
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func play() {
        player?.play()
        isPlaying = true
        updateNowPlaying()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlaying()
    }
    
    /// 播放上一首歌曲
    func previousTrack() {
        guard let currentIndex = getCurrentIndex() else { return }
        let newIndex = (currentIndex - 1 + playlist.count) % playlist.count
        playSong(playlist[newIndex])
    }
    
    /// 播放下一首歌曲
    func nextTrack() {
        guard let currentIndex = getCurrentIndex() else { return }
        
        switch repeatMode {
        case .one:
            // 单曲循环，重新播放当前歌曲
            playSong(playlist[currentIndex])
        case .all:
            // 列表循环
            let newIndex = (currentIndex + 1) % playlist.count
            playSong(playlist[newIndex])
        case .none:
            // 不循环，到达末尾停止
            if currentIndex < playlist.count - 1 {
                playSong(playlist[currentIndex + 1])
            }
        }
    }
    
    func setVolume(_ value: Double) {
        volume = value
        player?.volume = Float(value)
    }
    
    // 跳转到指定进度
    func seek(to progress: Float) {
        guard let player = player, let currentSong = currentSong else { return }
        
        // 计算目标时间
        let targetTime = Double(progress) * currentSong.duration
        
        // 创建 CMTime
        let time = CMTime(seconds: targetTime, preferredTimescale: 1000)
        
        // 跳转到指定时间
        player.seek(to: time) { [weak self] finished in
            if finished {
                // 更新当前进度
                self?.progress = progress
                
                // 如果当前是暂停状态，保持暂停
                if !(self?.isPlaying ?? true) {
                    self?.player?.pause()
                }
            }
        }
    }
    
    // MARK: - 倍速播放控制
    func setPlaybackRate(_ rate: PlaybackRate) {
        playbackRate = rate
        player?.rate = Float(rate.rawValue)
    }
    
    func cyclePlaybackRate() {
        let rates = PlaybackRate.allCases
        guard let currentIndex = rates.firstIndex(of: playbackRate) else { return }
        let nextIndex = (currentIndex + 1) % rates.count
        setPlaybackRate(rates[nextIndex])
    }
    
    // MARK: - 播放列表管理
    /// 切换随机播放状态
    func toggleShuffle() {
        isShuffleEnabled.toggle()
        if isShuffleEnabled {
            originalPlaylist = playlist
            shuffledPlaylist = playlist.shuffled()
            playlist = shuffledPlaylist
        } else {
            playlist = originalPlaylist
        }
    }
    
    /// 切换重复模式
    func toggleRepeatMode() {
        switch repeatMode {
        case .none:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .none
        }
    }
    
    // MARK: - 播放歌曲
    /// 播放指定的歌曲
    /// - Parameter song: 要播放的歌曲
    func playSong(_ song: Song) {
        currentSong = song
        // 这里应该设置实际的音频URL
        guard let url = song.url else { return }
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = Float(volume)
        player?.rate = Float(playbackRate.rawValue)
        
        // 设置时间观察器
        removeTimeObserver()
        setupTimeObserver()
        
        // 设置播放结束通知
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        
        // 保存最后播放的歌曲ID
        if let musicFile = LocalMusicManager.shared.getAllMusicFiles().first(where: { $0.title == song.title }) {
            LocalMusicManager.shared.saveLastPlayedSong(id: musicFile.id)
        }
        
        play()
    }
    
    // MARK: - 播放本地文件
    func playLocalFile(_ url: URL) {
        // 创建 AVAsset 来获取音频信息
        let asset = AVAsset(url: url)
        
        // 异步加载音频时长和元数据
        Task {
            do {
                // 获取音频时长
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                
                // 获取元数据
                let metadata = try await asset.load(.commonMetadata)
                var title = url.lastPathComponent
                var artist = "本地音乐"
                
                // 尝试从元数据中获取标题和艺术家信息
                for item in metadata {
                    if let commonKey = item.commonKey {
                        let value = try await item.load(.value)
                        
                        switch commonKey.rawValue {
                        case AVMetadataKey.commonKeyTitle.rawValue:
                            if let titleStr = value as? String {
                                title = titleStr
                            }
                        case AVMetadataKey.commonKeyArtist.rawValue:
                            if let artistStr = value as? String {
                                artist = artistStr
                            }
                        default:
                            break
                        }
                    }
                }
                
                // 在主线程更新 UI
                await MainActor.run {
                    // 创建新的 Song 对象
                    let song = Song(
                        title: title,
                        artist: artist,
                        duration: durationSeconds,
                        url: url
                    )
                    
                    // 如果歌曲不在播放列表中，添加它
                    if !playlist.contains(where: { $0.id == song.id }) {
                        playlist.append(song)
                    }
                    
                    // 设置当前歌曲
                    currentSong = song
                    self.duration = durationSeconds
                    
                    // 创建新的 AVPlayer 实例
                    let playerItem = AVPlayerItem(asset: asset)
                    player = AVPlayer(playerItem: playerItem)
                    player?.volume = Float(volume)
                    player?.rate = Float(playbackRate.rawValue)
                    
                    // 设置时间观察器
                    removeTimeObserver()
                    setupTimeObserver()
                    
                    // 开始播放
                    play()
                }
            } catch {
                print("加载音频文件失败: \(error)")
            }
        }
    }
    
    // MARK: - 添加本地歌曲到播放列表
    func addLocalSongs(_ songs: [Song]) {
        // 过滤掉已经存在的歌曲
        let newSongs = songs.filter { song in
            !playlist.contains(where: { $0.id == song.id })
        }
        playlist.append(contentsOf: newSongs)
        
        // 如果当前没有正在播放的歌曲，播放第一首新添加的歌曲
        if currentSong == nil, let firstSong = newSongs.first {
            playSong(firstSong)
        }
    }
    
    // MARK: - 测试数据
    static var samples: [Song] {
        let musicFolderURL = Bundle.main.resourceURL?.appendingPathComponent("music")
        guard let url = musicFolderURL,
              let contents = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }
        
        return contents
            .filter { $0.pathExtension.lowercased() == "mp3" }
            .map { url in
                Song(
                    title: url.deletingPathExtension().lastPathComponent,
                    artist: "本地音乐",
                    duration: 0,
                    url: url
                )
            }
    }
    
    // MARK: - 私有辅助方法
    /// 获取当前播放歌曲在播放列表中的索引
    /// - Returns: 当前歌曲的索引，如果没有当前歌曲则返回 nil
    private func getCurrentIndex() -> Int? {
        guard let currentSong = currentSong else { return nil }
        return playlist.firstIndex(where: { $0.id == currentSong.id })
    }
    
    private func setupTimeObserver() {
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self,
                  let duration = self.player?.currentItem?.duration,
                  !duration.seconds.isNaN else { return }
            
            self.currentTime = time.seconds
            self.duration = duration.seconds
            self.progress = Float(self.currentTime / self.duration)
            self.updateNowPlaying()
        }
    }
    
    private func removeTimeObserver() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }
    
    @objc private func playerItemDidFinish() {
        nextTrack()
    }
    
    // MARK: - 锁屏控制
    private func updateNowPlaying() {
        guard let song = currentSong else { return }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate.rawValue : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - 析构方法
    deinit {
        NotificationCenter.default.removeObserver(self)
        removeTimeObserver()
    }
    
    // 清空播放状态
    func clearPlayback() {
        // 停止当前播放
        player?.pause()
        
        // 移除时间观察器
        removeTimeObserver()
        
        // 重置所有状态
        currentSong = nil
        playlist = []
        isPlaying = false
        currentTime = 0
        duration = 30.0
        progress = 0.0
        
        // 更新锁屏信息
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    // 恢复上次播放
    func restoreLastPlayback() {
        // 获取上次播放的歌曲
        if let lastPlayedSong = LocalMusicManager.shared.getLastPlayedSong(),
           let url = LocalMusicManager.shared.getAccessibleURL(for: lastPlayedSong) {
            
            // 创建歌曲对象
            let song = Song(
                title: lastPlayedSong.title,
                artist: lastPlayedSong.artist,
                duration: lastPlayedSong.duration,
                url: url
            )
            
            // 设置当前歌曲但不自动播放
            currentSong = song
            duration = song.duration
            
            // 创建播放器但不开始播放
            let playerItem = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: playerItem)
            player?.volume = Float(volume)
            player?.rate = Float(playbackRate.rawValue)
            
            // 设置时间观察器
            setupTimeObserver()
            
            // 设置播放结束通知
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            
            // 加载播放列表
            let allFiles = LocalMusicManager.shared.getAllMusicFiles()
            playlist = allFiles.compactMap { file -> Song? in
                guard let url = LocalMusicManager.shared.getAccessibleURL(for: file) else { return nil }
                return Song(
                    title: file.title,
                    artist: file.artist,
                    duration: file.duration,
                    url: url
                )
            }
        }
    }
}

