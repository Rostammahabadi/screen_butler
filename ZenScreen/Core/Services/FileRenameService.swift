import Foundation
#if os(macOS)
import AppKit
#endif

class FileRenameService {
    enum RenameError: Error, LocalizedError {
        case fileDoesNotExist
        case destinationExists
        case accessDenied
        case bookmarkError
        case unknown(Error)
        
        var errorDescription: String? {
            switch self {
            case .fileDoesNotExist: return "The file doesn't exist"
            case .destinationExists: return "A file with that name already exists"
            case .accessDenied: return "You don't have permission to rename this file"
            case .bookmarkError: return "Could not create security bookmark for this file"
            case .unknown(let error): return "Error: \(error.localizedDescription)"
            }
        }
    }
    
    static func rename(fileAt sourceURL: URL, to newName: String, completion: @escaping (Result<URL, RenameError>) -> Void) {
        let fileManager = FileManager.default
        
        // Ensure the file exists
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            completion(.failure(.fileDoesNotExist))
            return
        }
        
        // Create the destination URL with the new name but keeping the original extension
        let originalExtension = sourceURL.pathExtension
        let destinationURL = sourceURL.deletingLastPathComponent()
            .appendingPathComponent(newName)
            .appendingPathExtension(originalExtension)
        
        // Check if destination already exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            completion(.failure(.destinationExists))
            return
        }
        
        #if os(macOS)
        // For macOS, we need to handle security-scoped resource access
        var sourceAccessStarted = false
        var destinationDirAccessStarted = false
        
        // Try to get access to source file
        let sourceBookmarkSuccess = sourceURL.startAccessingSecurityScopedResource()
        if sourceBookmarkSuccess {
            sourceAccessStarted = true
            print("Successfully started accessing source file: \(sourceURL.path)")
        } else {
            print("Failed to start accessing source file: \(sourceURL.path)")
            // Try to create and store a bookmark for this file
            do {
                let bookmarkData = try sourceURL.bookmarkData(options: .securityScopeAllowOnlyReadAccess, includingResourceValuesForKeys: nil, relativeTo: nil)
                let bookmarkKey = "FileBookmark-\(sourceURL.path.hash)"
                UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
                
                // Try accessing again with the newly created bookmark
                if sourceURL.startAccessingSecurityScopedResource() {
                    sourceAccessStarted = true
                    print("Successfully accessed source file after creating bookmark")
                }
            } catch {
                print("Failed to create bookmark for source: \(error)")
            }
        }
        
        // Get access to destination directory
        let destinationDir = destinationURL.deletingLastPathComponent()
        let destinationDirSuccess = destinationDir.startAccessingSecurityScopedResource()
        if destinationDirSuccess {
            destinationDirAccessStarted = true
            print("Successfully started accessing destination directory: \(destinationDir.path)")
        } else {
            print("Failed to start accessing destination directory: \(destinationDir.path)")
            // Try to create and store a bookmark for the destination directory
            do {
                let bookmarkData = try destinationDir.bookmarkData(options: .securityScopeAllowOnlyReadAccess, includingResourceValuesForKeys: nil, relativeTo: nil)
                let bookmarkKey = "DirBookmark-\(destinationDir.path.hash)"
                UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
                
                // Try accessing again with the newly created bookmark
                if destinationDir.startAccessingSecurityScopedResource() {
                    destinationDirAccessStarted = true
                    print("Successfully accessed destination directory after creating bookmark")
                }
            } catch {
                print("Failed to create bookmark for destination directory: \(error)")
            }
        }
        
        // Defer stopping security-scoped access
        defer {
            if sourceAccessStarted {
                sourceURL.stopAccessingSecurityScopedResource()
                print("Stopped accessing source file")
            }
            if destinationDirAccessStarted {
                destinationDir.stopAccessingSecurityScopedResource()
                print("Stopped accessing destination directory")
            }
        }
        #endif
        
        do {
            // Check write permission before attempting to rename
            if !fileManager.isWritableFile(atPath: sourceURL.path) {
                print("Source file is not writable: \(sourceURL.path)")
                
                #if os(macOS)
                // Try to request explicit permission
                if !requestFileAccessPermission(for: sourceURL) {
                    completion(.failure(.accessDenied))
                    return
                }
                #else
                completion(.failure(.accessDenied))
                return
                #endif
            }
            
            // Also check write permission for the destination directory
            let destinationDir = destinationURL.deletingLastPathComponent()
            if !fileManager.isWritableFile(atPath: destinationDir.path) {
                print("Destination directory is not writable: \(destinationDir.path)")
                
                #if os(macOS)
                // Try to request explicit permission for the directory
                if !requestFileAccessPermission(for: destinationDir) {
                    completion(.failure(.accessDenied))
                    return
                }
                #else
                completion(.failure(.accessDenied))
                return
                #endif
            }
            
            // Attempt to rename the file
            print("Attempting to rename \(sourceURL.path) to \(destinationURL.path)")
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            print("Successfully renamed file to: \(destinationURL.lastPathComponent)")
            completion(.success(destinationURL))
            
        } catch let error as NSError {
            print("Error during rename: \(error.localizedDescription), Domain: \(error.domain), Code: \(error.code)")
            
            if error.domain == NSCocoaErrorDomain {
                switch error.code {
                case NSFileWriteNoPermissionError:
                    print("No permission to write file")
                    completion(.failure(.accessDenied))
                case NSFileWriteOutOfSpaceError:
                    print("Out of disk space")
                    completion(.failure(.unknown(error)))
                case NSFileWriteVolumeReadOnlyError:
                    print("Volume is read-only")
                    completion(.failure(.accessDenied))
                default:
                    print("Other file error: \(error.code)")
                    completion(.failure(.unknown(error)))
                }
            } else {
                completion(.failure(.unknown(error)))
            }
        }
    }
    
    #if os(macOS)
    private static func requestFileAccessPermission(for url: URL) -> Bool {
        if #available(macOS 10.15, *) {
            // Use modern API to request access
            let openPanel = NSOpenPanel()
            openPanel.message = "Select the file to grant permission to rename it"
            openPanel.prompt = "Grant Access"
            openPanel.allowsMultipleSelection = false
            openPanel.canChooseDirectories = url.hasDirectoryPath
            openPanel.canChooseFiles = !url.hasDirectoryPath
            openPanel.directoryURL = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
            
            if !url.hasDirectoryPath {
                openPanel.nameFieldStringValue = url.lastPathComponent
            }
            
            print("Showing open panel to request access for: \(url.path)")
            let response = openPanel.runModal()
            
            if response == .OK, let selectedURL = openPanel.url {
                print("User granted access to: \(selectedURL.path)")
                
                // Create bookmark for future access
                do {
                    // Store the bookmark data
                    let bookmarkData = try selectedURL.bookmarkData(options: .securityScopeAllowOnlyReadAccess, includingResourceValuesForKeys: nil, relativeTo: nil)
                    let bookmarkKey = "FileAccessBookmark-\(selectedURL.path.hash)"
                    UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
                    print("Created and stored bookmark for: \(selectedURL.path)")
                    
                    // Start accessing this resource
                    let success = selectedURL.startAccessingSecurityScopedResource()
                    print("Started accessing resource: \(success)")
                    return success
                } catch {
                    print("Failed to create bookmark: \(error)")
                    return false
                }
            } else {
                print("User cancelled permission request")
                return false
            }
        } else {
            // Fallback for older macOS versions
            return false
        }
    }
    #endif
}
