//
//  personnalMusicApp.swift
//  personnalMusic
//
//  Created by 胡开成 on 2025/3/6.
//

import SwiftUI
import Foundation
import UIKit
import AVFoundation

@main
struct personnalMusicApp: App {
    init() {
        // 设置音频会话类别（激活推迟到 ContentView.onAppear）
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
        } catch {
            print("AudioSession 设置失败: \(error)")
        }
        UIApplication.shared.beginReceivingRemoteControlEvents()

        // 设置默认语言偏好
        let languages = ["zh-Hans-CN", "en-CN"]
        CFPreferencesSetAppValue("AppleLanguages" as CFString,
                               languages as CFArray,
                               kCFPreferencesCurrentApplication)
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)

        UserDefaults.standard.set(languages, forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
