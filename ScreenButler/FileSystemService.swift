import Foundation
import SwiftUI

class FileSystemService: ObservableObject {
    @Published var currentDirectory: URL
    @Published var items: [FileItem] = []
    @Published var error: String?
    @Published var directoryAccessGranted = false
    @Published var recentDirectories: [URL] = []
    
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
        
        // Load recent directories from UserDefaults
        loadRecentDirectories()
        
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
            // If we can't access a bookmarked location, prompt the user to select a starting directory
            #if os(macOS)
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Choose Starting Directory"
                alert.informativeText = "ScreenButler needs access to a directory to work with your files. Would you like to select a starting directory now?"
                alert.addButton(withTitle: "Choose Directory")
                alert.addButton(withTitle: "Use Documents")
                
                if alert.runModal() == .alertFirstButtonReturn {
                    // User wants to select a directory
                    self.showDirectoryPicker(message: "Select a starting directory")
                } else {
                    // Use Documents as fallback
                    print("Using Documents folder as fallback")
                }
            }
            #else
            // Just use Documents on iOS
            #endif
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
    
    func navigateUp() {
        guard currentDirectory.pathComponents.count > 1 else { return }
        
        // Get the parent directory
        let parentDirectory = currentDirectory.deletingLastPathComponent()
        
        // Check if we're likely to have permissions before attempting to navigate
        if isLikelyRestrictedDirectory(parentDirectory) {
            // Proactively show directory picker rather than waiting for an error
            showDirectoryPicker(
                message: "Select a folder to navigate to",
                initialDirectory: parentDirectory
            )
        } else {
            // Attempt to navigate up
            do {
                _ = try FileManager.default.contentsOfDirectory(
                    at: parentDirectory, 
                    includingPropertiesForKeys: nil,
                    options: []
                )
                
                // If successful, update and load contents
                currentDirectory = parentDirectory
                loadContents()
            } catch {
                // Handle error
                self.error = "Cannot access parent directory: \(error.localizedDescription)"
                
                // Show directory picker as fallback
                showDirectoryPicker(
                    message: "Select a folder to navigate to",
                    initialDirectory: parentDirectory
                )
            }
        }
    }
    
    // Helper to determine if a directory is likely to require special permissions
    private func isLikelyRestrictedDirectory(_ url: URL) -> Bool {
        // Check if we're trying to navigate to a high-level system directory
        let pathComponents = url.pathComponents
        if pathComponents.count <= 2 { // / or /Users would be restricted
            return true
        }
        
        // Check system locations that won't be accessible in sandbox
        let restrictedLocations = [
            "/System",
            "/Library",
            "/usr",
            "/bin",
            "/sbin",
            "/var",
            "/private",
            "/Network",
            "/Volumes",
            "/Applications"
        ]
        
        for location in restrictedLocations {
            if url.path.hasPrefix(location) {
                return true
            }
        }
        
        // Special handling for Desktop and Downloads outside of bookmark access
        let userPath = FileManager.default.homeDirectoryForCurrentUser.path
        let desktopPath = userPath + "/Desktop"
        let downloadsPath = userPath + "/Downloads"
        
        // Consider Desktop/Downloads restricted unless we have a bookmark
        if url.path.hasPrefix(desktopPath) || url.path.hasPrefix(downloadsPath) {
            // Check if we might have a bookmark for this
            if let bookmarkData = UserDefaults.standard.data(forKey: "DirectoryBookmark") {
                do {
                    var isStale = false
                    let bookmarkedURL = try URL(resolvingBookmarkData: bookmarkData,
                                              options: .withSecurityScope,
                                              relativeTo: nil,
                                              bookmarkDataIsStale: &isStale)
                    
                    // If this URL is a parent directory of our bookmarked URL, it might be accessible
                    if !isStale && bookmarkedURL.path.hasPrefix(url.path) {
                        return false
                    }
                } catch {
                    print("Error checking bookmark: \(error)")
                }
            }
            return true
        }
        
        return false
    }
    
    // Unified method for showing directory picker
    private func showDirectoryPicker(message: String, initialDirectory: URL? = nil) {
        #if os(macOS)
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.message = message
            openPanel.prompt = "Open"
            openPanel.canChooseDirectories = true
            openPanel.canChooseFiles = false
            openPanel.allowsMultipleSelection = false
            
            if let initialDir = initialDirectory {
                // Try to set initial directory, but fallback if not accessible
                if FileManager.default.fileExists(atPath: initialDir.path) {
                    openPanel.directoryURL = initialDir
                } else if let desktop = self.desktopURL {
                    openPanel.directoryURL = desktop
                }
            }
            
            if openPanel.runModal() == .OK, let selectedURL = openPanel.url {
                // Create a security bookmark for persistent access
                do {
                    let bookmarkData = try selectedURL.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    
                    // Store bookmark for future use
                    UserDefaults.standard.set(bookmarkData, forKey: "DirectoryBookmark")
                    
                    // Navigate to the selected directory
                    self.currentDirectory = selectedURL
                    self.directoryAccessGranted = true
                    self.loadContents()
                    
                    // Add to recent directories
                    self.addToRecentDirectories(selectedURL)
                } catch {
                    self.error = "Failed to bookmark directory: \(error.localizedDescription)"
                }
            }
        }
        #else
        // iOS implementation would be different
        self.error = "Folder selection not supported on this platform"
        #endif
    }
    
    // Updated request method that uses the general showDirectoryPicker
    private func requestAccessToCurrentDirectory() {
        showDirectoryPicker(
            message: "Select the folder to grant access",
            initialDirectory: currentDirectory
        )
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
    
    // Navigate to a URL and add it to recent directories
    func navigate(to url: URL) {
        // Check if the URL is a directory before navigating
        do {
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            if let isDirectory = resourceValues.isDirectory, isDirectory {
                currentDirectory = url
                loadContents()
                
                // Add to recent directories
                addToRecentDirectories(url)
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
    
    // Save a directory to recent directories list
    func addToRecentDirectories(_ url: URL) {
        // Remove if already exists to avoid duplicates
        recentDirectories.removeAll { $0.path == url.path }
        
        // Add to the front of the list
        recentDirectories.insert(url, at: 0)
        
        // Limit to last 5 directories
        if recentDirectories.count > 5 {
            recentDirectories.removeLast()
        }
        
        // Save to UserDefaults
        saveRecentDirectories()
    }
    
    // Load recent directories from UserDefaults
    private func loadRecentDirectories() {
        if let data = UserDefaults.standard.data(forKey: "RecentDirectories") {
            do {
                let bookmarks = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: data) as? [Data]
                
                if let bookmarks = bookmarks {
                    recentDirectories = bookmarks.compactMap { bookmarkData in
                        do {
                            var isStale = false
                            let url = try URL(resolvingBookmarkData: bookmarkData,
                                              options: .withSecurityScope,
                                              relativeTo: nil,
                                              bookmarkDataIsStale: &isStale)
                            return url
                        } catch {
                            print("Failed to resolve bookmark: \(error)")
                            return nil
                        }
                    }
                }
            } catch {
                print("Failed to load recent directories: \(error)")
            }
        }
    }
    
    // Save recent directories to UserDefaults
    private func saveRecentDirectories() {
        do {
            let bookmarks = try recentDirectories.map { url -> Data in
                try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            }
            
            let data = try NSKeyedArchiver.archivedData(withRootObject: bookmarks, requiringSecureCoding: true)
            UserDefaults.standard.set(data, forKey: "RecentDirectories")
        } catch {
            print("Failed to save recent directories: \(error)")
        }
    }
    
    deinit {
        #if os(macOS)
        if directoryAccessGranted {
            currentDirectory.stopAccessingSecurityScopedResource()
        }
        #endif
    }
} 
