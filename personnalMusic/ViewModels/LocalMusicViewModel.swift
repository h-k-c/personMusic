//
//  LocalMusicViewModel.swift
//  personnalMusic
//
//  本地音乐视图模型：管理本地音乐数据和操作

import Foundation
import SwiftUI

class LocalMusicViewModel: ObservableObject {
    @Published var musicFolders: [MusicFolder] = []
    
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
        if let url = LocalMusicManager.shared.getAccessibleURL(for: file) {
            // 保存最后播放的歌曲ID
            LocalMusicManager.shared.saveLastPlayedSong(id: file.id)
            
            let song = Song(
                title: file.title,
                artist: file.artist,
                duration: file.duration,
                url: url
            )
            playerViewModel.playSong(song)
            
            // 跳转到播放界面
            DispatchQueue.main.async {
                selectedTab.wrappedValue = 0
            }
        }
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


