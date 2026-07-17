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

class LocalMusicManager {
    static let shared = LocalMusicManager()
    private let defaults = UserDefaults.standard
    private let musicFilesKey = "musicFiles_v3"
    private let folderBookmarksKey = "folderBookmarks_v1"

    /// 内存缓存，避免频繁反序列化 UserDefaults JSON
    private var cachedFiles: [MusicFile]?
    private var cachedFolders: [MusicFolder]?

    private init() {}

    private func invalidateCache() {
        cachedFiles = nil
        cachedFolders = nil
    }

    // MARK: 文件夹书签持久化

    private func loadBookmarks() -> [String: Data] {
        defaults.dictionary(forKey: folderBookmarksKey) as? [String: Data] ?? [:]
    }

    private func saveBookmarks(_ bookmarks: [String: Data]) {
        defaults.set(bookmarks, forKey: folderBookmarksKey)
    }

    // MARK: 音乐文件列表持久化

    private func saveMusicFiles(_ files: [MusicFile]) {
        if let data = try? JSONEncoder().encode(files) {
            defaults.set(data, forKey: musicFilesKey)
        }
        invalidateCache()
    }

    func loadMusicFiles() -> [MusicFile] {
        guard let data = defaults.data(forKey: musicFilesKey),
              let files = try? JSONDecoder().decode([MusicFile].self, from: data)
        else { return [] }
        return files
    }

    // MARK: 获取所有文件

    func getAllMusicFiles() -> [MusicFile] {
        if let cached = cachedFiles { return cached }
        let files = loadMusicFiles()
        cachedFiles = files
        return files
    }

    func getMusicByFolders() -> [MusicFolder] {
        if let cached = cachedFolders { return cached }
        let folderFiles = loadMusicFiles().filter { $0.folderIdentifier != "loose" }
        var dict: [String: [MusicFile]] = [:]
        for file in folderFiles {
            dict[file.folderIdentifier, default: []].append(file)
        }
        let result = dict.map { (id: String, files: [MusicFile]) in
            let displayName = files.first?.folderPath ?? "未知文件夹"
            let sorted = files.sorted { (a: MusicFile, b: MusicFile) in
                a.title.localizedStandardCompare(b.title) == .orderedAscending
            }
            return MusicFolder(path: displayName, files: sorted)
        }.sorted { (a: MusicFolder, b: MusicFolder) in
            a.path.localizedStandardCompare(b.path) == .orderedAscending
        }
        cachedFolders = result
        // 注意：不要污染 cachedFiles，让 getAllMusicFiles 自己管理缓存
        return result
    }

    // MARK: 书签解析

    /// 获取文件夹书签数据
    func getBookmarkData(for identifier: String) -> Data? {
        loadBookmarks()[identifier]
    }

