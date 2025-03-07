//
//  personnalMusicApp.swift
//  personnalMusic
//
//  Created by 胡开成 on 2025/3/6.
//

import SwiftUI
import Foundation
import UIKit

@main
struct personnalMusicApp: App {
    init() {
        // 设置默认语言偏好
        let languages = ["zh-Hans-CN", "en-CN"]
        CFPreferencesSetAppValue("AppleLanguages" as CFString,
                               languages as CFArray,
                               kCFPreferencesCurrentApplication)
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
        
        // 同时设置 UserDefaults
        UserDefaults.standard.set(languages, forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
