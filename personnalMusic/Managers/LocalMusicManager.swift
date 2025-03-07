import Foundation
import AVFoundation

struct MusicFile: Codable, Identifiable {
    let id: String
    let url: URL
    let folderPath: String
    let fileName: String
    var title: String
    var artist: String
    var duration: TimeInterval
    let bookmarkData: Data?
    
    init(url: URL) {
        self.id = UUID().uuidString
        self.url = url
        self.folderPath = url.deletingLastPathComponent().lastPathComponent // 只保留最后一级文件夹名
        self.fileName = url.lastPathComponent
        self.title = url.deletingPathExtension().lastPathComponent
        self.artist = "本地音乐"
        self.duration = 0
        
        // 创建安全作用域的书签
        do {
            self.bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            // 同步获取音频时长
            let asset = AVURLAsset(url: url)
            let durationItem = asset.duration
            self.duration = CMTimeGetSeconds(durationItem)
            
        } catch {
            print("创建书签失败: \(error)")
            self.bookmarkData = nil
        }
    }
    
    // 获取可访问的URL
    func resolveURL() -> URL? {
        guard let bookmarkData = bookmarkData else { return nil }
        
        do {
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],  // 移除 .withSecurityScope 选项
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            return resolvedURL
        } catch {
            print("解析书签失败: \(error)")
            return nil
        }
    }
}

// 添加用于按文件夹组织的结构
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

class LocalMusicManager {
    static let shared = LocalMusicManager()
    private let userDefaults = UserDefaults.standard
    private let musicFilesKey = "musicFiles"
    private let musicFoldersKey = "musicFolders"
    
    private init() {}  // 确保单例模式
    
    // 保存音乐文件信息
    private func saveMusicFiles(_ musicFiles: [MusicFile]) {
        if let encoded = try? JSONEncoder().encode(musicFiles) {
            userDefaults.set(encoded, forKey: musicFilesKey)
        }
    }
    
    // 加载音乐文件信息
    func loadMusicFiles() -> [MusicFile] {
        guard let data = userDefaults.data(forKey: musicFilesKey),
              let musicFiles = try? JSONDecoder().decode([MusicFile].self, from: data) else {
            return []
        }
        return musicFiles
    }
    
    // 添加音乐文件夹
    func addMusicFolder(_ folderURL: URL) {
        // 开始访问安全作用域的资源
        guard folderURL.startAccessingSecurityScopedResource() else {
            print("无法访问文件夹")
            return
        }
        defer {
            folderURL.stopAccessingSecurityScopedResource()
        }
        
        var musicFiles = loadMusicFiles()
        let newFiles = scanMusicFiles(in: folderURL)
        
        // 过滤掉已存在的文件
        let newMusicFiles = newFiles.filter { newFile in
            !musicFiles.contains { $0.url.path == newFile.url.path }
        }
        
        musicFiles.append(contentsOf: newMusicFiles)
        saveMusicFiles(musicFiles)
    }
    
    // 从音频文件加载元数据
    private func loadMetadata(from url: URL) throws -> (title: String?, artist: String?, duration: TimeInterval) {
        // 开始访问安全作用域的资源
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "LocalMusicManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法访问文件"])
        }
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        let asset = AVURLAsset(url: url)
        var title: String?
        var artist: String?
        var duration: TimeInterval = 0
        
        // 使用信号量来等待异步操作完成
        let semaphore = DispatchSemaphore(value: 0)
        
        // 加载持续时间
        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            duration = asset.duration.seconds
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 2)  // 等待最多2秒
        
        // 加载元数据
        let metadata = asset.metadata
        for item in metadata {
            if let commonKey = item.commonKey {
                switch commonKey.rawValue {
                case AVMetadataKey.commonKeyTitle.rawValue:
                    title = item.stringValue
                case AVMetadataKey.commonKeyArtist.rawValue:
                    artist = item.stringValue
                default:
                    break
                }
            }
        }
        
        return (title, artist, duration)
    }
    
    // 扫描文件夹中的音乐文件
    private func scanMusicFiles(in folderURL: URL) -> [MusicFile] {
        let fileManager = FileManager.default
        var musicFiles: [MusicFile] = []
        
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  let isRegularFile = resourceValues.isRegularFile,
                  isRegularFile else {
                continue
            }
            
            let fileExtension = fileURL.pathExtension.lowercased()
            if ["mp3", "wav", "m4a", "aac"].contains(fileExtension) {
                var musicFile = MusicFile(url: fileURL)
                
                // 尝试读取音频文件的元数据
                if let metadata = try? loadMetadata(from: fileURL) {
                    musicFile.title = metadata.title ?? musicFile.title
                    musicFile.artist = metadata.artist ?? musicFile.artist
                    musicFile.duration = metadata.duration
                }
                
                musicFiles.append(musicFile)
            }
        }
        
        return musicFiles
    }
    
    // 添加单个音乐文件
    func addMusicFiles(_ urls: [URL]) {
        var musicFiles = loadMusicFiles()
        let newFiles = urls.compactMap { url -> MusicFile? in
            guard url.startAccessingSecurityScopedResource() else { return nil }
            defer { url.stopAccessingSecurityScopedResource() }
            return MusicFile(url: url)
        }
        
        // 过滤掉已存在的文件
        let newMusicFiles = newFiles.filter { newFile in
            !musicFiles.contains { $0.url.path == newFile.url.path }
        }
        
        musicFiles.append(contentsOf: newMusicFiles)
        saveMusicFiles(musicFiles)
    }
    
    // 删除音乐文件
    func removeMusicFile(_ musicFile: MusicFile) {
        var musicFiles = loadMusicFiles()
        musicFiles.removeAll { $0.id == musicFile.id }
        saveMusicFiles(musicFiles)
    }
    
    // 获取可访问的URL
    func getAccessibleURL(for musicFile: MusicFile) -> URL? {
        // 尝试从书签恢复URL
        if let resolvedURL = musicFile.resolveURL() {
            return resolvedURL
        }
        
        // 如果书签无效，尝试直接使用原始URL
        if musicFile.url.startAccessingSecurityScopedResource() {
            return musicFile.url
        }
        
        return nil
    }
    
    // 获取按文件夹组织的音乐文件
    func getMusicByFolders() -> [MusicFolder] {
        let musicFiles = loadMusicFiles()
        var folderDict: [String: [MusicFile]] = [:]
        
        // 按文件夹路径组织文件
        for file in musicFiles {
            if folderDict[file.folderPath] == nil {
                folderDict[file.folderPath] = []
            }
            folderDict[file.folderPath]?.append(file)
        }
        
        // 转换为 MusicFolder 数组并按文件夹名称排序
        return folderDict.map { path, files in
            MusicFolder(path: path, files: files.sorted { $0.title < $1.title })
        }.sorted { $0.path < $1.path }
    }
    
    // 获取所有音乐文件（用于播放列表）
    func getAllMusicFiles() -> [MusicFile] {
        return loadMusicFiles().sorted { $0.title < $1.title }
    }
    
    // 获取播放列表（从指定音乐文件开始的20首歌）
    func getPlaylist(startingFrom musicFile: MusicFile) -> [MusicFile] {
        let allFiles = loadMusicFiles()
        guard let startIndex = allFiles.firstIndex(where: { $0.id == musicFile.id }) else {
            return []
        }
        
        let endIndex = min(startIndex + 20, allFiles.count)
        return Array(allFiles[startIndex..<endIndex])
    }
}
