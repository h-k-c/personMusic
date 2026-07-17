import SwiftUI

struct AlbumCoverView: View {
    let isRotating: Bool

    @State private var rotation: Double = 0
    @State private var pulseScale: Double = 1.0

    var body: some View {
        ZStack {
            // 发光光晕
            Circle()
                .fill(
                    AngularGradient(
                        colors: [.accentColor.opacity(0.3), .purple.opacity(0.2), .blue.opacity(0.3), .accentColor.opacity(0.3)],
                        center: .center
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: 20)
                .scaleEffect(pulseScale)
                .opacity(isRotating ? 0.6 : 0.15)

            // 唱片背景
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 240, height: 240)

            // 唱片纹理 + 音符（旋转层）
            ZStack {
                ForEach(0..<6) { i in
                    Circle()
                        .stroke(Color.accentColor.opacity(0.08), lineWidth: 1)
                        .frame(width: CGFloat(220 - i * 35))
                }

                Circle()
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: 40, height: 40)

                Image(systemName: "music.note")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .foregroundColor(.accentColor.opacity(0.6))
            }
            .rotationEffect(.degrees(rotation))
        }
        .frame(width: 260, height: 260)
        .onAppear {
            if isRotating { startRotation() }
        }
        .onChange(of: isRotating) { _, playing in
            playing ? startRotation() : stopRotation()
        }
    }

    private func startRotation() {
        rotation = 0
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
            rotation = 360
        }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pulseScale = 1.06
        }
    }

    private func stopRotation() {
        // 停止 repeatForever 动画，平滑回到 0
        withAnimation(.easeOut(duration: 0.4)) {
            rotation = 0
            pulseScale = 1.0
        }
    }
}
