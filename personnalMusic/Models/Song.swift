//
//  Song.swift
//  personnalMusic
//
//  歌曲模型：定义了音乐播放器中单个歌曲的数据结构

import Foundation

/// 表示一首歌曲的数据模型
struct Song: Identifiable, Equatable {
    /// 唯一标识符
    let id = UUID()
    /// 歌曲标题
    let title: String
    /// 艺术家名称
    let artist: String
    /// 歌曲时长（秒）
    let duration: TimeInterval
    /// 音频文件的URL
    let url: URL?
    /// 专辑封面图片URL（如果有）
    var albumArtURL: URL?
    /// 安全域根 URL（需要在 stop 时调用 stopAccessingSecurityScopedResource）
    var securityScopedRootURL: URL? = nil
    /// 源文件夹路径（书签 key，用于延迟解析）
    var folderPath: String? = nil
    /// 相对路径（在源文件夹内的路径）
    var relativePath: String? = nil

    init(title: String, artist: String, duration: TimeInterval, url: URL?,
         albumArtURL: URL? = nil, securityScopedRootURL: URL? = nil,
         folderPath: String? = nil, relativePath: String? = nil) {
        self.title = title
        self.artist = artist
        self.duration = duration
        self.url = url
        self.albumArtURL = albumArtURL
        self.securityScopedRootURL = securityScopedRootURL
        self.folderPath = folderPath
        self.relativePath = relativePath
    }

    static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.id == rhs.id
    }

    /// 示例数据
    /// 用于开发和测试阶段
    static var samples: [Song] {
        [
            Song(title: "春江花月夜", artist: "古典音乐", duration: 185, url: nil),
            Song(title: "青花瓷", artist: "周杰伦", duration: 240, url: nil),
            Song(title: "夜曲", artist: "周杰伦", duration: 212, url: nil),
            Song(title: "稻香", artist: "周杰伦", duration: 198, url: nil),
            Song(title: "月光", artist: "莫文蔚", duration: 220, url: nil)
        ]
    }
}

// MARK: - 时长格式化
extension TimeInterval {
    /// 格式化为 mm:ss 格式
    var formattedDuration: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
