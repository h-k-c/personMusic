//
//  PulsingProgressView.swift
//  personnalMusic
//
//  自定义进度条：简洁设计

import SwiftUI

struct PulsingProgressView: View {
    let progress: Double
    let isPlaying: Bool
    let onSeek: (Double) -> Void
    
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            // 整个进度条区域
            ZStack(alignment: .leading) {
                // 背景轨道
                Capsule()
                    .fill(Color(.systemGray5))
                    .frame(height: 4)
                
                // 进度条
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(0, min(geometry.size.width * (isDragging ? dragProgress : progress), geometry.size.width)), height: 4)
            }
            .overlay(
                // 拖动手柄
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 16, height: 16)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .position(x: max(8, min(geometry.size.width * (isDragging ? dragProgress : progress), geometry.size.width - 8)), y: 2)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let newProgress = value.location.x / geometry.size.width
                        dragProgress = min(max(newProgress, 0), 1)
                    }
                    .onEnded { _ in
                        onSeek(dragProgress)
                        isDragging = false
                    }
            )
            .animation(isDragging ? nil : .linear(duration: 0.1), value: progress)
        }
        .frame(height: 16)
        .padding(.horizontal, 8) // 添加水平内边距，避免手柄超出边界
    }
}

// 预览
struct PulsingProgressView_Previews: PreviewProvider {
    static var previews: some View {
        PulsingProgressView(
            progress: 0.5,
            isPlaying: true,
            onSeek: { _ in }
        )
        .padding()
        .previewLayout(.fixed(width: 300, height: 50))
    }
} 
