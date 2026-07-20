import Foundation
import AVFoundation
import AudioToolbox


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
        // 零散文件：通过文件名匹配，使用文件级书签
        if folderIdentifier == "loose" {
            let looseFiles = getAllMusicFiles().filter { $0.folderIdentifier == "loose" }
            guard let file = looseFiles.first(where: { $0.relativePath == relativePath }) else { return nil }
            return resolveFileURL(for: file)
        }
        // 文件夹导入：用文件夹级书签
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

            // 过滤有效音频文件并启动安全域访问
            var validURLs: [(url: URL, relPath: String)] = []
            for url in urls {
                let ext = url.pathExtension.lowercased()
                guard ["mp3", "wav", "m4a", "aac"].contains(ext) else { continue }
                guard url.startAccessingSecurityScopedResource() else { continue }
                validURLs.append((url, url.lastPathComponent))
            }
            defer {
                for (url, _) in validURLs { url.stopAccessingSecurityScopedResource() }
            }

            // 并发批量读取元数据（和 addMusicFolder 一样快）
            let results = await self.batchLoadMetadata(from: validURLs)

            var newFiles: [MusicFile] = []
            for r in results {
                let fileId = UUID().uuidString
                if let fileBookmark = try? URL(fileURLWithPath: r.fileName).bookmarkData(options: []) {
                    // 使用实际 URL 创建书签
                    if let match = validURLs.first(where: { $0.url.lastPathComponent == r.fileName }) {
                        if let bk = try? match.url.bookmarkData(options: []) {
                            bookmarks[fileId] = bk
                        }
                    }
                }
                newFiles.append(MusicFile(
                    id: fileId,
                    fileName: r.fileName,
                    folderPath: "导入的文件",
                    folderIdentifier: "loose",
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
        // 分批并发，每批最多 6 个，避免 I/O 争抢
        let batchSize = 6
        var results: [FileMetaResult] = []
        for batch in stride(from: 0, to: files.count, by: batchSize) {
            let batchFiles = Array(files[batch..<min(batch + batchSize, files.count)])
            let batchResults = await withTaskGroup(of: FileMetaResult?.self) { group in
                for (url, relPath) in batchFiles {
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
                var r: [FileMetaResult] = []
                for await result in group {
                    if let result = result { r.append(result) }
                }
                return r
            }
            results.append(contentsOf: batchResults)
        }
        return results
    }

    /// 使用 AudioFile API 直接读文件头获取元数据，比 AVURLAsset 快数倍
    private func loadMetadataAsync(from url: URL) async -> (title: String?, artist: String?, duration: TimeInterval) {
        // 在后台队列执行同步的 AudioFile 读取
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Self.readAudioMetadata(from: url)
                continuation.resume(returning: result)
            }
        }
    }

    /// 同步读取音频文件元数据（AudioToolbox，极快）
    nonisolated private static func readAudioMetadata(from url: URL) -> (title: String?, artist: String?, duration: TimeInterval) {
        var fileID: AudioFileID?
        guard AudioFileOpenURL(url as CFURL, .readPermission, 0, &fileID) == noErr,
              let fid = fileID else {
            return (nil, nil, 0)
        }
        defer { AudioFileClose(fid) }

        // 时长
        var duration: TimeInterval = 0
        var estimated = Float64(0)
        var propSize = UInt32(MemoryLayout<Float64>.size)
        if AudioFileGetProperty(fid, kAudioFilePropertyEstimatedDuration, &propSize, &estimated) == noErr {
            duration = estimated.isNaN ? 0 : max(0, estimated)
        }

        // ID3 / 元数据字典
        var title: String?
        var artist: String?
        var dictSize: UInt32 = 0
        if AudioFileGetPropertyInfo(fid, kAudioFilePropertyInfoDictionary, &dictSize, nil) == noErr,
           dictSize > 0 {
            var cfDict: CFDictionary?
            if AudioFileGetProperty(fid, kAudioFilePropertyInfoDictionary, &dictSize, &cfDict) == noErr,
               let dict = cfDict as? [String: Any] {
                title = (dict["title"] as? String)?.trimmingCharacters(in: .whitespaces)
                artist = (dict["artist"] as? String)?.trimmingCharacters(in: .whitespaces)
            }
        }

        return (title, artist, duration)
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
