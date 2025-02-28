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

// File Utilities for handling file type checking
struct FileUtils {
    // Check if a file is of a supported type for AI analysis and renaming
    static func isSupportedFileType(url: URL) -> Bool {
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
    
    // Check if a file is a text file
    static func isTextFile(url: URL) -> Bool {
        let textExtensions = ["txt", "md", "json", "xml", "html", "css", "js", "swift", "c", "cpp", "h", "m", "py", "rb", "java", "sh"]
        return textExtensions.contains(url.pathExtension.lowercased())
    }
    
    // Check if a file is an image file
    static func isImageFile(url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "svg", "bmp", "tiff"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    // Check if a file is a video file
    static func isVideoFile(url: URL) -> Bool {
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v"]
        return videoExtensions.contains(url.pathExtension.lowercased())
    }
    
    // Check if a file is a PDF
    static func isPDFFile(url: URL) -> Bool {
        return url.pathExtension.lowercased() == "pdf"
    }
    
    // Get appropriate icon for a file
    static func fileTypeIcon(for url: URL) -> String {
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

struct ContentView: View {
    @State private var selectedItem: FileItem?
    @State private var selectedItems: Set<FileItem> = []
    @State private var fileContent: String = ""
    @State private var refreshTrigger = false
    @State private var isMultiSelectMode = false
    @State private var isShowingBatchRenameView = false
    @State private var renameSuggestions: [FileItem: String] = [:]
    @State private var isSmartSelecting = false
    @StateObject private var fileService = FileSystemService()  // Create a shared FileSystemService
    
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
                    
                    // Smart Select button - automatically identify ambiguous filenames
                    if !isMultiSelectMode {
                        Button(action: smartSelectAmbiguousFiles) {
                            HStack {
                                if isSmartSelecting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "wand.and.stars")
                                }
                                Text(isSmartSelecting ? "Scanning..." : "Smart Select")
                                    .font(.subheadline)
                            }
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.blue)
                        .padding(.trailing, 8)
                        .disabled(isSmartSelecting)
                    }
                    
                    // Multi-select toggle button
                    Button(action: {
                        isMultiSelectMode.toggle()
                        if !isMultiSelectMode {
                            selectedItems.removeAll()
                        }
                    }) {
                        HStack {
                            Image(systemName: isMultiSelectMode ? "xmark.circle" : "checkmark.circle")
                            Text(isMultiSelectMode ? "Exit Selection" : "Select Files")
                                .font(.subheadline)
                        }
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(isMultiSelectMode ? .red : .blue)
                    
                    // Batch rename button (only visible when items are selected)
                    if !selectedItems.isEmpty {
                        Button(action: startBatchRename) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Rename \(selectedItems.count) Files")
                                    .font(.subheadline)
                            }
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.green)
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
                
                // File browser - pass the shared fileService
                FileBrowserWithSelectionView(
                    selectedItem: $selectedItem,
                    selectedItems: $selectedItems,
                    fileContent: $fileContent,
                    isMultiSelectMode: $isMultiSelectMode,
                    fileService: fileService
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
    
    func smartSelectAmbiguousFiles() {
        // Set the loading state
        isSmartSelecting = true
        
        // Use a brief delay to allow UI to update with the loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.performSmartSelection()
        }
    }
    
    private func performSmartSelection() {
        // First, enter multi-select mode
        isMultiSelectMode = true
        selectedItems = []
        
        // Log the current directory for debugging
        print("Current directory in FileSystemService: \(fileService.currentDirectory.path)")
        
        // Get ambiguous items
        let ambiguousItems = findAmbiguousItems()
        
        // Log the files that were checked and the results
        print("Found \(ambiguousItems.count) ambiguous items out of \(fileService.items.count) total items")
        
        // Log some of the filenames for debugging
        if !fileService.items.isEmpty {
            print("Some filenames in the current directory:")
            for (index, item) in fileService.items.prefix(10).enumerated() {
                print("\(index + 1). \(item.name) - Ambiguous: \(isAmbiguousFilename(item.name))")
            }
        }
        
        // Reset loading state
        isSmartSelecting = false
        
        // Select all ambiguous files
        selectedItems = Set(ambiguousItems)
        
        // Notify the user of the results
        notifyUserOfSmartSelectionResults(itemCount: ambiguousItems.count)
    }
    
    private func findAmbiguousItems() -> [FileItem] {
        // Use the shared fileService instead of creating a new one
        let fileItems = fileService.items
        
        print("DEBUG: Current directory: \(fileService.currentDirectory.path)")
        print("DEBUG: Number of items: \(fileItems.count)")
        
        let ambiguousFiles = fileItems.filter { item in
            // Only consider files, not directories
            if item.isDirectory {
                return false
            }
            
            // Only consider supported file types
            guard FileUtils.isSupportedFileType(url: item.path) else {
                return false
            }
            
            let filename = item.name
            print("DEBUG: Checking file: \(filename)")
            
            // Special case for Recording files from the screenshot
            if filename.lowercased().contains("recording at") {
                print("DEBUG: Found recording file!")
                return true
            }
            
            // Now check if the filename appears ambiguous/non-specific
            let isAmbiguous = isAmbiguousFilename(filename)
            print("DEBUG: \(filename) is ambiguous: \(isAmbiguous)")
            return isAmbiguous
        }
        
        print("DEBUG: Found \(ambiguousFiles.count) ambiguous files")
        return ambiguousFiles
    }
    
    private func notifyUserOfSmartSelectionResults(itemCount: Int) {
        if itemCount > 0 {
            showAmbiguousFilesFoundAlert(count: itemCount)
        } else {
            showNoAmbiguousFilesFoundAlert()
        }
    }
    
    private func showAmbiguousFilesFoundAlert(count: Int) {
        #if os(macOS)
        // Show a quick alert to inform the user
        let alert = NSAlert()
        alert.messageText = "Smart Selection"
        alert.informativeText = "Found \(count) files with ambiguous names. You can now review and rename them using AI."
        alert.addButton(withTitle: "OK")
        alert.runModal()
        
        // Automatically show the batch rename view
        startBatchRename()
        #else
        // On iOS, we use alerts or a toast
        withAnimation {
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // Automatically show the batch rename view
            startBatchRename()
        }
        #endif
    }
    
    private func showNoAmbiguousFilesFoundAlert() {
        #if os(macOS)
        // No ambiguous files found
        let alert = NSAlert()
        alert.messageText = "Smart Selection"
        alert.informativeText = "No files with ambiguous names were found in the current directory."
        alert.addButton(withTitle: "OK")
        alert.runModal()
        
        // Exit multi-select mode since we didn't find anything
        isMultiSelectMode = false
        #else
        // On iOS
        withAnimation {
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            
            // Exit multi-select mode since we didn't find anything
            isMultiSelectMode = false
        }
        #endif
    }
    
    // Helper method to determine if a filename appears ambiguous or non-specific
    func isAmbiguousFilename(_ filename: String) -> Bool {
        // Ignore hidden files
        if filename.hasPrefix(".") {
            return false
        }
        
        let lowercased = filename.lowercased()
        let nameWithoutExtension = (filename as NSString).deletingPathExtension.lowercased()
        
        // Explicit detection for recording files like in the screenshot
        if lowercased.contains("recording at") || 
           (lowercased.hasPrefix("recording") && lowercased.contains("20")) {
            print("DEBUG: \(filename) matches recording pattern")
            return true
        }
        
        // Check for date patterns in the filename
        let datePatterns = [
            // YYYY-MM-DD format
            "\\d{4}-\\d{2}-\\d{2}",
            // MM-DD-YY format
            "\\d{1,2}-\\d{1,2}-\\d{2,4}",
            // Timestamps like 20.17.40
            "\\d{2}\\.\\d{2}\\.\\d{2}"
        ]
        
        for pattern in datePatterns {
            if lowercased.range(of: pattern, options: .regularExpression) != nil {
                print("DEBUG: \(filename) matches date pattern: \(pattern)")
                return true
            }
        }
        
        // Consider very short names (less than 3 characters) as ambiguous
        if nameWithoutExtension.count < 3 {
            return true
        }
        
        // Check for common patterns in non-specific names
        
        // Pattern 1: Generic prefixes like "image_", "screenshot_", "photo_", "recording_", etc.
        let genericPrefixes = ["image", "img", "screenshot", "screen", "photo", "pic", "picture", 
                              "recording", "record", "video", "movie", "file", "document", "doc", 
                              "untitled", "unnamed", "new", "scan", "capture", "attachment",
                              "download", "export", "import", "output", "print", "temp", "tmp"]
        
        for prefix in genericPrefixes {
            // Check if the name starts with this prefix (case insensitive)
            if nameWithoutExtension.lowercased().hasPrefix(prefix.lowercased()) {
                return true
            }
            if nameWithoutExtension.lowercased().contains("_\(prefix.lowercased())_") || 
               nameWithoutExtension.lowercased().contains("-\(prefix.lowercased())-") {
                return true
            }
            if nameWithoutExtension.lowercased().hasSuffix("_\(prefix.lowercased())") || 
               nameWithoutExtension.lowercased().hasSuffix("-\(prefix.lowercased())") {
                return true
            }
        }
        
        // Pattern 2: Names that are primarily numbers or contain timestamps
        // Look for date patterns like 2023-01-15 or 20230115
        if nameWithoutExtension.range(of: "\\d{2,4}[-_]?\\d{1,2}[-_]?\\d{1,2}", options: .regularExpression) != nil {
            return true
        }
        
        // Recording at DATE patterns (explicitly check for the format in the screenshot)
        if nameWithoutExtension.lowercased().range(of: "recording at \\d{4}-\\d{2}-\\d{2}", options: .regularExpression) != nil {
            return true
        }
        
        // Pattern 3: Names with timestamp patterns HH:MM:SS or HH.MM.SS
        if nameWithoutExtension.range(of: "\\d{1,2}[:\\.]\\d{1,2}([:\\.]\\d{1,2})?", options: .regularExpression) != nil {
            return true
        }
        
        // Check for timestamps at the end of recording filenames (like those in the screenshot)
        if nameWithoutExtension.range(of: "\\d{2}\\.\\d{2}\\.\\d{2}$", options: .regularExpression) != nil {
            return true
        }
        
        // Pattern 4: Names that are just random characters/numbers like "DSC12345" or "IMG_1234"
        if nameWithoutExtension.range(of: "^[A-Za-z]{2,4}[_-]?\\d{3,6}$", options: .regularExpression) != nil {
            return true
        }
        
        // Pattern 5: Default camera naming patterns
        let cameraPrefixes = ["dsc", "img", "dcim", "mov", "vid", "clip", "100canon", "gopro", 
                              "iphoto", "photo", "still", "frame", "mvi_", "pict"]
        for prefix in cameraPrefixes {
            if nameWithoutExtension.lowercased().hasPrefix(prefix) {
                return true
            }
        }
        
        // Pattern 6: Names that are primarily numbers
        if nameWithoutExtension.range(of: "^\\d+$", options: .regularExpression) != nil {
            return true
        }
        
        // Pattern 7: Screenshot patterns from various operating systems
        let screenshotPatterns = ["screenshot", "screen shot", "screen_shot", "screensnap", 
                                 "screen snap", "screen-snap", "screen-capture", "screen_capture"]
        for pattern in screenshotPatterns {
            if nameWithoutExtension.lowercased().contains(pattern.lowercased()) {
                return true
            }
        }
        
        // Pattern 8: Names that include "copy" or duplicates
        let copyPatterns = ["copy", "copy of", "duplicate", " - copy", "_copy", "(copy)"]
        for pattern in copyPatterns {
            if nameWithoutExtension.lowercased().contains(pattern.lowercased()) {
                return true
            }
        }
        
        // Pattern 9: Names with UUIDs or hash-like strings
        if nameWithoutExtension.range(of: "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", options: .regularExpression) != nil {
            return true
        }
        
        // Pattern 10: Names with version numbers or revision markers
        let versionPatterns = ["v1", "v2", "v3", "ver", "version", "rev", "revision", 
                              " - v", "_v", "-v", "(v", "_rev", "-rev"]
        for pattern in versionPatterns {
            if nameWithoutExtension.lowercased().contains(pattern.lowercased()) {
                // Make sure it's not just part of a legitimate word
                if let range = nameWithoutExtension.range(of: pattern, options: .caseInsensitive) {
                    let index = nameWithoutExtension.distance(from: nameWithoutExtension.startIndex, to: range.lowerBound)
                    if index > 0 || pattern.hasPrefix(" ") || pattern.hasPrefix("_") || pattern.hasPrefix("-") || pattern.hasPrefix("(") {
                        return true
                    }
                }
            }
        }
        
        return false
    }
}

// Update FileBrowserWithSelectionView to accept a fileService
struct FileBrowserWithSelectionView: View {
    @Binding var selectedItem: FileItem?
    @Binding var selectedItems: Set<FileItem>
    @Binding var fileContent: String
    @Binding var isMultiSelectMode: Bool
    @ObservedObject var fileService: FileSystemService  // Change from @StateObject to @ObservedObject
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation header
            NavigationHeaderView(fileService: fileService)
            
            // Error message if present
            if let error = fileService.error {
                ErrorBannerView(errorMessage: error)
            }
            
            // Directory contents
            DirectoryContentsList(
                items: fileService.items,
                selectedItem: $selectedItem,
                selectedItems: $selectedItems,
                fileContent: $fileContent,
                isMultiSelectMode: $isMultiSelectMode,
                fileService: fileService
            )
        }
        .onAppear {
            fileService.restoreBookmarkedAccess()
        }
    }
    
