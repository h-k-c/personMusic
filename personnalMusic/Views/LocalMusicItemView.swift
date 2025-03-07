//
//  LocalMusicItemView.swift
//  personnalMusic
//
//  本地音乐列表项视图：显示单个音乐文件的信息

import SwiftUI

struct LocalMusicItemView: View {
    let musicFile: MusicFile
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(musicFile.title)
                        .lineLimit(1)
                    Text(musicFile.artist)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                Spacer()
                Text(formatDuration(musicFile.duration))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    LocalMusicItemView(
        musicFile: MusicFile(
            url: URL(string: "file:///example.mp3")!
        ),
        action: {}
    )
    .previewLayout(.sizeThatFits)
    .padding()
} 