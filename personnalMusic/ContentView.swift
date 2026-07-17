//
//  ContentView.swift
//  personnalMusic
//
//  Created by 胡开成 on 2025/3/6.
//
//  主视图：包含音乐播放器的主要界面元素和布局

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var playerViewModel = PlayerViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 播放器标签页
            PlayerContentView(playerViewModel: playerViewModel, selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "play.circle.fill")
                    Text("播放器")
                }
                .tag(0)
            
            // 本地音乐标签页
            LocalMusicView(playerViewModel: playerViewModel, selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("本地音乐")
                }
                .tag(1)

            // 收藏标签页
            FavoritesView(playerViewModel: playerViewModel, selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("收藏")
                }
                .tag(2)
        }
        .accentColor(.primary)
        .onAppear {
            // 激活音频会话（后台播放必须）
            try? AVAudioSession.sharedInstance().setActive(true)
            // 恢复上次播放
            playerViewModel.restoreLastPlayback()
        }
    }
}


#Preview {
    ContentView()
}

