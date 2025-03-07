//
//  ThemeManager.swift
//  personnalMusic
//
//  主题管理器：管理应用的颜色主题

import SwiftUI

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: AppTheme = .light {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
        }
    }
    
    init() {
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            currentTheme = theme
        }
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case light  // 白色主题
    case blue   // 蓝色主题
    
    var id: String { rawValue }
    
    var primaryGradient: LinearGradient {
        switch self {
        case .light:
            return LinearGradient(
                colors: [
                    Color.white,
                    Color(.systemGray6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .blue:
            return LinearGradient(
                colors: [
                    Color(.systemBlue).opacity(0.8),
                    Color(.systemBlue).opacity(0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // 主要交互按钮颜色（用于重要按钮）
    var accentColor: Color {
        switch self {
        case .light:
            return Color(.systemGray)  // 使用更深的灰色
        case .blue:
            return Color(.systemBlue)
        }
    }
    
    // 预览颜色
    var previewColor: Color {
        switch self {
        case .light:
            return Color(.darkGray)  // 使用深灰色
        case .blue:
            return Color(.systemBlue).opacity(0.8)
        }
    }
    
    // 次要按钮颜色
    var secondaryColor: Color {
        switch self {
        case .light:
            return Color(.systemGray2)  // 次要按钮也使用较深的灰色
        case .blue:
            return Color(.systemBlue).opacity(0.3)
        }
    }
    
    // 播放控制按钮颜色
    var playButtonColor: Color {
        switch self {
        case .light:
            return Color.black  // 使用黑色作为播放按钮颜色
        case .blue:
            return Color(.systemBlue).opacity(0.9)  // 加深蓝色
        }
    }
    
    // 图标按钮颜色
    var iconColor: Color {
        switch self {
        case .light:
            return Color.black  // 图标也使用黑色
        case .blue:
            return Color(.systemBlue).opacity(0.9)
        }
    }
} 
