//
//  PlaybackControlsView.swift
//  personnalMusic
//
//  播放控制按钮组件：包含播放/暂停、上一首、下一首和倍速控制

import SwiftUI

struct PlaybackControlsView: View {
    @ObservedObject var playerViewModel: PlayerViewModel

    var body: some View {
        VStack(spacing: 15) {
            // 主播放控制按钮
            HStack(spacing: 25) {
                // 上一曲按钮
                Button {
                    playerViewModel.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.black)
                }
                
                // 播放/暂停按钮
                Button {
                    playerViewModel.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white)
                    }
                }
                
                // 下一曲按钮
                Button {
                    playerViewModel.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.black)
                }
            }
            
            // 额外控制按钮
            HStack(spacing: 40) {
                // 播放模式按钮（顺序 → 列表循环 → 单曲循环 → 随机）
                Button {
                    playerViewModel.togglePlayMode()
                } label: {
                    Image(systemName: playerViewModel.playMode.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(playerViewModel.playMode == .sequential ? .gray : .black)
                }

                // 倍速按钮（点击循环切换，无弹窗）
                Button {
                    playerViewModel.cyclePlaybackRate()
                } label: {
                    Text(playerViewModel.playbackRate.label)
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                }
            }
        }
    }
    
}

#Preview(traits: .sizeThatFitsLayout) {
    PlaybackControlsView(playerViewModel: PlayerViewModel())
        .padding()
}
