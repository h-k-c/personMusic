//
//  MusicSource.swift
//  personnalMusic
//
//  音乐源模型：定义了本地音乐文件夹的数据结构

import Foundation

/// 表示一个本地音乐源
struct MusicSource: Identifiable {
    /// 唯一标识符
    let id = UUID()
    /// 文件夹名称
    let name: String
    /// 文件夹URL
    let url: URL
    /// 音乐文件数量
    var songCount: Int
} 