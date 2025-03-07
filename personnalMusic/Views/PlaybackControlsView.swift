//
//  PlaybackControlsView.swift
//  personnalMusic
//
//  播放控制按钮组件：包含播放/暂停、上一首、下一首和倍速控制

import SwiftUI

struct PlaybackControlsView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @State private var showSpeedPicker = false
    
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
                // 播放模式按钮
                Button {
                    playerViewModel.toggleRepeatMode()
                } label: {
                    Image(systemName: repeatModeIcon)
                        .font(.system(size: 18))
                        .foregroundColor(playerViewModel.repeatMode == .none ? .gray : .black)
                }
                
                // 倍速按钮
                Button {
                    showSpeedPicker = true
                } label: {
                    Text(playerViewModel.playbackRate.label)
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                }
                .popover(isPresented: $showSpeedPicker) {
                    VStack(spacing: 8) {
                        ForEach(PlayerViewModel.PlaybackRate.allCases) { rate in
                            Button {
                                playerViewModel.setPlaybackRate(rate)
                                showSpeedPicker = false
                            } label: {
                                HStack {
                                    Text(rate.label)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if rate == playerViewModel.playbackRate {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.black)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.vertical)
                    .frame(width: 120)
                }
                
                // 随机播放按钮
                Button {
                    playerViewModel.toggleShuffle()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 18))
                        .foregroundColor(playerViewModel.isShuffleEnabled ? .black : .gray)
                }
            }
        }
    }
    
    private var repeatModeIcon: String {
        switch playerViewModel.repeatMode {
        case .none:
            return "repeat"
        case .all:
            return "repeat"
        case .one:
            return "repeat.1"
        }
    }
}

#Preview {
    PlaybackControlsView(playerViewModel: PlayerViewModel())
        .previewLayout(.sizeThatFits)
        .padding()
}
