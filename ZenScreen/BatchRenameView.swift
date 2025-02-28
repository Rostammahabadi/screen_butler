import SwiftUI

struct BatchRenameView: View {
    // Input data
    let selectedItems: [FileItem]
    @Binding var renameSuggestions: [FileItem: String]
    let onComplete: () -> Void
    
    // View state
    @StateObject private var openAIService = OpenAIService()
    @State private var currentProcessingIndex = 0
    @State private var isProcessing = false
    @State private var rejectedItems = Set<FileItem>()
    @State private var approvedItems = Set<FileItem>()
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingCompletion = false
    @State private var processedCount = 0
    @State private var successCount = 0
    @State private var isApplyingChanges = false
    @State private var filterMode: FilterMode = .all
    
    enum FilterMode: String, CaseIterable {
        case all = "All"
        case approved = "Approved"
        case rejected = "Rejected"
        case pending = "Pending"
    }
    
    var filteredItems: [FileItem] {
        switch filterMode {
        case .all:
            return selectedItems
        case .approved:
            return selectedItems.filter { approvedItems.contains($0) }
        case .rejected:
            return selectedItems.filter { rejectedItems.contains($0) }
        case .pending:
            return selectedItems.filter { 
                renameSuggestions[$0] != nil && 
                !approvedItems.contains($0) && 
                !rejectedItems.contains($0)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Batch Rename with AI")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    onComplete()
                }
                .disabled(isProcessing || isApplyingChanges)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            
            // Status bar
            HStack {
                if isProcessing {
                    ProgressView()
                        .padding(.trailing, 4)
                    Text("Analyzing \(currentProcessingIndex + 1) of \(selectedItems.count)")
                } else if isApplyingChanges {
                    ProgressView()
                        .padding(.trailing, 4)
                    Text("Applying changes...")
                } else {
                    Text("Review suggested names")
                }
                Spacer()
                
                Text("\(processedCount) of \(selectedItems.count) processed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            
            // Filter controls
            HStack {
                Text("Show:")
                    .font(.subheadline)
                
                Picker("Filter", selection: $filterMode) {
                    ForEach(FilterMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Spacer()
                
                HStack {
                    Text("✓")
                        .foregroundColor(.green)
                    Text("\(approvedItems.count)")
                        .fontWeight(.medium)
                    
                    Text("✗")
                        .foregroundColor(.red)
                        .padding(.leading, 8)
                    Text("\(rejectedItems.count)")
                        .fontWeight(.medium)
                }
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Content scrollview
            ScrollView {
                if filteredItems.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No items match the current filter")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding()
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredItems, id: \.id) { item in
                            RenameItemRow(
                                item: item,
                                suggestedName: renameSuggestions[item] ?? "",
                                isProcessing: isProcessing && currentProcessingIndex == selectedItems.firstIndex(of: item),
                                isRejected: rejectedItems.contains(item),
                                isApproved: approvedItems.contains(item),
                                onToggle: { toggleApproval(for: item) },
                                onNameEdit: { newName in
                                    // Update the suggestions dictionary with the edited name
                                    renameSuggestions[item] = newName
                                    
                                    // If the item is currently rejected, move it to approved
                                    if rejectedItems.contains(item) {
                                        rejectedItems.remove(item)
                                        approvedItems.insert(item)
                                    }
                                }
                            )
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .background(rowBackgroundColor(for: item))
                            .cornerRadius(8)
                            .padding(.horizontal, 8)
                            .transition(.opacity)
                        }
                    }
                    .padding(.vertical)
                }
            }
            
            // Action buttons
            HStack {
                Button("Reject All") {
                    // Add all processed items to rejected
                    for item in selectedItems where renameSuggestions[item] != nil {
                        rejectedItems.insert(item)
                        approvedItems.remove(item)
                    }
                }
                .disabled(processedCount == 0 || isProcessing || isApplyingChanges)
                
                Spacer()
                
                Button("Approve All") {
                    // Add all processed items to approved
                    for item in selectedItems where renameSuggestions[item] != nil {
                        approvedItems.insert(item)
                        rejectedItems.remove(item)
                    }
                }
                .disabled(processedCount == 0 || isProcessing || isApplyingChanges)
                
                Spacer()
                
                Button(action: applyChanges) {
                    Text("Apply Changes (\(approvedItems.count))")
                        .bold()
                }
                .disabled(approvedItems.isEmpty || isProcessing || isApplyingChanges)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            startProcessing()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Renaming Complete", isPresented: $showingCompletion) {
            Button("Done", role: .cancel) {
                onComplete()
            }
        } message: {
            Text("Successfully renamed \(successCount) of \(approvedItems.count) files.")
        }
        .animation(.easeInOut, value: filterMode)
    }
    
    private func startProcessing() {
        guard currentProcessingIndex < selectedItems.count else {
            isProcessing = false
            return
        }
        
        isProcessing = true
        let item = selectedItems[currentProcessingIndex]
        
        // Skip directories
        if item.isDirectory {
            moveToNextItem()
            return
        }
        
        // Analyze the current item with OpenAI
        processItems()
    }
    
    private func moveToNextItem() {
        currentProcessingIndex += 1
        
        // If we've processed all items, finish
        if currentProcessingIndex >= selectedItems.count {
            isProcessing = false
            return
        }
        
        // Otherwise, start processing the next item
        startProcessing()
    }
    
    private func toggleApproval(for item: FileItem) {
        if approvedItems.contains(item) {
            approvedItems.remove(item)
            rejectedItems.insert(item)
        } else if rejectedItems.contains(item) {
            rejectedItems.remove(item)
            approvedItems.insert(item)
        } else {
            // Not in either set yet, so approve it
            approvedItems.insert(item)
        }
    }
    
    private func rowBackgroundColor(for item: FileItem) -> Color {
        if rejectedItems.contains(item) {
            return Color.red.opacity(0.1)
        } else if approvedItems.contains(item) {
            return Color.green.opacity(0.1)
        } else if renameSuggestions[item] != nil {
            return Color.yellow.opacity(0.05) // Processed but not decided
        } else {
            return Color.clear // Not processed yet
        }
    }
    
    private func applyChanges() {
        guard !approvedItems.isEmpty else { return }
        
        isApplyingChanges = true
        successCount = 0
        
        // Create a task group to handle renaming in parallel
        let group = DispatchGroup()
        
        for item in approvedItems {
            guard let newName = renameSuggestions[item] else { continue }
            
            group.enter()
            FileRenameService.rename(fileAt: item.path, to: newName) { result in
                defer { group.leave() }
                
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        successCount += 1
                    }
                case .failure(let error):
                    print("Error renaming \(item.name): \(error.localizedDescription)")
                }
            }
        }
        
        group.notify(queue: .main) {
            isApplyingChanges = false
            showingCompletion = true
        }
    }
    
    private func processItems() {
        guard !selectedItems.isEmpty else { return }
        
        isProcessing = true
        let aiService = OpenAIService()
        
        // Filter items to ensure only supported types are processed
        let supportedItems = selectedItems.filter { item in
            return !item.isDirectory && FileUtils.isSupportedFileType(url: item.path)
        }
        
        let totalItems = supportedItems.count
        var processed = 0
        
        // Show warning if some items were filtered out
        if supportedItems.count < selectedItems.count {
            errorMessage = "Some items were skipped because they are not supported file types."
            showingError = true
        }
        
        // If no supported items, end processing
        if supportedItems.isEmpty {
            isProcessing = false
            return
        }
        
        for (index, item) in supportedItems.enumerated() {
            // Update processing index for UI
            currentProcessingIndex = selectedItems.firstIndex(of: item) ?? index
            
            // Use the analyzeImage method to process both image and non-image files
            aiService.analyzeImage(url: item.path) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let suggestion):
                        self.renameSuggestions[item] = suggestion
                    case .failure(let error):
                        print("Error processing \(item.name): \(error.localizedDescription)")
                        // Generate a simple suggestion for this file as fallback
                        let nameWithoutExtension = item.path.deletingPathExtension().lastPathComponent
                        let fallbackName = nameWithoutExtension
                            .replacingOccurrences(of: "_", with: " ")
                            .replacingOccurrences(of: "-", with: " ")
                            .capitalized
                        self.renameSuggestions[item] = fallbackName
                    }
                    
                    // Update processing state
                    processed += 1
                    self.processedCount = processed
                    
                    // Check if all items have been processed
                    if processed == totalItems {
                        self.isProcessing = false
                    }
                }
            }
        }
    }
}

