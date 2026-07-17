//
//  PlayerViewModel.swift
//  personnalMusic
//
//  播放器视图模型：使用 AVAudioPlayer（适合本地文件），替代 AVPlayer
//

import Foundation
import AVFoundation
import MediaPlayer
import SwiftUI

/// 音乐播放器的视图模型类
@MainActor
class PlayerViewModel: NSObject, ObservableObject, @preconcurrency AVAudioPlayerDelegate {

    // MARK: - Published 属性
    @Published var currentSong: Song?
    @Published var playlist: [Song] = []
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 30.0
    @Published var progress: Float = 0.0
    @Published var volume: Double = 0.5
    @Published var isShuffleEnabled = false
    @Published var repeatMode: RepeatMode = .none
    @Published var playMode: PlayMode = .sequential
    @Published var playbackRate: PlaybackRate = .normal
    // MARK: - 私有属性
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var originalPlaylist: [Song] = []
    private var shuffledPlaylist: [Song] = []
    private var activeScopedURLs = [URL]()

    // MARK: - 枚举
    enum RepeatMode: Int {
        case none = 0
        case all = 1
        case one = 2
    }

    enum PlayMode: Int, CaseIterable {
        case sequential = 0   // 顺序播放
        case repeatAll = 1    // 列表循环
        case repeatOne = 2    // 单曲循环
        case shuffle = 3      // 随机播放

        var iconName: String {
            switch self {
            case .sequential: return "arrow.forward"
            case .repeatAll:  return "repeat"
            case .repeatOne:  return "repeat.1"
            case .shuffle:    return "shuffle"
            }
        }
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

    // MARK: - 初始化
    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        setupRemoteCommandCenter()
    }

