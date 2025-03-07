//
//  SyncStatusView.swift
//  personnalMusic
//
//  同步状态视图：显示同步状态和信息

import SwiftUI

struct SyncStatusView: View {
    @ObservedObject private var syncManager = SyncManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("同步状态")
                .font(.headline)
                .padding(.top)
            
            if syncManager.isSyncing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: themeManager.currentTheme.accentColor))
                    .scaleEffect(1.5)
                    .padding()
                
                Text("正在同步...")
                    .foregroundColor(.gray)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(themeManager.currentTheme.accentColor)
                    .padding()
                
                Text(syncManager.formattedLastSyncTime())
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            HStack(spacing: 20) {
                Button("取消") {
                    isPresented = false
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(10)
                
                Button("同步") {
                    syncManager.sync()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(themeManager.currentTheme.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(syncManager.isSyncing)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 300, height: 300)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 20)
        .overlay(
            Group {
                if syncManager.showSyncMessage {
                    VStack {
                        Text(syncManager.syncMessage ?? "")
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.4))
                }
            }
        )
    }
} 