import Foundation
import SwiftUI

class FileSystemService: ObservableObject {
    @Published var currentDirectory: URL
    @Published var items: [FileItem] = []
    @Published var error: String?
    @Published var directoryAccessGranted = false
    
    // Safe directories that should always be accessible
    var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    var desktopURL: URL? {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    }
    
    var homeURL: URL? {
        FileManager.default.homeDirectoryForCurrentUser
    }
    
    init() {
        // Start with Documents directory which should always be accessible in sandbox
        self.currentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Now that all properties are initialized, we can call instance methods
        loadContents()
        
        // Attempt to access the preferred directory after loading documents as fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.attemptToAccessPreferredDirectory()
        }
    }
    
    // Try to access the user's preferred starting directory
    private func attemptToAccessPreferredDirectory() {
        // First try to restore any previously bookmarked location
        let restored = restoreBookmarkedAccess()
        
        if !restored {
            // If restoration fails, try to access the Desktop
            if let desktop = desktopURL {
                let success = desktop.startAccessingSecurityScopedResource()
                if success {
                    self.currentDirectory = desktop
                    self.directoryAccessGranted = true
                    desktop.stopAccessingSecurityScopedResource() // Release temporary access
                    self.loadContents()
                } else {
                    // If we can't access Desktop, just stay with Documents
                    print("Could not access Desktop, staying with Documents folder")
                }
            }
        }
    }
    
    func loadContents() {
        do {
            // Clear previous error
            error = nil
            
            // Try to access the directory if needed
            var accessGranted = false
            
            // Only try to get security-scoped access if needed
            // This is mainly for accessing Desktop/Downloads in sandboxed app
            let isRestrictedLocation = isRestrictedSystemDirectory(currentDirectory)
            
            if isRestrictedLocation {
                accessGranted = currentDirectory.startAccessingSecurityScopedResource()
                if !accessGranted {
                    // If we can't access directly, try requesting access
                    requestAccessToCurrentDirectory()
                    // Early return, requestAccessToCurrentDirectory will reload contents if successful
                    return
                }
            }
            
            // Now try to get directory contents
            let contents = try FileManager.default.contentsOfDirectory(
                at: currentDirectory, 
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            items = contents.compactMap { FileItem.fromURL($0) }
                .sorted { $0.isDirectory && !$1.isDirectory || $0.name.lowercased() < $1.name.lowercased() }
            
            // Release security-scoped access if we obtained it
            if isRestrictedLocation && accessGranted {
                currentDirectory.stopAccessingSecurityScopedResource()
            }
            
        } catch {
            items = []
            // Set a more user-friendly error message
            if error._domain == NSCocoaErrorDomain && error._code == 257 {
                self.error = "Permission denied. You don't have access to this folder."
            } else if error._domain == NSPOSIXErrorDomain && error._code == 20 {
                self.error = "The path is not a directory or doesn't exist."
                
                // Fall back to Documents directory
                DispatchQueue.main.async {
                    // Navigate to documents directory as a fallback
                    self.navigateToSafeLocation()
                }
            } else {
                self.error = "Error loading directory: \(error.localizedDescription)"
            }
            
            print("Error accessing directory: \(error)")
        }
    }
    
    // Helper to check if this is a system directory that might need special access
    private func isRestrictedSystemDirectory(_ url: URL) -> Bool {
        let restrictedPaths = [
            "/Users/", // User directory or subdirectories
            "/Desktop/",
            "/Downloads/",
            "/Documents/",
            "/Library/"
        ]
        
        let path = url.path
        return restrictedPaths.contains { path.contains($0) }
    }
    
    // Navigate to a safe location when encountering permissions errors
    private func navigateToSafeLocation() {
        self.currentDirectory = self.documentsURL
        self.loadContents()
    }
    
    private func requestAccessToCurrentDirectory() {
        #if os(macOS)
        // For folders requiring user permission, guide the user
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.message = "Select the folder to grant access"
            openPanel.prompt = "Grant Access"
            openPanel.canChooseDirectories = true
            openPanel.canChooseFiles = false
            openPanel.allowsMultipleSelection = false
            openPanel.directoryURL = self.currentDirectory
            
            if openPanel.runModal() == .OK, let selectedURL = openPanel.url {
                // User selected a directory - store access
                do {
                    let bookmarkData = try selectedURL.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                                                             
                    // Save this bookmark data for future app launches
                    UserDefaults.standard.set(bookmarkData, forKey: "DirectoryBookmark")
                    
                    // Use the selectedURL
                    self.currentDirectory = selectedURL
                    self.directoryAccessGranted = true
                    self.loadContents()
                } catch {
                    self.error = "Failed to create security bookmark: \(error.localizedDescription)"
                    self.navigateToSafeLocation()
                }
            } else {
                // User canceled - navigate to a safe location
                self.navigateToSafeLocation()
            }
        }
        #else
        // iOS implementation would be different
        self.error = "Folder access not supported on this platform"
        self.navigateToSafeLocation()
        #endif
    }
    
    func requestDesktopAccess() {
        #if os(macOS)
        guard let desktopURL = desktopURL else {
            self.error = "Cannot locate Desktop directory"
            return
        }
        
        // For Desktop folder, guide the user directly
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
                    let bookmarkData = try selectedURL.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                                                             
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
        #else
        // iOS implementation would be different
        self.error = "Desktop folder access not supported on this platform"
        #endif
    }
    
    func navigate(to url: URL) {
        // Check if the URL is a directory before navigating
        do {
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            if let isDirectory = resourceValues.isDirectory, isDirectory {
                currentDirectory = url
                loadContents()
            } else {
                self.error = "Cannot navigate to this path as it is not a directory"
            }
        } catch {
            // If we can't determine if it's a directory, still try to navigate
            // The loadContents method will handle any errors
            currentDirectory = url
            loadContents()
        }
    }
    
    func navigateUp() {
        guard currentDirectory.pathComponents.count > 1 else { return }
        
        // Store the current directory in case we need to revert
        let previousDirectory = currentDirectory
        
        // Try to navigate up
        currentDirectory = currentDirectory.deletingLastPathComponent()
        
        // Check if we can access the parent directory
        do {
            _ = try FileManager.default.contentsOfDirectory(
                at: currentDirectory, 
                includingPropertiesForKeys: nil,
                options: []
            )
            
            // If successful, load contents normally
            loadContents()
        } catch {
            // If we can't access the parent directory, revert and show error
            currentDirectory = previousDirectory
            self.error = "Cannot access parent directory: \(error.localizedDescription)"
            
            // Try to request access
            requestAccessToCurrentDirectory()
        }
    }
    
    func restoreBookmarkedAccess() -> Bool {
        #if os(macOS)
        // Try to restore previous security-scoped access if available
        if let bookmarkData = UserDefaults.standard.data(forKey: "DirectoryBookmark") {
            do {
                var isStale = false
                
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if isStale {
                    // Bookmark is stale, return false to try alternatives
                    return false
                } else {
                    let success = url.startAccessingSecurityScopedResource()
                    if success {
                        // Successfully restored
                        currentDirectory = url
                        directoryAccessGranted = true
                        loadContents()
                        // Release the access immediately, we'll reacquire it as needed
                        url.stopAccessingSecurityScopedResource()
                        return true
                    }
                }
            } catch {
                print("Error restoring bookmark: \(error)")
            }
        }
        
        // Also try Desktop-specific bookmark as a fallback
        if let bookmarkData = UserDefaults.standard.data(forKey: "DesktopBookmark") {
            do {
                var isStale = false
                
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if !isStale {
                    let success = url.startAccessingSecurityScopedResource()
                    if success {
                        // Successfully restored Desktop access
                        currentDirectory = url
                        directoryAccessGranted = true
                        loadContents()
                        // Release the access immediately, we'll reacquire it as needed
                        url.stopAccessingSecurityScopedResource()
                        return true
                    }
                }
            } catch {
                print("Error restoring Desktop bookmark: \(error)")
            }
        }
        #endif
        
        return false
    }
    
    deinit {
        #if os(macOS)
        if directoryAccessGranted {
            currentDirectory.stopAccessingSecurityScopedResource()
        }
        #endif
    }
} 