    func refreshContents() {
        fileService.loadContents()
    }
}

// Navigation header as a separate component
struct NavigationHeaderView: View {
    @ObservedObject var fileService: FileSystemService
    
    var body: some View {
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
    }
}

// Error banner as a separate component
struct ErrorBannerView: View {
    let errorMessage: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
            Text(errorMessage)
                .foregroundColor(.red)
                .font(.caption)
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
    }
}

// Directory contents list as a separate component
struct DirectoryContentsList: View {
    let items: [FileItem]
    @Binding var selectedItem: FileItem?
    @Binding var selectedItems: Set<FileItem>
    @Binding var fileContent: String
    @Binding var isMultiSelectMode: Bool
    @ObservedObject var fileService: FileSystemService
    
    var body: some View {
        List(items) { item in
            FileItemRow(
                item: item,
                selectedItem: $selectedItem,
                selectedItems: $selectedItems,
                fileContent: $fileContent,
                isMultiSelectMode: $isMultiSelectMode,
                fileService: fileService
            )
        }
        .listStyle(InsetListStyle())
    }
}

// Individual file item row as a separate component
struct FileItemRow: View {
    let item: FileItem
    @Binding var selectedItem: FileItem?
    @Binding var selectedItems: Set<FileItem>
    @Binding var fileContent: String
    @Binding var isMultiSelectMode: Bool
    @ObservedObject var fileService: FileSystemService
    
