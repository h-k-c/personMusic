//
//  personnalMusicTests.swift
//  personnalMusicTests
//

import Testing
import Foundation
@testable import personnalMusic

// MARK: - TimeInterval 格式化

struct TimeIntervalFormattingTests {
    @Test func zero() { #expect(0.formattedDuration == "0:00") }
    @Test func oneMinute() { #expect(60.formattedDuration == "1:00") }
    @Test func oneMinuteOneSecond() { #expect(61.formattedDuration == "1:01") }
    @Test func oneHour() { #expect(3600.formattedDuration == "60:00") }
    @Test func typicalSong() { #expect(245.formattedDuration == "4:05") }
}

// MARK: - MusicFile 模型

struct MusicFileTests {
    @Test func musicFileProperties() {
        let file = MusicFile(id: "1", fileName: "test.mp3", folderPath: "MyMusic",
                             folderIdentifier: "folder-1", relativePath: "subdir/test.mp3",
                             title: "Test", artist: "Tester", duration: 100,
                             fileSize: 1000)
        #expect(file.fileFormat == "MP3")
        #expect(!file.fileSizeString.isEmpty)
        #expect(file.titleFromFileName == "test")
        #expect(file.relativePath == "subdir/test.mp3")
    }
}

// MARK: - PlayerViewModel 测试

@MainActor
struct PlayerViewModelTests {
    let vm = PlayerViewModel()

    @Test func initialState() {
        #expect(vm.isPlaying == false)
        #expect(vm.currentSong == nil)
        #expect(vm.playlist.isEmpty)
        #expect(vm.repeatMode == .none)
        #expect(vm.isShuffleEnabled == false)
        #expect(vm.playbackRate == .normal)
    }

    @Test func emptyPlaylistSafe() {
        vm.nextTrack()
        vm.previousTrack()
        #expect(vm.currentSong == nil)
    }

    @Test func playModeCycles() {
        #expect(vm.playMode == .sequential)
        vm.togglePlayMode(); #expect(vm.playMode == .repeatAll)
        vm.togglePlayMode(); #expect(vm.playMode == .repeatOne)
        vm.togglePlayMode(); #expect(vm.playMode == .shuffle)
        vm.togglePlayMode(); #expect(vm.playMode == .sequential)
    }

    @Test func playModeStartsSequential() {
        #expect(vm.playMode == .sequential)
        #expect(vm.isShuffleEnabled == false)
        #expect(vm.repeatMode == .none)
    }

    @Test func playbackRate() {
        vm.setPlaybackRate(.fast150)
        #expect(vm.playbackRate == .fast150)
    }

    @Test func volume() {
        vm.setVolume(0.8)
        #expect(vm.volume == 0.8)
    }

    @Test func formatTime() {
        #expect(vm.formatTime(65) == "01:05")
        #expect(vm.formatTime(3599) == "59:59")
    }

    @Test func timeStrings() {
        vm.currentTime = 65; vm.duration = 240
        #expect(vm.currentTimeString == "01:05")
        #expect(vm.durationString == "04:00")
    }

    @Test func clearPlayback() {
        vm.playlist = Song.samples
        vm.currentSong = Song.samples.first
        vm.clearPlayback()
        #expect(vm.currentSong == nil)
        #expect(vm.playlist.isEmpty)
    }
}

// MARK: - Song 模型

struct SongTests {
    @Test func equality() { #expect(Song.samples[0] == Song.samples[0]) }
    @Test func inequality() { #expect(Song.samples[0] != Song.samples[1]) }
    @Test func count() { #expect(Song.samples.count == 5) }
    @Test func hasTitles() {
        for song in Song.samples { #expect(!song.title.isEmpty) }
    }
}
