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
    enum RepeatMode: Int {
        case none = 0
        case all = 1
        case one = 2
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

        // 处理音频中断（来电、闹钟等）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            pause()
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    play()
                }
            }
        @unknown default:
            break
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
        // 如果当前没有播放歌曲，从最后一首开始播放
        if currentSong == nil {
            if let lastSong = playlist.last {
                playSong(lastSong)
            }
            return
        }

        guard let currentIndex = getCurrentIndex() else {
            if let lastSong = playlist.last {
                playSong(lastSong)
            }
            return
        }

        if currentIndex > 0 {
            let previousSong = playlist[currentIndex - 1]
            playSong(previousSong)
        } else if repeatMode == .all, let lastSong = playlist.last {
            // 列表循环：第一首切换到最后一首
            playSong(lastSong)
        }
    }
    
    /// 播放下一首歌曲
    func nextTrack() {
        // 如果当前没有播放歌曲，从第一首开始播放
        if currentSong == nil {
            if let firstSong = playlist.first {
                playSong(firstSong)
            }
            return
        }
        
        guard let currentIndex = getCurrentIndex() else {
            if let firstSong = playlist.first {
                playSong(firstSong)
            }
            return
        }
        
        if currentIndex < playlist.count - 1 {
            let nextSong = playlist[currentIndex + 1]
            playSong(nextSong)
        } else if repeatMode == .all, let firstSong = playlist.first {
            // 列表循环：最后一首切换到第一首
            playSong(firstSong)
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
    
    // MARK: - 每文件进度记忆
    private let perFileProgressKey = "perFileProgress"

    /// 获取指定文件的上次播放进度
    func getSavedProgress(for url: URL) -> TimeInterval {
        let dict = UserDefaults.standard.dictionary(forKey: perFileProgressKey) as? [String: TimeInterval] ?? [:]
        return dict[url.path] ?? 0
    }

    /// 保存指定文件的播放进度
    private func saveFileProgress(_ time: TimeInterval, for url: URL) {
        var dict = UserDefaults.standard.dictionary(forKey: perFileProgressKey) as? [String: TimeInterval] ?? [:]
        // 如果已经播完（剩余不足2秒），重置进度到开头
        if duration > 2 && time >= duration - 2 {
            dict[url.path] = 0
        } else {
            dict[url.path] = time
        }
        UserDefaults.standard.set(dict, forKey: perFileProgressKey)
    }

    // MARK: - 播放歌曲
    /// 播放指定的歌曲
    /// - Parameter song: 要播放的歌曲
    func playSong(_ song: Song) {
        guard let url = song.url else { return }

        // 验证URL是否可访问
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        // 设置当前歌曲
        currentSong = song

        // 创建新的播放器项
        let playerItem = AVPlayerItem(url: url)

        // 移除旧的观察者
        removeTimeObserver()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

        // 创建新的播放器
        player = AVPlayer(playerItem: playerItem)
        player?.volume = Float(volume)
        player?.rate = Float(playbackRate.rawValue)

        // 恢复该文件的上次播放进度
        let savedProgress = getSavedProgress(for: url)
        if savedProgress > 0 {
            let seekTime = CMTime(seconds: savedProgress, preferredTimescale: 1000)
            player?.seek(to: seekTime)
        }

        // 设置新的观察者
        setupTimeObserver()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )

        // 保存播放状态
        savePlaybackState()

        // 开始播放
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
        
        // 如果当前没有正在播放的歌曲，设置第一首歌但不自动播放
        if currentSong == nil, let firstSong = newSongs.first {
            currentSong = firstSong
            let playerItem = AVPlayerItem(url: firstSong.url!)
            player = AVPlayer(playerItem: playerItem)
            player?.volume = Float(volume)
            player?.rate = 0 // 确保不自动播放
            duration = firstSong.duration
            setupTimeObserver()
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
        
        return playlist.firstIndex(where: { 
            $0.title == currentSong.title && $0.artist == currentSong.artist
        })
    }
    
    private func setupTimeObserver() {
        // 每0.5秒更新一次进度
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)

        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self,
                  let duration = self.player?.currentItem?.duration,
                  !duration.seconds.isNaN else { return }

            self.currentTime = time.seconds
            self.duration = duration.seconds
            self.progress = Float(self.currentTime / self.duration)

            // 保存当前状态
            self.savePlaybackState()

            // 保存每文件进度
            if let url = self.currentSong?.url {
                self.saveFileProgress(time.seconds, for: url)
            }

            // 更新锁屏信息
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
        switch repeatMode {
        case .one:
            // 单曲循环：重新播放当前歌曲
            guard let player = player else { return }
            player.seek(to: .zero)
            play()
        case .all:
            // 列表循环：播下一首，最后一首回到第一首
            guard let currentIndex = getCurrentIndex() else {
                if let firstSong = playlist.first { playSong(firstSong) }
                return
            }
            if currentIndex < playlist.count - 1 {
                playSong(playlist[currentIndex + 1])
            } else if let firstSong = playlist.first {
                playSong(firstSong)
            }
        case .none:
            // 不循环：播下一首，最后一首就停止
            guard let currentIndex = getCurrentIndex() else { return }
            if currentIndex < playlist.count - 1 {
                playSong(playlist[currentIndex + 1])
            }
        }
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
    
    // MARK: - 保存播放状态
    func savePlaybackState() {
        guard let currentSong = currentSong else { return }
    
        
        // 保存当前歌曲信息
        let songDict: [String: Any] = [
            "id": currentSong.id.uuidString,
            "title": currentSong.title,
            "artist": currentSong.artist,
            "duration": currentSong.duration,
            "url": currentSong.url?.absoluteString ?? ""
        ]
        UserDefaults.standard.set(songDict, forKey: "lastPlayedSongInfo")
        
        // 保存播放进度和时长
        UserDefaults.standard.set(currentTime, forKey: "lastPlaybackTime")
        UserDefaults.standard.set(duration, forKey: "lastPlaybackDuration")
        UserDefaults.standard.set(progress, forKey: "lastPlaybackProgress")
        
        // 保存播放器状态
        UserDefaults.standard.set(volume, forKey: "lastPlaybackVolume")
        UserDefaults.standard.set(playbackRate.rawValue, forKey: "lastPlaybackRate")
        UserDefaults.standard.set(repeatMode.rawValue, forKey: "lastRepeatMode")
        UserDefaults.standard.set(isShuffleEnabled, forKey: "lastShuffleEnabled")
        
        // 立即同步
        UserDefaults.standard.synchronize()
        
    }
    
    // MARK: - 恢复上次播放
    func restoreLastPlayback() {
        // 确保清理旧的 observer，防止重复调用时泄漏
        removeTimeObserver()

        // 先加载所有音乐文件到播放列表
        let allFiles = LocalMusicManager.shared.getAllMusicFiles()
        
        playlist = allFiles.compactMap { file -> Song? in
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
        
        // 恢复播放器状态
        if let lastVolume = UserDefaults.standard.object(forKey: "lastPlaybackVolume") as? Double {
            volume = lastVolume
        }
        
        if let lastRate = UserDefaults.standard.object(forKey: "lastPlaybackRate") as? Double,
           let rate = PlaybackRate(rawValue: lastRate) {
            playbackRate = rate
        }
        
        if let lastRepeatMode = UserDefaults.standard.object(forKey: "lastRepeatMode") as? Int {
            switch lastRepeatMode {
            case 0: repeatMode = .none
            case 1: repeatMode = .all
            case 2: repeatMode = .one
            default: repeatMode = .none
            }
        }
        
        isShuffleEnabled = UserDefaults.standard.bool(forKey: "lastShuffleEnabled")
        
        // 从 UserDefaults 获取上次播放的歌曲信息
        if let songDict = UserDefaults.standard.dictionary(forKey: "lastPlayedSongInfo"),
           let title = songDict["title"] as? String,
           let artist = songDict["artist"] as? String,
           let duration = songDict["duration"] as? TimeInterval,
           let urlString = songDict["url"] as? String,
           let url = URL(string: urlString) {
            
            // 创建歌曲对象
            let song = Song(
                title: title,
                artist: artist,
                duration: duration,
                url: url
            )
            
            // 设置当前歌曲但不自动播放
            currentSong = song
            
            // 恢复进度：优先使用每文件记忆的进度
            let perFileProgress = getSavedProgress(for: url)
            if perFileProgress > 0 {
                currentTime = perFileProgress
            } else if let lastTime = UserDefaults.standard.object(forKey: "lastPlaybackTime") as? TimeInterval {
                currentTime = lastTime
            }
            
            if let lastDuration = UserDefaults.standard.object(forKey: "lastPlaybackDuration") as? TimeInterval {
                self.duration = lastDuration
            }
            
            if let lastProgress = UserDefaults.standard.object(forKey: "lastPlaybackProgress") as? Float {
                progress = lastProgress
            }
            
            // 创建播放器但不开始播放
            let playerItem = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: playerItem)
            player?.volume = Float(volume)
            player?.rate = 0 // 确保初始速率为0，不自动播放
            
            // 设置播放位置到上次的进度
            let targetTime = CMTime(seconds: currentTime, preferredTimescale: 1000)
            player?.seek(to: targetTime)
            
            // 设置时间观察器
            setupTimeObserver()
            
            // 设置播放结束通知
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            
            // 更新锁屏信息
            updateNowPlaying()
            
            // 确保播放状态为暂停
            isPlaying = false
        }
    }
    
    // MARK: - 析构方法
    deinit {
        // 保存播放状态
        savePlaybackState()
        
        // 清理观察者
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
    
    // MARK: - 时间格式化
    /// 格式化时间为 "mm:ss" 格式
    func formatTime(_ timeInSeconds: TimeInterval) -> String {
        let minutes = Int(timeInSeconds) / 60
        let seconds = Int(timeInSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// 获取当前播放时间的格式化字符串
    var currentTimeString: String {
        return formatTime(currentTime)
    }
    
    /// 获取总时长的格式化字符串
    var durationString: String {
        return formatTime(duration)
    }
    
    /// 获取完整的时间显示字符串
    var timeDisplayString: String {
        return "\(currentTimeString) / \(durationString)"
    }
}





