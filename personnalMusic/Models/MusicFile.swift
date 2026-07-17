import Foundation
import AVFoundation

// MARK: - 音乐文件模型（文件夹书签版）

import Foundation
import AVFoundation

// MARK: - 音乐文件模型（文件夹书签版）

struct MusicFile: Codable, Identifiable {
    let id: String
    let fileName: String          // 原始文件名 "song.mp3"
    let folderPath: String        // 来源文件夹显示名
    let folderIdentifier: String  // 书签 key（UUID，区分同名文件夹）
    var relativePath: String      // 文件相对源文件夹根目录的路径
    var title: String
    var artist: String
    var duration: TimeInterval
    var isFavorite: Bool = false  // 收藏标记
    let fileSize: Int64           // 文件字节数

    var fileFormat: String {
        fileName.components(separatedBy: ".").last?.uppercased() ?? "?"
    }

    var fileSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    /// 不带扩展名的原始文件名
    var titleFromFileName: String {
        (fileName as NSString).deletingPathExtension
    }
}

// MARK: - 按文件夹组织

struct MusicFolder: Identifiable {
    let id: String
    let path: String
    var files: [MusicFile]

    init(path: String, files: [MusicFile]) {
        self.id = UUID().uuidString
        self.path = path
        self.files = files
    }
}

// MARK: - 本地音乐管理器（文件夹书签版）

