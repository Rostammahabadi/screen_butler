import Foundation
import SwiftUI

class FileSystemService: ObservableObject {
    @Published var currentDirectory: URL
    @Published var items: [FileItem] = []
    @Published var error: String?
    @Published var directoryAccessGranted = false
    
    var desktopURL: URL? {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    }
    
    init() {
        // Initialize currentDirectory directly without using self
        let fileManager = FileManager.default
        if let desktop = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first {
            self.currentDirectory = desktop
        } else {
            self.currentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }
        
        // Now that all properties are initialized, we can call instance methods
        loadContents()
    }
    
    func loadContents() {
        do {
            // Check and request security-scoped access if needed
            if !directoryAccessGranted {
                requestDesktopAccess()
            }
            
            let contents = try FileManager.default.contentsOfDirectory(at: currentDirectory, 
                                                  includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                                                  options: [.skipsHiddenFiles])
            
            items = contents.compactMap { FileItem.fromURL($0) }
                .sorted { $0.isDirectory && !$1.isDirectory || $0.name.lowercased() < $1.name.lowercased() }
            
            error = nil
        } catch {
            items = []
            self.error = "Error loading directory contents: \(error.localizedDescription)"
            print("Error accessing directory: \(error)")
        }
    }
    
    func requestDesktopAccess() {
        #if os(macOS)
        guard let desktopURL = desktopURL else {
            self.error = "Cannot locate Desktop directory"
            return
        }
        
        // Attempt to access the directory
        do {
            // Start accessing security-scoped resource
            let success = desktopURL.startAccessingSecurityScopedResource()
            if success {
                directoryAccessGranted = true
                // Remember to call stopAccessingSecurityScopedResource() when done
            } else {
                // Access not granted
                self.error = "Access to Desktop was denied"
                
                // For folders requiring user permission, guide the user
                DispatchQueue.main.async {
                    let openPanel = NSOpenPanel()
                    openPanel.message = "Select your Desktop folder to grant access"
                    openPanel.prompt = "Grant Access"
                    openPanel.canChooseDirectories = true
                    openPanel.canChooseFiles = false
                    openPanel.allowsMultipleSelection = false
                    openPanel.directoryURL = desktopURL
                    
                    if openPanel.runModal() == .OK, let selectedURL = openPanel.url {
                        // User selected a directory - store access
                        do {
                            let bookmarkData = try selectedURL.bookmarkData(options: .withSecurityScope,
                                                                         includingResourceValuesForKeys: nil,
                                                                         relativeTo: nil)
                                                                         
                            // Save this bookmark data for future app launches
                            UserDefaults.standard.set(bookmarkData, forKey: "DesktopBookmark")
                            
                            // Use the selectedURL
                            self.currentDirectory = selectedURL
                            self.directoryAccessGranted = true
                            self.loadContents()
                        } catch {
                            self.error = "Failed to create security bookmark: \(error.localizedDescription)"
                        }
                    }
                }
            }
        } catch {
            self.error = "Error requesting Desktop access: \(error.localizedDescription)"
        }
        #else
        // iOS implementation would be different
        self.error = "Desktop folder access not supported on this platform"
        #endif
    }
    
    func navigate(to url: URL) {
        currentDirectory = url
        loadContents()
    }
    
    func navigateUp() {
        guard currentDirectory.pathComponents.count > 1 else { return }
        currentDirectory = currentDirectory.deletingLastPathComponent()
        loadContents()
    }
    
    func restoreBookmarkedAccess() {
        #if os(macOS)
        // Try to restore previous security-scoped access if available
        if let bookmarkData = UserDefaults.standard.data(forKey: "DesktopBookmark") {
            do {
                var isStale = false
                
                let url = try URL(resolvingBookmarkData: bookmarkData,
                                  options: .withSecurityScope,
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale)
                
                if isStale {
                    // Bookmark is stale, need to request access again
                    requestDesktopAccess()
                } else {
                    let success = url.startAccessingSecurityScopedResource()
                    if success {
                        currentDirectory = url
                        directoryAccessGranted = true
                        loadContents()
                    } else {
                        requestDesktopAccess()
                    }
                }
            } catch {
                print("Error restoring bookmark: \(error)")
                requestDesktopAccess()
            }
        } else {
            requestDesktopAccess()
        }
        #endif
    }
    
    deinit {
        #if os(macOS)
        if directoryAccessGranted {
            currentDirectory.stopAccessingSecurityScopedResource()
        }
        #endif
    }
} 
