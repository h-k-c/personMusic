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
        musicFolders = LocalMusicManager.shared.getMusicByFolders()
    }
    
    // 播放音乐文件
    func playMusic(_ musicFile: MusicFile, playerViewModel: PlayerViewModel, selectedTab: Binding<Int>) {
        if let url = LocalMusicManager.shared.getAccessibleURL(for: musicFile) {
            // 保存最后播放的歌曲ID
            LocalMusicManager.shared.saveLastPlayedSong(id: musicFile.id)
            
            let song = Song(
                title: musicFile.title,
                artist: musicFile.artist,
                duration: musicFile.duration,
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