    var body: some View {
        HStack {
            // Selection indicator (checkbox) for multi-select mode - only show for supported files
            selectionIndicator
            
            Image(systemName: item.icon)
                .foregroundColor(item.isDirectory ? .blue : .gray)
            
            fileDetails
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .background(rowBackground)
        .opacity(rowOpacity)
        .onTapGesture {
            handleTap()
        }
    }
    
    @ViewBuilder
    private var selectionIndicator: some View {
        if isMultiSelectMode && !item.isDirectory && FileUtils.isSupportedFileType(url: item.path) {
            Image(systemName: selectedItems.contains(item) ? "checkmark.square.fill" : "square")
                .foregroundColor(.blue)
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleItemSelection()
                }
        } else if isMultiSelectMode && (item.isDirectory || !FileUtils.isSupportedFileType(url: item.path)) {
            // Show a folder icon or "unsupported" icon
            Image(systemName: item.isDirectory ? "folder" : "xmark.square")
                .foregroundColor(.secondary.opacity(0.5))
                .font(.caption)
        }
    }
    
    private var fileDetails: some View {
        VStack(alignment: .leading) {
            Text(item.name)
                .lineLimit(1)
                // In multi-select mode, show directories and unsupported files with reduced opacity
                .foregroundColor(isMultiSelectMode && (item.isDirectory || !FileUtils.isSupportedFileType(url: item.path)) ? 
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
    
    private var rowBackground: Color {
        if selectedItem?.id == item.id {
            return Color.blue.opacity(0.1)
        } else if selectedItems.contains(item) {
            return Color.blue.opacity(0.2)
        } else {
            return Color.clear
        }
    }
    
    private var rowOpacity: Double {
        return isMultiSelectMode && (item.isDirectory || !FileUtils.isSupportedFileType(url: item.path)) ? 0.7 : 1.0
    }
    
    private func toggleItemSelection() {
        if !item.isDirectory && FileUtils.isSupportedFileType(url: item.path) {
            if selectedItems.contains(item) {
                selectedItems.remove(item)
            } else {
                selectedItems.insert(item)
            }
        }
    }
    
    private func handleTap() {
        if isMultiSelectMode {
            handleMultiSelectTap()
        } else {
            handleSingleSelectTap()
        }
    }
    
    private func handleMultiSelectTap() {
        // In multi-select mode, only allow selection of supported files
        if !item.isDirectory && FileUtils.isSupportedFileType(url: item.path) {
            toggleItemSelection()
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
    }
    
    private func handleSingleSelectTap() {
        // In single-select mode, normal behavior
        if item.isDirectory {
            fileService.navigate(to: item.path)
            selectedItem = nil
        } else {
            selectedItem = item
            loadFileContent()
        }
    }
    
    private func loadFileContent() {
        if FileUtils.isTextFile(url: item.path) {
            do {
                fileContent = try String(contentsOf: item.path, encoding: .utf8)
            } catch {
                fileContent = "Error loading file: \(error.localizedDescription)"
            }
        } else {
            fileContent = "Preview available"
        }
    }
}

// Replace the complex view body with a simplified version that uses extracted views
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
            previewHeader
            
            // File information
            fileInfoSection
            
            Divider()
            
            // Preview content
            contentPreview
        }
        // Apply each modifier individually
        .modifier(RenameAlertModifier(
            isShowingRenameAlert: $isShowingRenameAlert,
            suggestedName: $suggestedName,
            item: item,
            performRename: performRename
        ))
        .modifier(ErrorAlertModifier(
            showErrorAlert: $showErrorAlert,
            errorMessage: renameError
        ))
        .modifier(VideoAnalysisAlertModifier(
            isShowingVideoAlert: $isShowingVideoAlert,
            performVideoAnalysis: performVideoAnalysis
        ))
        .modifier(APIKeySheetModifier(
            isShowingAPIKeyView: $isShowingAPIKeyView,
            openAIService: openAIService,
            item: item,
            isShowingVideoAlert: $isShowingVideoAlert,
            suggestedName: $suggestedName,
            isShowingRenameAlert: $isShowingRenameAlert,
            showErrorAlert: $showErrorAlert
        ))
    }
    
    // MARK: - Extracted Views
    
    private var previewHeader: some View {
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
    }
    
    private var fileInfoSection: some View {
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
    }
    
    private var contentPreview: some View {
        Group {
            if FileUtils.isTextFile(url: item.path) {
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
                if FileUtils.isPDFFile(url: item.path) {
                    PDFKitView(url: item.path)
                } else if FileUtils.isImageFile(url: item.path) {
                    ImagePreview(url: item.path)
                } else {
                    fallbackPreview
                }
                #endif
            }
        }
    }
    
    var fallbackPreview: some View {
        VStack {
            Spacer()
            
            Image(systemName: FileUtils.fileTypeIcon(for: item.path))
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
    
    // MARK: - Methods
    
    func analyzeAndRename() {
        // Check if API key is available
        if !openAIService.hasAPIKey {
            // Show API key input view
            isShowingAPIKeyView = true
            return
        }
        
        // Show specific alert for video files
        if FileUtils.isVideoFile(url: item.path) {
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
}

// Extracted ViewModifier for alerts to simplify the main view
struct RenameAlertModifier: ViewModifier {
    @Binding var isShowingRenameAlert: Bool
    @Binding var suggestedName: String
    let item: FileItem
    let performRename: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("Rename with AI", isPresented: $isShowingRenameAlert) {
                renameAlertButtons
            } message: {
                renameAlertMessage
            }
    }
    
    @ViewBuilder
    private var renameAlertButtons: some View {
        TextField("Suggested name", text: $suggestedName)
        Button("Cancel", role: .cancel) { }
        Button("Rename", action: performRename)
    }
    
    @ViewBuilder
    private var renameAlertMessage: some View {
        if FileUtils.isVideoFile(url: item.path) {
            Text("AI has analyzed frames from your video using computer vision and suggested this name based on the visual content. You can edit it before confirming.")
        } else {
            Text("AI has analyzed your image using computer vision and suggested this name. You can edit it before confirming.")
        }
    }
}

struct ErrorAlertModifier: ViewModifier {
    @Binding var showErrorAlert: Bool
    let errorMessage: String?
    
    func body(content: Content) -> some View {
        content
            .alert("Error Renaming File", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
    }
}

struct VideoAnalysisAlertModifier: ViewModifier {
    @Binding var isShowingVideoAlert: Bool
    let performVideoAnalysis: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("Analyze Video", isPresented: $isShowingVideoAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Continue") {
                    performVideoAnalysis()
                }
            } message: {
                Text("The AI will extract frames from the beginning, middle, and end of this video, then use advanced vision AI to analyze the visual content and suggest a descriptive name. Continue?")
            }
    }
}

struct APIKeySheetModifier: ViewModifier {
    @Binding var isShowingAPIKeyView: Bool
    let openAIService: OpenAIService
    let item: FileItem
    @Binding var isShowingVideoAlert: Bool
    @Binding var suggestedName: String
    @Binding var isShowingRenameAlert: Bool
    @Binding var showErrorAlert: Bool
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isShowingAPIKeyView) {
                APIKeyView(openAIService: openAIService, isPresented: $isShowingAPIKeyView)
                    .onDisappear {
                        handleAPIKeyDismissal()
                    }
            }
    }
    
    private func handleAPIKeyDismissal() {
        // If API key is available after sheet is dismissed, continue with analysis
        if openAIService.hasAPIKey {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                analyzeContentWithAI()
            }
        }
    }
    
    private func analyzeContentWithAI() {
        // Show specific alert for video files
        if FileUtils.isVideoFile(url: item.path) {
            isShowingVideoAlert = true
        } else {
            // For other file types, proceed as normal
            openAIService.analyzeImage(url: item.path) { result in
                switch result {
                case .success(let name):
                    suggestedName = name
                    isShowingRenameAlert = true
                case .failure:
                    showErrorAlert = true
                }
            }
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

#Preview {
    ContentView()
}
