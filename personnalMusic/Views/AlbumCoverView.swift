import SwiftUI

struct AlbumCoverView: View {
    let isRotating: Bool
    
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
    }
}
