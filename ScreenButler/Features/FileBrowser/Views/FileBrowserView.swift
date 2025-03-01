import SwiftUI

struct FileBrowserView: View {
    @StateObject private var fileService = FileSystemService()
    @State private var selectedItem: FileItem?
    @State private var isShowingFileContent = false
    @State private var fileContent: String = ""
    
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
                    Image(systemName: item.icon)
                        .foregroundColor(item.isDirectory ? .blue : .gray)
                    
                    VStack(alignment: .leading) {
                        Text(item.name)
                            .lineLimit(1)
                        
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
                .onTapGesture {
                    if item.isDirectory {
                        fileService.navigate(to: item.path)
                    } else {
                        selectedItem = item
                        loadFileContent(url: item.path)
                    }
                }
            }
            .listStyle(InsetListStyle())
        }
        .onAppear {
            fileService.restoreBookmarkedAccess()
        }
        .sheet(isPresented: $isShowingFileContent) {
            if let selectedItem = selectedItem {
                VStack {
                    HStack {
                        Text(selectedItem.name)
                            .font(.headline)
                        Spacer()
                        Button("Close") {
                            isShowingFileContent = false
                        }
                    }
                    .padding()
                    
                    if isTextFile(url: selectedItem.path) {
                        ScrollView {
                            Text(fileContent)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        VStack {
                            Image(systemName: "doc")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                                .foregroundColor(.gray)
                            
                            Text("This file cannot be previewed")
                                .padding()
                        }
                        .frame(maxHeight: .infinity)
                    }
                }
                .frame(minWidth: 600, minHeight: 400)
            }
        }
    }
    
    func loadFileContent(url: URL) {
        if isTextFile(url: url) {
            do {
                fileContent = try String(contentsOf: url, encoding: .utf8)
            } catch {
                fileContent = "Error loading file: \(error.localizedDescription)"
            }
        } else {
            fileContent = "Binary file content cannot be displayed"
        }
        
        isShowingFileContent = true
    }
    
    func isTextFile(url: URL) -> Bool {
        let textExtensions = ["txt", "md", "json", "xml", "html", "css", "js", "swift", "c", "cpp", "h", "m", "py", "rb", "java", "sh"]
        return textExtensions.contains(url.pathExtension.lowercased())
    }
}

#Preview {
    FileBrowserView()
} 