//
//  PlaylistView.swift
//  personnalMusic
//
//  播放列表视图：显示当前播放列表

import SwiftUI

struct PlaylistView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    
    var body: some View {
        List {
            ForEach(playerViewModel.playlist) { song in
                HStack {
                    VStack(alignment: .leading) {
                        Text(song.title)
                            .font(.headline)
                        Text(song.artist)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if playerViewModel.currentSong?.id == song.id {
                        Image(systemName: "music.note")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    playerViewModel.playSong(song)
                }
            }
        }
        .listStyle(PlainListStyle())
    }
} 