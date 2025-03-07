//
//  AudioFileManager.swift
//  personnalMusic
//
//  音频文件管理工具类：处理音频文件的元数据和持久化存储

import Foundation
import AVFoundation
#if os(macOS)
import AppKit
#endif

class AudioFileManager {
    static let shared = AudioFileManager()
    
    private init() {}
    
    /// 获取音频文件的元数据
    /// - Parameter url: 音频文件的URL
    /// - Returns: 元数据元组 (标题, 艺术家, 时长)
    func getAudioMetadata(from url: URL) -> (title: String, artist: String, duration: TimeInterval) {
        let asset = AVAsset(url: url)
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "未知艺术家"
        var duration: TimeInterval = 0
        
        // 同步获取时长
        duration = CMTimeGetSeconds(asset.duration)
        
        // 同步获取元数据
        let metadata = asset.metadata
        for item in metadata {
            if let commonKey = item.commonKey {
                switch commonKey.rawValue {
                case AVMetadataKey.commonKeyTitle.rawValue:
                    title = (try? item.stringValue) ?? title
                case AVMetadataKey.commonKeyArtist.rawValue:
                    artist = (try? item.stringValue) ?? artist
                default:
                    break
                }
            }
        }
        
        return (title, artist, duration)
    }
    
    /// 选择音乐文件夹
    /// - Returns: 选中的文件夹URL
    func selectMusicFolder() -> URL? {
        #if os(macOS)
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.message = "请选择音乐文件夹"
        openPanel.prompt = "选择"
        
        guard openPanel.runModal() == .OK else {
            return nil
        }
        
        return openPanel.url
        #else
        return nil
        #endif
    }
    
    /// 保存音乐源到UserDefaults
    func saveMusicSources(_ sources: [MusicSource]) {
        let sourceDicts = sources.map { source -> [String: Any] in
            [
                "id": source.id.uuidString,
                "name": source.name,
                "url": source.url.path,
                "songCount": source.songCount
            ]
        }
        UserDefaults.standard.set(sourceDicts, forKey: "MusicSources")
    }
    
    /// 从UserDefaults加载音乐源
    func loadMusicSources() -> [MusicSource] {
        guard let sourceDicts = UserDefaults.standard.array(forKey: "MusicSources") as? [[String: Any]] else {
            return []
        }
        
        return sourceDicts.compactMap { dict -> MusicSource? in
            guard let name = dict["name"] as? String,
                  let path = dict["url"] as? String,
                  let songCount = dict["songCount"] as? Int
            else {
                return nil
            }
            
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                return MusicSource(name: name, url: url, songCount: songCount)
            }
            return nil
        }
    }
    
    /// 检查URL是否可访问
    /// - Parameter url: 要检查的URL
    /// - Returns: 是否可以访问
    func isURLAccessible(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}
