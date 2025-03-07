//
//  AlbumCoverView.swift
//  personnalMusic
//
//  专辑封面视图：带有渐变和模糊效果

import SwiftUI

struct AlbumCoverView: View {
    let isRotating: Bool
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // 默认专辑封面
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .overlay(
                    Image(systemName: "music.note")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(Color(.systemGray))
                )
        }
        .frame(width: 260, height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        .rotationEffect(.degrees(rotation))
        .onChange(of: isRotating) { newValue in
            withAnimation(newValue ? 
                .linear(duration: 20).repeatForever(autoreverses: false) : 
                .linear(duration: 0.2)) {
                rotation = newValue ? 360 : rotation
            }
        }
    }
}

struct AlbumCoverView_Previews: PreviewProvider {
    static var previews: some View {
        AlbumCoverView(isRotating: false)
            .previewLayout(.sizeThatFits)
            .padding()
    }
} 