    // MARK: - 音频中断
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

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
        @unknown default: break
        }
    }

    // MARK: - 远程控制
    private func setupRemoteCommandCenter() {
        let c = MPRemoteCommandCenter.shared()

        // 启用的命令
        c.playCommand.addTarget { [weak self] _ in self?.play(); return .success }
        c.playCommand.isEnabled = true

        c.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        c.pauseCommand.isEnabled = true

        c.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        c.togglePlayPauseCommand.isEnabled = true

        c.nextTrackCommand.addTarget { [weak self] _ in self?.nextTrack(); return .success }
        c.nextTrackCommand.isEnabled = true

        c.previousTrackCommand.addTarget { [weak self] _ in self?.previousTrack(); return .success }
        c.previousTrackCommand.isEnabled = true

        c.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let e = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: Float(e.positionTime / (self?.duration ?? 1)))
            }
            return .success
        }
        c.changePlaybackPositionCommand.isEnabled = true

        // 显式禁用不支持的远程命令
        c.skipBackwardCommand.isEnabled = false
        c.skipForwardCommand.isEnabled = false
        c.changeRepeatModeCommand.isEnabled = false
        c.changeShuffleModeCommand.isEnabled = false
        c.changePlaybackRateCommand.isEnabled = false
        c.likeCommand.isEnabled = false
        c.dislikeCommand.isEnabled = false
        c.bookmarkCommand.isEnabled = false
        c.seekBackwardCommand.isEnabled = false
        c.seekForwardCommand.isEnabled = false
        c.ratingCommand.isEnabled = false
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        switch playMode {
        case .repeatOne:
            player.currentTime = 0
            player.play()
            isPlaying = true
            updateNowPlaying()
        case .repeatAll, .shuffle:
            nextTrack()
        case .sequential:
            guard let idx = getCurrentIndex(), idx < playlist.count - 1 else {
                stop()
                return
            }
            nextTrack()
        }
    }

    // MARK: - 播放控制
    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func play() {
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
        isPlaying = true
        startTimer()
        updateNowPlaying()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
        updateNowPlaying()
    }

    private func stop() {
        activeScopedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        activeScopedURLs.removeAll()
        player?.stop()
        isPlaying = false
        stopTimer()
        progress = 0
        currentTime = 0
        // 不在 stop 中清空 nowPlayingInfo，避免锁屏控制消失
    }

    // MARK: - 导航
    func previousTrack() {
        guard !playlist.isEmpty else { return }
        if currentSong == nil {
            playSong(playlist.last!)
            return
        }
        guard let idx = getCurrentIndex() else { return }
        if idx > 0 {
            playSong(playlist[idx - 1])
        } else if repeatMode == .all, let last = playlist.last {
            playSong(last)
        }
    }

    func nextTrack() {
        guard !playlist.isEmpty else { return }
        if currentSong == nil {
            playSong(playlist.first!)
            return
        }
        guard let idx = getCurrentIndex() else { return }
        if idx < playlist.count - 1 {
            playSong(playlist[idx + 1])
        } else if repeatMode == .all, let first = playlist.first {
            playSong(first)
        }
    }

    // MARK: - 播放歌曲
    func playSong(_ song: Song) {
        var resolvedURL = song.url
        var resolvedRootURL: URL? = song.securityScopedRootURL

        // 如果没有直接 URL，尝试通过书签解析
        if resolvedURL == nil, let folderId = song.folderIdentifier, let relativePath = song.relativePath {
            if let result = LocalMusicManager.shared.resolveFileURL(folderIdentifier: folderId, relativePath: relativePath) {
                resolvedURL = result.url
                resolvedRootURL = result.rootURL
            }
        }

        guard let url = resolvedURL else { return }
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        // 如果播放列表为空，从本地音乐库构建（确保上/下一首可用）
        if playlist.isEmpty {
            let allFiles = LocalMusicManager.shared.getAllMusicFiles()
            if !allFiles.isEmpty {
                playlist = allFiles.map { file in
                    Song(title: file.title, artist: file.artist, duration: file.duration,
                         url: nil, folderPath: file.folderPath, folderIdentifier: file.folderIdentifier, relativePath: file.relativePath)
                }
            }
        }

        stop()

        // 追踪安全域 URL
        if let rootURL = resolvedRootURL {
            activeScopedURLs.append(rootURL)
        }

        let audioPlayer: AVAudioPlayer?
        // 直接用 Data 方式创建播放器：在安全域激活期间读取文件数据，
        // 绕过 AVAudioPlayer URL 数据源层，不依赖 iCloud/File Provider
        if let data = try? Data(contentsOf: url) {
            audioPlayer = try? AVAudioPlayer(data: data)
        } else {
            audioPlayer = nil
        }

        if let player = audioPlayer {
            player.delegate = self
            player.volume = Float(volume)
            player.enableRate = true
            player.rate = Float(playbackRate.rawValue)
            player.prepareToPlay()
            self.player = player

            currentSong = song
            duration = player.duration

            let savedProgress = getSavedFileProgress(for: url)
            if savedProgress > 0 {
                player.currentTime = savedProgress
            }

            savePlaybackState()
            play()
        }
    }

    func playLocalFile(_ url: URL) {
        // 异步读取元数据
        Task {
            let asset = AVURLAsset(url: url)
            var title = url.lastPathComponent
            var artist = "本地音乐"
            var dur: TimeInterval = 0

            do {
                let seconds = try await asset.load(.duration)
                dur = CMTimeGetSeconds(seconds)
                let metadata = try await asset.load(.commonMetadata)
                for item in metadata {
                    if let key = item.commonKey {
                        let value = try await item.load(.stringValue)
                        switch key {
                        case .commonKeyTitle: title = value ?? title
                        case .commonKeyArtist: artist = value ?? artist
                        default: break
                        }
                    }
                }
            } catch {
                // 使用默认值
            }

            await MainActor.run {
                let song = Song(title: title, artist: artist, duration: dur, url: url)
                if !playlist.contains(where: { $0.id == song.id }) {
                    playlist.append(song)
                }
                playSong(song)
            }
        }
    }

    func addLocalSongs(_ songs: [Song]) {
        let newSongs = songs.filter { s in !playlist.contains(where: { $0.id == s.id }) }
        playlist.append(contentsOf: newSongs)
        if currentSong == nil, let first = newSongs.first {
            currentSong = first
            duration = first.duration
        }
    }

    // MARK: - Seek
    func seek(to progress: Float) {
        guard let player = player else { return }
        player.currentTime = Double(progress) * player.duration
        updateProgress()
        if !isPlaying {
            player.pause()
        }
    }

    // MARK: - 倍速
    func setPlaybackRate(_ rate: PlaybackRate) {
        playbackRate = rate
        player?.enableRate = true
        player?.rate = Float(rate.rawValue)
    }

    func cyclePlaybackRate() {
        let rates = PlaybackRate.allCases
        guard let idx = rates.firstIndex(of: playbackRate) else { return }
        setPlaybackRate(rates[(idx + 1) % rates.count])
    }

    // MARK: - 音量
    func setVolume(_ value: Double) {
        volume = value
        player?.volume = Float(value)
    }

    // MARK: - 随机播放
    func togglePlayMode() {
        let all = PlayMode.allCases
        guard let idx = all.firstIndex(of: playMode) else { return }
        playMode = all[(idx + 1) % all.count]
        applyPlayMode()
    }

    private func applyPlayMode() {
        switch playMode {
        case .sequential:
            restoreOriginalPlaylistIfNeeded()
            repeatMode = .none
            isShuffleEnabled = false
        case .repeatAll:
            restoreOriginalPlaylistIfNeeded()
            repeatMode = .all
            isShuffleEnabled = false
        case .repeatOne:
            restoreOriginalPlaylistIfNeeded()
            repeatMode = .one
            isShuffleEnabled = false
        case .shuffle:
            if !isShuffleEnabled { shufflePlaylist() }
            repeatMode = .none
            isShuffleEnabled = true
        }
    }

    private func restoreOriginalPlaylistIfNeeded() {
        guard isShuffleEnabled, !originalPlaylist.isEmpty else { return }
        playlist = originalPlaylist
        isShuffleEnabled = false
    }

    private func shufflePlaylist() {
        guard !originalPlaylist.isEmpty else { return }
        shuffledPlaylist = playlist.shuffled()
        playlist = shuffledPlaylist
    }

    // MARK: - 旧方法兼容（内部保留）
    private func toggleShuffle() {
        isShuffleEnabled.toggle()
        if isShuffleEnabled {
            originalPlaylist = playlist
            shuffledPlaylist = playlist.shuffled()
            playlist = shuffledPlaylist
        } else {
            playlist = originalPlaylist
        }
    }

    private func toggleRepeatMode() {
        switch repeatMode {
        case .none: repeatMode = .all
        case .all:  repeatMode = .one
        case .one:  repeatMode = .none
        }
    }

    // MARK: - Timer
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateProgress() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateProgress() {
        guard let player = player else { return }
        currentTime = player.currentTime
        duration = player.duration
        progress = player.duration > 0 ? Float(player.currentTime / player.duration) : 0
        saveFileProgressIfNeeded()
        updateNowPlaying()
    }

    // MARK: - 锁屏信息
    private func updateNowPlaying() {
        guard let song = currentSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = song.title
        info[MPMediaItemPropertyArtist] = song.artist
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - 每文件进度记忆
    private let perFileProgressKey = "perFileProgress"

    private func getSavedFileProgress(for url: URL) -> TimeInterval {
        let dict = UserDefaults.standard.dictionary(forKey: perFileProgressKey) as? [String: TimeInterval] ?? [:]
        return dict[url.path] ?? 0
    }

    private func saveFileProgressIfNeeded() {
        guard let url = currentSong?.url, duration > 0 else { return }
        var dict = UserDefaults.standard.dictionary(forKey: perFileProgressKey) as? [String: TimeInterval] ?? [:]
        if currentTime >= duration - 2 {
            dict[url.path] = 0
        } else {
            dict[url.path] = currentTime
        }
        UserDefaults.standard.set(dict, forKey: perFileProgressKey)
    }

    func getSavedProgress(for url: URL) -> TimeInterval {
        getSavedFileProgress(for: url)
    }

    // MARK: - 状态持久化
    func savePlaybackState() {
        guard let song = currentSong else { return }
        // 尝试从 MusicFile 列表匹配当前歌曲以保存 musicFileId
        let allFiles = LocalMusicManager.shared.getAllMusicFiles()
        let matchedFile = allFiles.first { file in
            file.folderIdentifier == song.folderIdentifier && file.relativePath == song.relativePath
        }
        let dict: [String: Any] = [
            "id": song.id.uuidString,
            "title": song.title, "artist": song.artist,
            "duration": song.duration,
            "musicFileId": matchedFile?.id ?? "",
            "folderIdentifier": song.folderIdentifier ?? "",
            "folderPath": song.folderPath ?? "",
            "relativePath": song.relativePath ?? ""
        ]
        UserDefaults.standard.set(dict, forKey: "lastPlayedSongInfo")
        UserDefaults.standard.set(currentTime, forKey: "lastPlaybackTime")
        UserDefaults.standard.set(duration, forKey: "lastPlaybackDuration")
        UserDefaults.standard.set(progress, forKey: "lastPlaybackProgress")
        UserDefaults.standard.set(volume, forKey: "lastPlaybackVolume")
        UserDefaults.standard.set(playbackRate.rawValue, forKey: "lastPlaybackRate")
        UserDefaults.standard.set(repeatMode.rawValue, forKey: "lastRepeatMode")
        UserDefaults.standard.set(isShuffleEnabled, forKey: "lastShuffleEnabled")
        UserDefaults.standard.set(playMode.rawValue, forKey: "lastPlayMode")
        UserDefaults.standard.synchronize()
    }

    func restoreLastPlayback() {
        // 加载所有音乐文件到播放列表（不解析书签，只存储索引信息）
        let allFiles = LocalMusicManager.shared.getAllMusicFiles()
        playlist = allFiles.map { file in
            Song(title: file.title, artist: file.artist, duration: file.duration,
                 url: nil, folderPath: file.folderPath, folderIdentifier: file.folderIdentifier, relativePath: file.relativePath)
        }

        // 恢复播放器设置
        if let v = UserDefaults.standard.object(forKey: "lastPlaybackVolume") as? Double { volume = v }
        if let r = UserDefaults.standard.object(forKey: "lastPlaybackRate") as? Double,
           let rate = PlaybackRate(rawValue: r) { playbackRate = rate }
        if let m = UserDefaults.standard.object(forKey: "lastRepeatMode") as? Int {
            repeatMode = RepeatMode(rawValue: m) ?? .none
        }
        isShuffleEnabled = UserDefaults.standard.bool(forKey: "lastShuffleEnabled")
        if let pm = UserDefaults.standard.object(forKey: "lastPlayMode") as? Int,
           let mode = PlayMode(rawValue: pm) {
            playMode = mode
        } else {
            // 从旧的独立字段迁移
            switch (isShuffleEnabled, repeatMode) {
            case (true, _):  playMode = .shuffle
            case (false, .all): playMode = .repeatAll
            case (false, .one): playMode = .repeatOne
            default:           playMode = .sequential
            }
        }

        // 恢复上次歌曲
        guard let songDict = UserDefaults.standard.dictionary(forKey: "lastPlayedSongInfo"),
              let title = songDict["title"] as? String,
              let artist = songDict["artist"] as? String,
              let dur = songDict["duration"] as? TimeInterval else { return }

        // 通过 MusicFile ID 或 folderPath 找回歌曲
        let savedSong: Song?
        if let musicFileId = songDict["musicFileId"] as? String,
           let matchedFile = allFiles.first(where: { $0.id == musicFileId }) {
            savedSong = Song(title: matchedFile.title, artist: matchedFile.artist,
                             duration: matchedFile.duration, url: nil,
                             folderPath: matchedFile.folderPath, folderIdentifier: matchedFile.folderIdentifier, relativePath: matchedFile.relativePath)
        } else {
            savedSong = playlist.first(where: { $0.title == title && $0.artist == artist })
        }
        guard let song = savedSong else { return }

        currentSong = song
        self.duration = dur

        // 恢复文件进度
        let fileProgress = getSavedFileProgress(for: song.url ?? URL(fileURLWithPath: ""))
        currentTime = fileProgress > 0 ? fileProgress : (UserDefaults.standard.object(forKey: "lastPlaybackTime") as? TimeInterval ?? 0)
        progress = UserDefaults.standard.object(forKey: "lastPlaybackProgress") as? Float ?? 0

        // 尝试解析书签并预创建 AVAudioPlayer
        if let folderId = song.folderIdentifier, let relativePath = song.relativePath,
           let result = LocalMusicManager.shared.resolveFileURL(folderIdentifier: folderId, relativePath: relativePath) {
            let url = result.url
            activeScopedURLs.append(result.rootURL)

            if let audioPlayer = try? AVAudioPlayer(contentsOf: url) {
                audioPlayer.delegate = self
                audioPlayer.volume = Float(volume)
                audioPlayer.enableRate = true
                audioPlayer.prepareToPlay()
                if fileProgress > 0 { audioPlayer.currentTime = fileProgress }
                self.player = audioPlayer
                // 更新 currentSong 的 url 以便进度保存
                var restoredSong = song
                restoredSong.securityScopedRootURL = result.rootURL
                currentSong = Song(title: song.title, artist: song.artist, duration: song.duration,
                                   url: url, securityScopedRootURL: result.rootURL,
                                   folderPath: song.folderPath, folderIdentifier: folderId, relativePath: relativePath)
            }
        }
        updateNowPlaying()
        isPlaying = false
    }

    // MARK: - 辅助
    private func getCurrentIndex() -> Int? {
        guard let song = currentSong else { return nil }
        // 优先通过 folderIdentifier + relativePath 匹配（唯一标识）
        if let fid = song.folderIdentifier, let rp = song.relativePath {
            if let idx = playlist.firstIndex(where: { $0.folderIdentifier == fid && $0.relativePath == rp }) {
                return idx
            }
        }
        // 其次通过 title + artist
        if let idx = playlist.firstIndex(where: { $0.title == song.title && $0.artist == song.artist }) {
            return idx
        }
        // 最后通过 URL 路径
        if let path = song.url?.path {
            return playlist.firstIndex { $0.url?.path == path }
        }
        return nil
    }

    // MARK: - 清空
    func clearPlayback() {
        stop()
        currentSong = nil
        playlist = []
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - 时间格式化
    func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60, s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }

    var currentTimeString: String { formatTime(currentTime) }
    var durationString: String { formatTime(duration) }
    var timeDisplayString: String { "\(currentTimeString) / \(durationString)" }

    deinit {
        activeScopedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}
