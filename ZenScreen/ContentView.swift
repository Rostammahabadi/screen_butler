//
//  ContentView.swift
//  ZenScreen
//
//  Created by Rostam on 2/28/25.
//

import SwiftUI
#if os(macOS)
import Quartz
import QuickLookUI
#else
import QuickLook
import PDFKit
#endif

struct ContentView: View {
    @State private var selectedItem: FileItem?
    @State private var selectedItems: Set<FileItem> = []
    @State private var fileContent: String = ""
    @State private var refreshTrigger = false
    @State private var isMultiSelectMode = false
    @State private var isShowingBatchRenameView = false
    @State private var renameSuggestions: [FileItem: String] = [:]
    
    var body: some View {
        HStack(spacing: 0) {
            // Left side - File Browser
            VStack(spacing: 0) {
                // Title header
                HStack {
                    Text("ZenScreen Desktop Browser")
                        .font(.headline)
                        .padding()
                    
                    Spacer()
                    
                    // Multi-select toggle button
                    Button(action: {
                        isMultiSelectMode.toggle()
                        if !isMultiSelectMode {
                            // Clear selection when exiting multi-select mode
                            selectedItems = []
                        }
                    }) {
                        HStack {
                            Image(systemName: isMultiSelectMode ? "xmark.circle" : "checklist")
                            Text(isMultiSelectMode ? "Exit Selection" : "Select Files")
                                .font(.subheadline)
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                    
                    // Batch rename button (only visible in multi-select mode with items selected)
                    if isMultiSelectMode && !selectedItems.isEmpty {
                        Button(action: startBatchRename) {
                            Label("Rename with AI", systemImage: "wand.and.stars")
                                .font(.subheadline)
                        }
                        .padding(.trailing)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                
                // Multi-select info banner
                if isMultiSelectMode {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Only images, videos, PDFs, text and spreadsheet files can be selected for renaming. Folders remain navigable.")
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        
                        if !selectedItems.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("\(selectedItems.count) \(selectedItems.count == 1 ? "file" : "files") selected")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 6)
                }
                
                // File browser
                FileBrowserWithSelectionView(
                    selectedItem: $selectedItem,
                    selectedItems: $selectedItems,
                    fileContent: $fileContent,
                    isMultiSelectMode: $isMultiSelectMode
                )
            }
            .frame(minWidth: 300)
            
            // Right side - Preview Pane (only in single-select mode)
            if !isMultiSelectMode && selectedItem != nil {
                Divider()
                
                FilePreviewView(item: selectedItem!, content: fileContent, onFileRenamed: {
                    // Clear selected item and trigger refresh
                    selectedItem = nil
                    refreshTrigger.toggle()
                })
                .frame(minWidth: 400)
                .transition(.move(edge: .trailing))
            }
        }
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 600)
        #else
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
        .sheet(isPresented: $isShowingBatchRenameView) {
            BatchRenameView(
                selectedItems: Array(selectedItems),
                renameSuggestions: $renameSuggestions,
                onComplete: {
                    // Dismiss the sheet
                    isShowingBatchRenameView = false
                    
                    // Clear selections and refresh
                    selectedItems = []
                    isMultiSelectMode = false
                    refreshTrigger.toggle()
                }
            )
        }
    }
    
    func startBatchRename() {
        // Only allow batch renaming if there are items selected
        guard !selectedItems.isEmpty else { return }
        
        // Show the batch rename view
        isShowingBatchRenameView = true
    }
}

// Modified file browser view that passes selection to parent
struct FileBrowserWithSelectionView: View {
    @Binding var selectedItem: FileItem?
    @Binding var selectedItems: Set<FileItem>
    @Binding var fileContent: String
    @Binding var isMultiSelectMode: Bool
    @StateObject private var fileService = FileSystemService()
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation header
            HStack {
                Button(action: fileService.navigateUp) {
                    Image(systemName: "arrow.up")
                        .padding(8)
                }
                .disabled(fileService.currentDirectory.pathComponents.count <= 1)
                
                Text(fileService.currentDirectory.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                    .padding(.horizontal)
                
                Spacer()
                
                Button(action: fileService.loadContents) {
                    Image(systemName: "arrow.clockwise")
                        .padding(8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            
            // Error message if present
            if let error = fileService.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                    Spacer()
                }
                .padding()
                .background(Color.red.opacity(0.1))
            }
            
            // Directory contents
            List(fileService.items) { item in
                HStack {
                    // Selection indicator (checkbox) for multi-select mode - only show for supported files
                    if isMultiSelectMode && !item.isDirectory && isSupportedFileType(url: item.path) {
                        Image(systemName: selectedItems.contains(item) ? "checkmark.square.fill" : "square")
                            .foregroundColor(.blue)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleItemSelection(item)
                            }
                    } else if isMultiSelectMode && (item.isDirectory || !isSupportedFileType(url: item.path)) {
                        // Show a folder icon or "unsupported" icon
                        Image(systemName: item.isDirectory ? "folder" : "xmark.square")
                            .foregroundColor(.secondary.opacity(0.5))
                            .font(.caption)
                    }
                    
                    Image(systemName: item.icon)
                        .foregroundColor(item.isDirectory ? .blue : .gray)
                    
                    VStack(alignment: .leading) {
                        Text(item.name)
                            .lineLimit(1)
                            // In multi-select mode, show directories and unsupported files with reduced opacity
                            .foregroundColor(isMultiSelectMode && (item.isDirectory || !isSupportedFileType(url: item.path)) ? 
                                             .primary.opacity(0.6) : .primary)
                        
                        HStack {
                            Text(item.formattedSize)
                            Text("•")
                            Text(item.formattedDate)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .padding(.vertical, 2)
                .background(
                    (selectedItem?.id == item.id) ? Color.blue.opacity(0.1) : 
                    (selectedItems.contains(item) ? Color.blue.opacity(0.2) : Color.clear)
                )
                // Apply opacity to directories and unsupported files in multi-select mode
                .opacity(isMultiSelectMode && (item.isDirectory || !isSupportedFileType(url: item.path)) ? 0.7 : 1.0)
                .onTapGesture {
                    if isMultiSelectMode {
                        // In multi-select mode, only allow selection of supported files
                        if !item.isDirectory && isSupportedFileType(url: item.path) {
                            toggleItemSelection(item)
                        } else {
                            // For directories, navigate as usual but with haptic feedback
                            if item.isDirectory {
                                #if os(iOS)
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                #endif
                                fileService.navigate(to: item.path)
                            } else {
                                // For unsupported files, provide feedback that they can't be selected
                                #if os(iOS)
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.error)
                                #endif
                            }
                        }
                    } else {
                        // In single-select mode, normal behavior
                        if item.isDirectory {
                            fileService.navigate(to: item.path)
                            selectedItem = nil
                        } else {
                            selectedItem = item
                            loadFileContent(url: item.path)
                        }
                    }
                }
            }
            .listStyle(InsetListStyle())
        }
        .onAppear {
            fileService.restoreBookmarkedAccess()
        }
    }
    
    private func toggleItemSelection(_ item: FileItem) {
        if !item.isDirectory && isSupportedFileType(url: item.path) {
            if selectedItems.contains(item) {
                selectedItems.remove(item)
            } else {
                selectedItems.insert(item)
            }
        }
    }
    
    // Check if a file is of a supported type for AI analysis and renaming
    func isSupportedFileType(url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        
        // Supported file types
        let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "raw", "bmp"]
        let videoExtensions = ["mp4", "mov", "m4v", "avi", "wmv", "webm", "mkv", "3gp"]
        let documentExtensions = ["pdf", "txt", "rtf", "doc", "docx", "pages"]
        let spreadsheetExtensions = ["xls", "xlsx", "csv", "numbers"]
        
        // Check if the file extension is in any of the supported categories
        return imageExtensions.contains(fileExtension) ||
               videoExtensions.contains(fileExtension) ||
               documentExtensions.contains(fileExtension) ||
               spreadsheetExtensions.contains(fileExtension)
    }
    
    func loadFileContent(url: URL) {
        if isTextFile(url: url) {
            do {
                fileContent = try String(contentsOf: url, encoding: .utf8)
            } catch {
                fileContent = "Error loading file: \(error.localizedDescription)"
            }
        } else {
            fileContent = "Preview available"
        }
    }
    
    func refreshContents() {
        fileService.loadContents()
    }
    
    func isTextFile(url: URL) -> Bool {
        let textExtensions = ["txt", "md", "json", "xml", "html", "css", "js", "swift", "c", "cpp", "h", "m", "py", "rb", "java", "sh"]
        return textExtensions.contains(url.pathExtension.lowercased())
    }
}

// Preview pane for selected file
struct FilePreviewView: View {
    let item: FileItem
    let content: String
    let onFileRenamed: () -> Void
    @StateObject private var openAIService = OpenAIService()
    @State private var isShowingRenameAlert = false
    @State private var suggestedName = ""
    @State private var isRenamingFile = false
    @State private var renameError: String?
    @State private var showErrorAlert = false
    @State private var isShowingAPIKeyView = false
    @State private var isShowingVideoAlert = false
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Image(systemName: item.icon)
                    .font(.title)
                    .foregroundColor(item.isDirectory ? .blue : .gray)
                    .padding(.trailing, 4)
                
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                if openAIService.isAnalyzing {
                    ProgressView()
                        .padding(.trailing, 8)
                } else {
                    Button(action: analyzeAndRename) {
                        Label("Rename with AI", systemImage: "wand.and.stars")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(item.isDirectory)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            
            // File information
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Size:")
                            .fontWeight(.medium)
                        Text(item.formattedSize)
                    }
                    
                    HStack {
                        Text("Modified:")
                            .fontWeight(.medium)
                        Text(item.formattedDate)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .font(.subheadline)
            
            Divider()
            
            // Preview content
            if isTextFile(url: item.path) {
                ScrollView {
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                #if os(macOS)
                QuickLookPreview(url: item.path)
                #else
                if isPDFFile(url: item.path) {
                    PDFKitView(url: item.path)
                } else if isImageFile(url: item.path) {
                    ImagePreview(url: item.path)
                } else {
                    fallbackPreview
                }
                #endif
            }
        }
        .alert("Rename with AI", isPresented: $isShowingRenameAlert) {
            TextField("Suggested name", text: $suggestedName)
            
            Button("Cancel", role: .cancel) { }
            
            Button("Rename", action: performRename)
        } message: {
            if isVideoFile(url: item.path) {
                Text("AI has analyzed frames from your video using computer vision and suggested this name based on the visual content. You can edit it before confirming.")
            } else {
                Text("AI has analyzed your image using computer vision and suggested this name. You can edit it before confirming.")
            }
        }
        .alert("Error Renaming File", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(renameError ?? "Unknown error")
        }
        .alert("Analyze Video", isPresented: $isShowingVideoAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Continue") {
                performVideoAnalysis()
            }
        } message: {
            Text("The AI will extract frames from the beginning, middle, and end of this video, then use advanced vision AI to analyze the visual content and suggest a descriptive name. Continue?")
        }
        .sheet(isPresented: $isShowingAPIKeyView) {
            APIKeyView(openAIService: openAIService, isPresented: $isShowingAPIKeyView)
                .onDisappear {
                    // If API key is available after sheet is dismissed, continue with analysis
                    if openAIService.hasAPIKey {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            analyzeAndRename()
                        }
                    }
                }
        }
    }
    
    func analyzeAndRename() {
        // Check if API key is available
        if !openAIService.hasAPIKey {
            // Show API key input view
            isShowingAPIKeyView = true
            return
        }
        
        // Show specific alert for video files
        if isVideoFile(url: item.path) {
            isShowingVideoAlert = true
        } else {
            // For other file types, proceed as normal
            openAIService.analyzeImage(url: item.path) { result in
                switch result {
                case .success(let name):
                    self.suggestedName = name
                    self.isShowingRenameAlert = true
                case .failure(let error):
                    self.renameError = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        }
    }
    
    func performVideoAnalysis() {
        openAIService.analyzeImage(url: item.path) { result in
            switch result {
            case .success(let name):
                DispatchQueue.main.async {
                    self.suggestedName = name
                    self.isShowingRenameAlert = true
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.renameError = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        }
    }
    
    func performRename() {
        isRenamingFile = true
        
        // Create a friendly filename if suggestedName is empty
        if suggestedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            suggestedName = "Renamed_File_\(Int.random(in: 100...999))"
        }
        
        // Disable special characters that might cause issues
        let sanitizedName = suggestedName
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        
        FileRenameService.rename(fileAt: item.path, to: sanitizedName) { result in
            isRenamingFile = false
            
            switch result {
            case .success(let newURL):
                // Trigger refresh of the file list
                onFileRenamed()
                print("File renamed successfully to: \(newURL.lastPathComponent)")
                
            case .failure(let error):
                self.renameError = error.localizedDescription
                self.showErrorAlert = true
                
                #if os(macOS)
                // On macOS, if access is denied, we might need to offer the user some guidance
                if case .accessDenied = error {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // If this is a permissions issue, explain more clearly to the user
                        let alert = NSAlert()
                        alert.messageText = "Permission Error"
                        alert.informativeText = "ZenScreen doesn't have permission to rename this file. This can happen with files in protected locations or files you don't own. Consider moving the file to a location you have full access to, like your Documents folder."
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
                #endif
            }
        }
    }
    
    var fallbackPreview: some View {
        VStack {
            Spacer()
            
            Image(systemName: fileTypeIcon(for: item.path))
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundColor(.gray)
            
            Text("Preview not available")
                .font(.headline)
                .padding(.top)
            
            Text("This file type cannot be previewed")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    func isTextFile(url: URL) -> Bool {
        let textExtensions = ["txt", "md", "json", "xml", "html", "css", "js", "swift", "c", "cpp", "h", "m", "py", "rb", "java", "sh"]
        return textExtensions.contains(url.pathExtension.lowercased())
    }
    
    func isPDFFile(url: URL) -> Bool {
        return url.pathExtension.lowercased() == "pdf"
    }
    
    func isImageFile(url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "svg", "bmp", "tiff"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    func isVideoFile(url: URL) -> Bool {
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v"]
        return videoExtensions.contains(url.pathExtension.lowercased())
    }
    
    func fileTypeIcon(for url: URL) -> String {
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "pdf":
            return "doc.text.viewfinder"
        case "jpg", "jpeg", "png", "gif", "heic", "svg":
            return "photo"
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v":
            return "film"
        case "mp3", "wav", "m4a":
            return "music.note"
        case "doc", "docx":
            return "doc.text"
        case "xls", "xlsx":
            return "chart.bar.doc.horizontal"
        case "ppt", "pptx":
            return "chart.bar.doc.horizontal"
        case "zip", "rar", "7z":
            return "doc.zipper"
        default:
            return "doc"
        }
    }
}

// QuickLook preview for macOS
#if os(macOS)
struct QuickLookPreview: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> NSView {
        let preview = QLPreviewView(frame: .zero, style: .normal)
        preview?.autostarts = true
        return preview ?? NSView()
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let previewView = nsView as? QLPreviewView {
            previewView.previewItem = url as QLPreviewItem
        }
    }
}
#endif

// For iOS - PDF View
#if os(iOS)
struct PDFKitView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        if let document = PDFDocument(url: url) {
            uiView.document = document
        }
    }
}

// For iOS - Image preview
struct ImagePreview: View {
    let url: URL
    
    var body: some View {
        if let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding()
        } else {
            Text("Unable to load image")
                .foregroundColor(.red)
        }
    }
}
#endif

// Add the fileTypeIcon method to make it available to other views
extension View {
    func fileTypeIcon(for url: URL) -> String {
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "pdf":
            return "doc.text.viewfinder"
        case "jpg", "jpeg", "png", "gif", "heic", "svg":
            return "photo"
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v":
            return "film"
        case "mp3", "wav", "m4a":
            return "music.note"
        case "doc", "docx":
            return "doc.text"
        case "xls", "xlsx":
            return "chart.bar.doc.horizontal"
        case "ppt", "pptx":
            return "chart.bar.doc.horizontal"
        case "zip", "rar", "7z":
            return "doc.zipper"
        default:
            return "doc"
        }
    }
}

#Preview {
    ContentView()
}