    /// 解析书签并启动安全域访问，返回根 URL
    func resolveBookmark(for identifier: String) -> URL? {
        guard let bookmarkData = getBookmarkData(for: identifier) else { return nil }
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
            if isStale {
                let newBookmark = try url.bookmarkData(options: [])
                var bookmarks = loadBookmarks()
                bookmarks[identifier] = newBookmark
                saveBookmarks(bookmarks)
            }
            guard url.startAccessingSecurityScopedResource() else { return nil }
            return url
        } catch {
            return nil
        }
    }

    /// 通过文件夹标识和相对路径直接解析文件 URL
    func resolveFileURL(folderIdentifier: String, relativePath: String) -> (url: URL, rootURL: URL)? {
        guard let rootURL = resolveBookmark(for: folderIdentifier) else { return nil }
        let fileURL = rootURL.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            rootURL.stopAccessingSecurityScopedResource()
            return nil
        }
        return (fileURL, rootURL)
    }

    /// 为 MusicFile 解析完整可访问的文件 URL
    func resolveFileURL(for file: MusicFile) -> (url: URL, rootURL: URL)? {
        // 零散文件：用文件级书签
        if file.folderIdentifier == "loose" {
            guard let bookmarkData = getBookmarkData(for: file.id) else { return nil }
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale),
                  url.startAccessingSecurityScopedResource() else { return nil }
            guard FileManager.default.fileExists(atPath: url.path) else {
                url.stopAccessingSecurityScopedResource()
                return nil
            }
            return (url, url)
        }
        // 文件夹导入：用文件夹级书签
        guard let rootURL = resolveBookmark(for: file.folderIdentifier) else { return nil }
        let fileURL = rootURL.appendingPathComponent(file.relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            rootURL.stopAccessingSecurityScopedResource()
            return nil
        }
        return (fileURL, rootURL)
    }

    // MARK: 添加文件

    func addMusicFiles(_ urls: [URL]) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let existingFiles = self.loadMusicFiles()
            var bookmarks = self.loadBookmarks()
            var newFiles: [MusicFile] = []

            // 对每个文件单独处理（文件选择器给的权限是文件级别，不是目录级别）
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                let ext = url.pathExtension.lowercased()
                guard ["mp3", "wav", "m4a", "aac"].contains(ext) else { continue }

                let meta = await self.loadMetadataAsync(from: url)
                let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                let fileId = UUID().uuidString

                // 为每个零散文件创建独立书签
                if let fileBookmark = try? url.bookmarkData(options: []) {
                    bookmarks[fileId] = fileBookmark
                }

                newFiles.append(MusicFile(
                    id: fileId,
                    fileName: url.lastPathComponent,
                    folderPath: "导入的文件",
                    folderIdentifier: "loose",   // 标记为零散文件
                    relativePath: url.lastPathComponent,
                    title: meta.title ?? url.deletingPathExtension().lastPathComponent,
                    artist: meta.artist ?? "未知艺术家",
                    duration: meta.duration,
                    fileSize: Int64(fileSize)
                ))
            }

            let allFiles = existingFiles + newFiles
            let finalBookmarks = bookmarks
            await MainActor.run {
                self.saveBookmarks(finalBookmarks)
                self.saveMusicFiles(allFiles)
                NotificationCenter.default.post(name: .musicFilesDidUpdate, object: nil)
            }
        }
    }

    // MARK: 添加文件夹

    func addMusicFolder(_ folderURL: URL) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            guard folderURL.startAccessingSecurityScopedResource() else { return }
            defer { folderURL.stopAccessingSecurityScopedResource() }

            let folderName = folderURL.lastPathComponent
            let folderId = UUID().uuidString
            var bookmarks = self.loadBookmarks()

            if bookmarks[folderId] == nil {
                if let bookmarkData = try? folderURL.bookmarkData(options: []) {
                    bookmarks[folderId] = bookmarkData
                }
            }

            // 同步阶段：枚举文件列表（NSEnumerator 不能在 async 上下文使用）
            let fileInfos: [(url: URL, relPath: String)] = {
                var infos: [(url: URL, relPath: String)] = []
                guard let enumerator = FileManager.default.enumerator(
                    at: folderURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) else { return infos }
                for case let fileURL as URL in enumerator {
                    guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                          values.isRegularFile == true else { continue }
                    let ext = fileURL.pathExtension.lowercased()
                    guard ["mp3", "wav", "m4a", "aac"].contains(ext) else { continue }
                    let rootPath = folderURL.path
                    let filePath = fileURL.path
                    let relativePath = filePath.hasPrefix(rootPath)
                        ? String(filePath.dropFirst(rootPath.count + 1))
                        : fileURL.lastPathComponent
                    infos.append((fileURL, relativePath))
                }
                return infos
            }()

            // 异步阶段：并发读取元数据
            let existingFiles = self.loadMusicFiles()
            let results = await self.batchLoadMetadata(from: fileInfos)

            var newFiles: [MusicFile] = []
            for r in results {
                newFiles.append(MusicFile(
                    id: UUID().uuidString,
                    fileName: r.fileName,
                    folderPath: folderName,
                    folderIdentifier: folderId,
                    relativePath: r.relPath,
                    title: r.title ?? URL(fileURLWithPath: r.fileName).deletingPathExtension().lastPathComponent,
                    artist: r.artist ?? "未知艺术家",
                    duration: r.duration,
                    fileSize: r.fileSize
                ))
            }

            let allFiles = existingFiles + newFiles
            let finalBookmarks = bookmarks
            await MainActor.run {
                self.saveBookmarks(finalBookmarks)
                self.saveMusicFiles(allFiles)
                NotificationCenter.default.post(name: .musicFilesDidUpdate, object: nil)
            }
        }
    }

    // MARK: 批量并发元数据读取

    private struct FileMetaResult {
        let fileName: String
        let relPath: String
        let title: String?
        let artist: String?
        let duration: TimeInterval
        let fileSize: Int64
    }

    private func batchLoadMetadata(from files: [(url: URL, relPath: String)]) async -> [FileMetaResult] {
        await withTaskGroup(of: FileMetaResult?.self) { group in
            for (url, relPath) in files {
                group.addTask {
                    let meta = await self.loadMetadataAsync(from: url)
                    let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    return FileMetaResult(
                        fileName: url.lastPathComponent,
                        relPath: relPath,
                        title: meta.title,
                        artist: meta.artist,
                        duration: meta.duration,
                        fileSize: Int64(fileSize)
                    )
                }
            }
            var results: [FileMetaResult] = []
            for await result in group {
                if let r = result { results.append(r) }
            }
            return results
        }
    }

    private func loadMetadataAsync(from url: URL) async -> (title: String?, artist: String?, duration: TimeInterval) {
        let asset = AVURLAsset(url: url)
        do {
            let d = try await asset.load(.duration)
            let dur = d.seconds.isNaN ? 0 : d.seconds
            let metadata = try await asset.load(.commonMetadata)
            var title: String?
            var artist: String?
            for item in metadata {
                if let key = item.commonKey {
                    let val = try await item.load(.stringValue)
                    switch key {
                    case .commonKeyTitle: title = val
                    case .commonKeyArtist: artist = val
                    default: break
                    }
                }
            }
            return (title, artist, dur)
        } catch {
            return (nil, nil, 0)
        }
    }

    // MARK: 删除

    func removeMusicFile(_ file: MusicFile) {
        var files = loadMusicFiles()
        files.removeAll { $0.id == file.id }
        saveMusicFiles(files)

        var bookmarks = loadBookmarks()
        if file.folderIdentifier == "loose" {
            // 零散文件：清理文件级书签
            bookmarks.removeValue(forKey: file.id)
        } else {
            // 文件夹导入：如果文件夹空了清理文件夹书签
            let remaining = files.filter { $0.folderIdentifier == file.folderIdentifier }
            if remaining.isEmpty {
                bookmarks.removeValue(forKey: file.folderIdentifier)
            }
        }
        saveBookmarks(bookmarks)
    }

    func clearAllMusic() {
        invalidateCache()
        // 清空记录和书签
        defaults.removeObject(forKey: musicFilesKey)
        defaults.removeObject(forKey: folderBookmarksKey)
        defaults.removeObject(forKey: "musicFolders")
        defaults.removeObject(forKey: "lastPlayedSongID")
        defaults.removeObject(forKey: "perFileProgress")
        defaults.removeObject(forKey: "lastPlayedSongInfo")
        defaults.removeObject(forKey: "lastPlaybackTime")
        defaults.removeObject(forKey: "lastPlaybackDuration")
        defaults.removeObject(forKey: "lastPlaybackProgress")
        defaults.removeObject(forKey: "lastPlaybackVolume")
        defaults.removeObject(forKey: "lastPlaybackRate")
        defaults.removeObject(forKey: "lastRepeatMode")
        defaults.removeObject(forKey: "lastShuffleEnabled")
        defaults.synchronize()
    }

    // MARK: 最后播放

    func toggleFavorite(_ fileId: String) {
        var files = loadMusicFiles()
        if let idx = files.firstIndex(where: { $0.id == fileId }) {
            files[idx].isFavorite.toggle()
            saveMusicFiles(files)
        }
    }

    func getFavorites() -> [MusicFile] {
        getAllMusicFiles().filter { $0.isFavorite }
    }

    func saveLastPlayedSong(id: String) {
        defaults.set(id, forKey: "lastPlayedSongID")
    }

    func getLastPlayedSong() -> MusicFile? {
        guard let id = defaults.string(forKey: "lastPlayedSongID") else { return nil }
        return loadMusicFiles().first { $0.id == id }
    }
}

// MARK: - 通知

extension Notification.Name {
    static let musicFilesDidUpdate = Notification.Name("musicFilesDidUpdate")
}
