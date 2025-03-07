//
//  LocalMusicViewModel.swift
//  personnalMusic
//
//  本地音乐视图模型：管理本地音乐源和状态

import Foundation
import SwiftUI

class LocalMusicViewModel: ObservableObject {
    /// 本地音乐源列表
    @Published var musicSources: [MusicSource] = []
    /// 错误信息
    @Published var errorMessage: String?
    /// 是否显示错误提示
    @Published var showError = false
    
    init() {
        loadSavedSources()
    }
    
    /// 加载保存的音乐源
    private func loadSavedSources() {
        musicSources = AudioFileManager.shared.loadMusicSources()
    }
    
    /// 添加新的音乐源
    /// - Parameter url: 选中的文件夹URL
    func addMusicSource(url: URL) {
        // 检查是否已经添加过该文件夹
        if musicSources.contains(where: { $0.url == url }) {
            showError(message: "该文件夹已经添加过了")
            return
        }
        
        // 获取文件夹中的音频文件数量
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            let audioFiles = contents.filter { url in
                let fileExtension = url.pathExtension.lowercased()
                return ["mp3", "wav", "m4a", "aac"].contains(fileExtension)
            }
            
            if audioFiles.isEmpty {
                showError(message: "该文件夹中没有音频文件")
                return
            }
            
            // 创建新的音乐源
            let source = MusicSource(
                name: url.lastPathComponent,
                url: url,
                songCount: audioFiles.count
            )
            
            DispatchQueue.main.async {
                self.musicSources.append(source)
                // 保存更新后的音乐源列表
                AudioFileManager.shared.saveMusicSources(self.musicSources)
            }
        } catch {
            showError(message: "读取文件夹失败: \(error.localizedDescription)")
        }
    }
    
    /// 从音乐源加载歌曲
    /// - Parameter source: 音乐源
    /// - Returns: 歌曲列表
    func loadSongs(from source: MusicSource) -> [Song] {
        var songs: [Song] = []
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: source.url, includingPropertiesForKeys: nil)
            let audioFiles = contents.filter { url in
                let fileExtension = url.pathExtension.lowercased()
                return ["mp3", "wav", "m4a", "aac"].contains(fileExtension)
            }
            
            songs = audioFiles.map { url in
                let metadata = AudioFileManager.shared.getAudioMetadata(from: url)
                return Song(
                    title: metadata.title,
                    artist: metadata.artist,
                    duration: metadata.duration,
                    url: url
                )
            }
        } catch {
            showError(message: "加载歌曲失败: \(error.localizedDescription)")
        }
        
        return songs
    }
    
    /// 删除音乐源
    /// - Parameter source: 要删除的音乐源
    func removeSource(_ source: MusicSource) {
        musicSources.removeAll { $0.id == source.id }
        AudioFileManager.shared.saveMusicSources(musicSources)
    }
    
    /// 显示错误信息
    /// - Parameter message: 错误信息
    private func showError(message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.showError = true
        }
    }
}
