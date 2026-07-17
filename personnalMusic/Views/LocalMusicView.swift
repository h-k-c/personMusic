//
//  LocalMusicView.swift
//  personnalMusic
//
//  本地音乐视图：显示本地音乐源列表和文件选择器

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct LocalMusicView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @StateObject private var viewModel = LocalMusicViewModel()
    @State private var showingFilePicker = false
    @State private var showingFolderPicker = false
    @State private var showingActionSheet = false
    @State private var showClearConfirmation = false
    @State private var fileToDelete: MusicFile?
    @State private var fileForInfo: MusicFile?
    @Binding var selectedTab: Int
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.musicFolders.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("还没有添加本地音乐")
                            .foregroundColor(.gray)
                        Button(action: { showingActionSheet = true }) {
                            Text("添加音乐")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.musicFolders) { folder in
                        Section {
                            ForEach(folder.files) { file in
                                LocalMusicItemView(
                                    musicFile: file,
                                    action: {
                                        viewModel.playMusic(file, playerViewModel: playerViewModel, selectedTab: $selectedTab)
                                    },
                                    onInfo: {
                                        fileForInfo = file
                                    }
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        fileToDelete = file
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            HStack(spacing: 8) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.accentColor)
                                Text(folder.path)
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Text("\(folder.files.count) 首")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("本地音乐")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingActionSheet = true
                    }) {
                        Image(systemName: "plus")
                            .imageScale(.large)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showClearConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .imageScale(.large)
                    }
                }
            }
            .confirmationDialog("添加音乐", isPresented: $showingActionSheet) {
                Button("添加文件夹") {
                    showingFolderPicker = true
                }
                Button("添加文件") {
                    showingFilePicker = true
                }
                Button("取消", role: .cancel) {}
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker(
                    allowedContentTypes: [.audio],
                    allowsMultipleSelection: true
                ) { urls in
                    viewModel.addMusicFiles(urls)
                }
            }
            .sheet(isPresented: $showingFolderPicker) {
                DocumentPicker(
                    allowedContentTypes: [.folder],
                    allowsMultipleSelection: false
                ) { urls in
                    if let folderURL = urls.first {
                        viewModel.addMusicFolder(folderURL)
                    }
                }
            }
            .alert(isPresented: $showClearConfirmation) {
                Alert(
                    title: Text("确认清空"),
                    message: Text("确定要清空所有音乐吗？此操作无法撤销。"),
                    primaryButton: .destructive(Text("清空")) {
                        viewModel.clearAllMusic(playerViewModel: playerViewModel)
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
            // 删除单个文件确认
            .alert("确认删除", isPresented: Binding(
                get: { fileToDelete != nil },
                set: { if !$0 { fileToDelete = nil } }
            )) {
                Button("取消", role: .cancel) { fileToDelete = nil }
                Button("删除", role: .destructive) {
                    if let file = fileToDelete {
                        viewModel.deleteFile(file, playerViewModel: playerViewModel)
                        fileToDelete = nil
                    }
                }
            } message: {
                if let file = fileToDelete {
                    Text("确定要删除「\(file.title)」吗？此操作无法撤销。")
                } else {
                    Text("确定要删除这个文件吗？")
                }
            }
            // 文件详情弹窗
            .sheet(item: $fileForInfo) { file in
                FileInfoSheet(file: file)
            }
            .onAppear {
                viewModel.refreshMusicList()
            }
        }
    }
}

// 自定义文档选择器
struct DocumentPicker: UIViewControllerRepresentable {
    let allowedContentTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onPick: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes)
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls)
        }
    }
}

#Preview {
    NavigationView {
        LocalMusicView(
            playerViewModel: PlayerViewModel(),
            selectedTab: .constant(0)
        )
    }
}

