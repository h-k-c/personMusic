//
//  ThemePickerView.swift
//  personnalMusic
//
//  主题选择视图：用于选择应用主题

import SwiftUI

struct ThemePickerView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("选择主题")
                .font(.headline)
                .padding(.top)
            
            ScrollView {
                VStack(spacing: 15) {
                    ForEach(AppTheme.allCases) { theme in
                        ThemeOptionView(theme: theme, isSelected: themeManager.currentTheme == theme)
                            .onTapGesture {
                                themeManager.setTheme(theme)
                            }
                    }
                }
                .padding()
            }
            
            Button("完成") {
                isPresented = false
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(themeManager.currentTheme.accentColor)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 300, height: 400)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 20)
    }
}

struct ThemeOptionView: View {
    let theme: AppTheme
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Circle()
                .fill(theme.primaryGradient)
                .frame(width: 40, height: 40)
            
            Text(theme.rawValue)
                .font(.body)
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(theme.accentColor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? theme.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
    }
} 