struct RenameItemRow: View {
    let item: FileItem
    let suggestedName: String
    let isProcessing: Bool
    let isRejected: Bool
    let isApproved: Bool
    let onToggle: () -> Void
    var onNameEdit: (String) -> Void
    
    @State private var editedName: String = ""
    @State private var isEditing: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                // File icon
                Image(systemName: item.icon)
                    .font(.title2)
                    .frame(width: 30)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 10) {
                    // Original name
                    HStack {
                        Text("Original:")
                            .fontWeight(.medium)
                            .frame(width: 70, alignment: .leading)
                        
                        Text(item.name)
                            .lineLimit(1)
                    }
                    
                    // Suggested name
                    HStack {
                        Text("Suggested:")
                            .fontWeight(.medium)
                            .frame(width: 70, alignment: .leading)
                        
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Analyzing...")
                                .foregroundColor(.secondary)
                        } else if !suggestedName.isEmpty {
                            if isEditing {
                                TextField("Enter name", text: $editedName, onCommit: {
                                    isEditing = false
                                    // Update parent with edited name
                                    onNameEdit(editedName)
                                })
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.8))
                                .cornerRadius(4)
                                .frame(minWidth: 200)
                                
                                Text(".\(item.path.pathExtension)")
                                    .foregroundColor(.blue)
                                
                                Button(action: { 
                                    isEditing = false
                                    // Update parent with edited name
                                    onNameEdit(editedName)
                                }) {
                                    Text("Done")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            } else {
                                Text("\(suggestedName).\(item.path.pathExtension)")
                                    .lineLimit(1)
                                    .foregroundColor(.blue)
                                
                                Button(action: {
                                    editedName = suggestedName
                                    isEditing = true
                                }) {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 4)
                            }
                        } else {
                            Text("Waiting...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Approval controls
                if !suggestedName.isEmpty && !isEditing {
                    HStack(spacing: 12) {
                        // Reject button
                        Button(action: onToggle) {
                            Image(systemName: isRejected ? "xmark.circle.fill" : "xmark.circle")
                                .foregroundColor(isRejected ? .red : .gray)
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        
                        // Approve button
                        Button(action: onToggle) {
                            Image(systemName: isApproved ? "checkmark.circle.fill" : "checkmark.circle")
                                .foregroundColor(isApproved ? .green : .gray)
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
        .onAppear {
            // Initialize with suggested name
            editedName = suggestedName
        }
        .onChange(of: suggestedName) { newValue in
            // Update edited name if suggested name changes
            editedName = newValue
        }
    }
}

#Preview {
    // Create some mock data for the preview
    let items = [
        FileItem(name: "vacation_pic_1.jpg", path: URL(string: "file:///vacation_pic_1.jpg")!, isDirectory: false, size: 1024, modificationDate: Date(), icon: "photo"),
        FileItem(name: "screenshot_2023.png", path: URL(string: "file:///screenshot_2023.png")!, isDirectory: false, size: 2048, modificationDate: Date(), icon: "photo"),
        FileItem(name: "document.pdf", path: URL(string: "file:///document.pdf")!, isDirectory: false, size: 4096, modificationDate: Date(), icon: "doc")
    ]
    
    return BatchRenameView(
        selectedItems: items,
        renameSuggestions: .constant([
            items[0]: "Beach_Sunset_Hawaii",
            items[1]: "Dashboard_Analytics"
        ]),
        onComplete: {}
    )
} 