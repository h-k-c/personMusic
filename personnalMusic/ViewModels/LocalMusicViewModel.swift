//
//  LocalMusicViewModel.swift
//  personnalMusic
//
//  本地音乐视图模型：管理本地音乐数据和操作

import Foundation
import SwiftUI

@MainActor
class LocalMusicViewModel: ObservableObject {
    @Published var musicFolders: [MusicFolder] = []

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMusicFilesUpdate),
            name: .musicFilesDidUpdate,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleMusicFilesUpdate() {
        Task { @MainActor [weak self] in
            self?.refreshMusicList()
        }
    }
    
    // 刷新音乐列表
    func refreshMusicList() {
        let allFiles = LocalMusicManager.shared.getAllMusicFiles()
        
        // 按文件夹分组并排序
        let groupedFiles = Dictionary(grouping: allFiles) { $0.folderPath }
        
        // 将分组后的文件转换为 MusicFolder 数组，并对文件进行排序
        musicFolders = groupedFiles.map { folderPath, files in
            // 对每个文件夹中的文件按标题字母顺序排序
            let sortedFiles = files.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            return MusicFolder(path: folderPath, files: sortedFiles)
        }
        // 对文件夹按路径字母顺序排序
        .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }
    
    // 播放音乐文件
    func playMusic(_ file: MusicFile, playerViewModel: PlayerViewModel, selectedTab: Binding<Int>) {
        // 通过书签解析文件 URL
        guard let result = LocalMusicManager.shared.resolveFileURL(for: file) else { return }
        LocalMusicManager.shared.saveLastPlayedSong(id: file.id)

        let song = Song(
            title: file.title,
            artist: file.artist,
            duration: file.duration,
            url: result.url,
            securityScopedRootURL: result.rootURL,
            folderPath: file.folderPath,
            relativePath: file.relativePath
        )
        playerViewModel.playSong(song)

        // 跳转到播放界面
        selectedTab.wrappedValue = 0
    }
    
    // 删除单个文件
    func deleteFile(_ file: MusicFile, playerViewModel: PlayerViewModel) {
        // 如果正在播放该文件，先停止
        if playerViewModel.currentSong?.title == file.title && playerViewModel.currentSong?.artist == file.artist {
            playerViewModel.clearPlayback()
        }
        LocalMusicManager.shared.removeMusicFile(file)
        refreshMusicList()
    }

    // 清空所有音乐
    func clearAllMusic(playerViewModel: PlayerViewModel) {
        // 清空本地音乐列表
        LocalMusicManager.shared.clearAllMusic()
        
        // 清空播放器状态
        playerViewModel.clearPlayback()
        
        // 刷新列表
        refreshMusicList()
    }
    
    // 添加音乐文件
    func addMusicFiles(_ urls: [URL]) {
        LocalMusicManager.shared.addMusicFiles(urls)
        refreshMusicList()
    }
    
    // 添加音乐文件夹
    func addMusicFolder(_ url: URL) {
        LocalMusicManager.shared.addMusicFolder(url)
        refreshMusicList()
    }
}


