//
//  SyncManager.swift
//  personnalMusic
//
//  同步管理器：管理与远程服务器的同步

import Foundation
import SwiftUI

class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncMessage: String?
    @Published var showSyncMessage = false
    
    private init() {
        // 从 UserDefaults 加载上次同步时间
        if let timeInterval = UserDefaults.standard.object(forKey: "lastSyncTime") as? TimeInterval {
            lastSyncTime = Date(timeIntervalSince1970: timeInterval)
        }
    }
    
    /// 执行同步操作
    func sync() {
        guard !isSyncing else {
            showMessage("正在同步中，请稍候...")
            return
        }
        
        isSyncing = true
        showMessage("正在与远程服务器同步...")
        
        // 模拟同步操作
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            
            // 更新同步状态
            self.lastSyncTime = Date()
            UserDefaults.standard.set(self.lastSyncTime?.timeIntervalSince1970, forKey: "lastSyncTime")
            
            self.showMessage("同步完成")
            self.isSyncing = false
            
            // 2秒后隐藏消息
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.showSyncMessage = false
            }
        }
    }
    
    /// 显示同步消息
    private func showMessage(_ message: String) {
        syncMessage = message
        showSyncMessage = true
    }
    
    /// 格式化上次同步时间
    func formattedLastSyncTime() -> String {
        guard let lastSyncTime = lastSyncTime else {
            return "从未同步"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "上次同步: \(formatter.string(from: lastSyncTime))"
    }
} 