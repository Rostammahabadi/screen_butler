import Foundation

struct FileItem: Identifiable, Hashable {
    var id: String { path.path }
    let name: String
    let path: URL
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date?
    let icon: String
    
    static func fromURL(_ url: URL) -> FileItem? {
        do {
            let resourceValues = try url.resourceValues(forKeys: [
                .isDirectoryKey,
                .fileSizeKey,
                .contentModificationDateKey
            ])
            
            let isDirectory = resourceValues.isDirectory ?? false
            let icon = isDirectory ? "folder" : "doc"
            
            return FileItem(
                name: url.lastPathComponent,
                path: url,
                isDirectory: isDirectory,
                size: Int64(resourceValues.fileSize ?? 0),
                modificationDate: resourceValues.contentModificationDate,
                icon: icon
            )
        } catch {
            print("Error reading file attributes: \(error)")
            return nil
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    var formattedDate: String {
        guard let date = modificationDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
} 