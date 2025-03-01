//
//  ScreenButlerApp.swift
//  ScreenButler
//
//  Created by Rostam on 2/28/25.
//

import SwiftUI

@main
struct ScreenButlerApp: App {
    // Create the FileSystemService at the App level
    @StateObject private var fileService = FileSystemService()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        WindowGroup {
            ContentView(isInWindow: true)
                .frame(minWidth: 800, minHeight: 600)
                .environmentObject(fileService)
                .onAppear {
                    // Pass the fileService to the AppDelegate when the app appears
                    appDelegate.setFileService(fileService)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        // Don't show the app in the Dock
        Settings {
            EmptyView()
        }
    }
}

#if os(macOS)
// App Delegate for managing menu bar and window
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var window: NSWindow?
    
    @Published var showFullApp: Bool = false
    // Don't initialize fileService here, it will be provided by the ScreenButlerApp
    var fileService: FileSystemService!
    
    // Function to receive the fileService from ScreenButlerApp
    func setFileService(_ service: FileSystemService) {
        fileService = service
        // Update any UI that depends on fileService
        updateUIWithFileService()
    }
    
    private func updateUIWithFileService() {
        // Only update UI components if they're already initialized
        if popover != nil {
            setupPopover()
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up the status bar item
        setupStatusBarItem()
        
        // Set up the popover for menu display
        setupPopover()
        
        // Make the app a pure background application (no dock icon, no Command+Tab)
        // Note: This is redundant with LSUIElement in Info.plist, but provides a fallback
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "ScreenButler")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        
        if fileService != nil {
            popover.contentViewController = NSHostingController(
                rootView: MenuBarView(appDelegate: self)
                    .environmentObject(fileService)
            )
        } else {
            // Create a basic view if fileService is not yet available
            popover.contentViewController = NSHostingController(
                rootView: Text("Loading...")
                    .frame(width: 300, height: 400)
            )
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    func openMainWindow() {
        // Close the popover if it's open
        if popover.isShown {
            popover.performClose(nil)
        }
        
        // Temporarily switch to regular app mode while window is open
        NSApp.setActivationPolicy(.regular)
        
        // Create the window if it doesn't exist
        if window == nil && fileService != nil {
            let contentView = ContentView(isInWindow: true)
                .environmentObject(fileService)
            let hostingController = NSHostingController(rootView: contentView)
            
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window?.title = "ScreenButler"
            window?.center()
            window?.contentViewController = hostingController
            window?.isReleasedWhenClosed = false
            window?.makeKeyAndOrderFront(nil)
            
            // Add window delegate to handle window closing
            window?.delegate = self
        } else if window != nil {
            window?.makeKeyAndOrderFront(nil)
        }
        
        // Bring app to front
        NSApp.activate(ignoringOtherApps: true)
    }
}

// Handle window closing to return to accessory mode
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Switch back to accessory mode when window is closed
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
#endif

// A compact view for the menu bar popover
struct MenuBarView: View {
    @ObservedObject var appDelegate: AppDelegate
    @EnvironmentObject var fileService: FileSystemService
    @State private var isShowingFilePicker = false
    @State private var isAnalyzingFolder = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("ScreenButler")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            
            ScrollView {
                VStack(spacing: 16) {
                    // Quick actions section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Actions")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        QuickActionButton(
                            title: "Browse Files",
                            icon: "folder",
                            description: "Open file browser window",
                            action: { appDelegate.openMainWindow() }
                        )
                        
                        QuickActionButton(
                            title: "Select Directory",
                            icon: "folder.badge.plus",
                            description: "Choose a directory to analyze",
                            action: { isShowingFilePicker = true }
                        )
                        
                        QuickActionButton(
                            title: "Smart Rename Directory",
                            icon: "sparkles.rectangle.stack",
                            description: "Analyze and rename ambiguous files",
                            action: {
                                isShowingFilePicker = true
                                isAnalyzingFolder = true
                            }
                        )
                    }
                    .padding()
                    
                    Divider()
                    
                    // Recent directories section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Directories")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if fileService.recentDirectories.isEmpty {
                            Text("No recent directories")
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(fileService.recentDirectories.prefix(5), id: \.self) { url in
                                Button(action: {
                                    // Navigate to this directory and open the main window
                                    fileService.navigate(to: url)
                                    NotificationCenter.default.post(
                                        name: Notification.Name("OpenDirectoryNotification"),
                                        object: nil,
                                        userInfo: ["url": url, "skipFolderPicker": true]
                                    )
                                    appDelegate.openMainWindow()
                                }) {
                                    HStack {
                                        Image(systemName: "folder")
                                            .foregroundColor(.blue)
                                        
                                        VStack(alignment: .leading) {
                                            Text(url.lastPathComponent)
                                                .lineLimit(1)
                                                .font(.callout)
                                            
                                            Text(url.deletingLastPathComponent().lastPathComponent)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                                
                                if url != fileService.recentDirectories.last {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            
            // Footer
            HStack {
                Text("v1.0")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    NSApp.terminate(nil)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                            .font(.caption)
                        Text("Quit")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
            }
            .padding(10)
            .background(Color.secondary.opacity(0.05))
        }
        .frame(width: 320, height: 480)
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            // Handle directory selection
            if case .success(let urls) = result, let url = urls.first {
                // Add to recent directories
                fileService.addToRecentDirectories(url)
                
                // Navigate to the selected directory
                fileService.navigate(to: url)
                
                // Notify the main window to open this directory
                NotificationCenter.default.post(
                    name: Notification.Name("OpenDirectoryNotification"),
                    object: nil,
                    userInfo: ["url": url, "skipFolderPicker": true]
                )
                
                // Open the main window
                appDelegate.openMainWindow()
                
                // If analyzing, automatically trigger smart select
                if isAnalyzingFolder {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        NotificationCenter.default.post(
                            name: Notification.Name("TriggerSmartSelectNotification"),
                            object: nil
                        )
                    }
                    isAnalyzingFolder = false
                }
            }
        }
    }
}

// Quick action button component
struct QuickActionButton: View {
    let title: String
    let icon: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}
