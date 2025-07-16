// main.swift
import SwiftUI

@main
struct ClipboardManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Create a hidden window that won't show in dock
        WindowGroup {
            EmptyView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

// AppDelegate.swift
import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var floatingWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from dock
        NSApp.setActivationPolicy(.accessory)
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Use SF Symbol for better visibility
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Text Clip")
            button.action = #selector(toggleWindow)
            button.target = self
        }
        
        // Create the floating window initially
        createFloatingWindow()
    }
    
    @objc func toggleWindow() {
        guard let window = floatingWindow else { return }
        
        if window.isVisible {
            window.orderOut(nil)
        } else {
            // Position window near status bar
            if let button = statusItem?.button {
                let buttonRect = button.convert(button.bounds, to: nil)
                let screenRect = button.window?.convertToScreen(buttonRect) ?? NSRect.zero
                
                let windowRect = NSRect(
                    x: screenRect.midX - 200,
                    y: screenRect.minY - 620,
                    width: 400,
                    height: 600
                )
                
                window.setFrame(windowRect, display: true)
            }
            
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func createFloatingWindow() {
        let view = ContentView()
        
        floatingWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        floatingWindow?.title = "Text Clip"
        floatingWindow?.isReleasedWhenClosed = false
        floatingWindow?.level = .floating
        floatingWindow?.contentView = NSHostingView(rootView: view)
        
        // Hide window initially
        floatingWindow?.orderOut(nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup if needed
        statusItem = nil
    }
}

// ClipboardViewModel.swift
import SwiftUI
import AppKit

class ClipboardViewModel: ObservableObject {
    @Published var items: [ClipboardItem] = []
    @Published var searchText: String = ""
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    
    var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { item in
                switch item.content {
                case .text(let string):
                    return string.localizedCaseInsensitiveContains(searchText)
                case .image(_):
                    return false // Could add image metadata search later
                }
            }
        }
    }
    
    init() {
        startMonitoring()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.checkPasteboard()
        }
    }
    
    func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        
        if pasteboard.changeCount != lastChangeCount {
            lastChangeCount = pasteboard.changeCount
            
            // Check for text first
            if let content = pasteboard.string(forType: .string), !content.isEmpty {
                // Don't add duplicate items
                if !items.contains(where: { 
                    if case .text(let existingText) = $0.content {
                        return existingText == content
                    }
                    return false
                }) {
                    let item = ClipboardItem(
                        id: UUID(),
                        type: .text,
                        content: .text(content),
                        timestamp: Date()
                    )
                    
                    DispatchQueue.main.async {
                        self.items.insert(item, at: 0)
                        // Keep only last 50 items
                        if self.items.count > 50 {
                            self.items.removeLast()
                        }
                    }
                }
            }
            // Check for images
            else if let data = pasteboard.data(forType: .tiff), let image = NSImage(data: data) {
                let item = ClipboardItem(
                    id: UUID(),
                    type: .image,
                    content: .image(image),
                    timestamp: Date()
                )
                
                DispatchQueue.main.async {
                    self.items.insert(item, at: 0)
                    // Keep only last 50 items
                    if self.items.count > 50 {
                        self.items.removeLast()
                    }
                }
            }
        }
    }
    
    func clearAll() {
        items.removeAll()
    }
}

// ClipboardItem.swift
import Foundation
import AppKit

enum ClipboardType: String, Codable {
    case text, image
}

enum ClipboardContent {
    case text(String)
    case image(NSImage)
}

struct ClipboardItem: Identifiable {
    let id: UUID
    let type: ClipboardType
    let content: ClipboardContent
    let timestamp: Date
}

// ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ClipboardViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Text Clip")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Clear All") {
                    viewModel.clearAll()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(.regularMaterial)
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search clipboard...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                
                if !viewModel.searchText.isEmpty {
                    Button("Clear") {
                        viewModel.searchText = ""
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(.regularMaterial)
            
            Divider()
            
            // Items list
            if viewModel.filteredItems.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "clipboard")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No clipboard items")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("Copy something to get started")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.filteredItems) { item in
                            ClipboardRow(item: item)
                                .onTapGesture {
                                    paste(item: item)
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 400, minHeight: 600)
        .background(.ultraThinMaterial)
    }
    
    func paste(item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.content {
        case .text(let string):
            pasteboard.setString(string, forType: .string)
        case .image(let image):
            if let tiff = image.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
        }
        
        // Close window after pasting
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.floatingWindow?.orderOut(nil)
        }
        
        // Simulate paste
        simulateCmdV()
    }
}

// ClipboardRow.swift
import SwiftUI

struct ClipboardRow: View {
    let item: ClipboardItem
    
    var body: some View {
        HStack {
            // Type indicator
            VStack {
                Image(systemName: item.type == .text ? "doc.text" : "photo")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                switch item.content {
                case .text(let string):
                    Text(string)
                        .font(.body)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                case .image(let image):
                    if let rep = image.representations.first,
                       let cgImage = rep.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                        Image(decorative: cgImage, scale: 1, orientation: .up)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 80)
                            .cornerRadius(8)
                    } else {
                        Text("Image Preview Unavailable")
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text(item.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Click to paste")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// PasteSimulation.swift
import Cocoa

func simulateCmdV() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        let src = CGEventSource(stateID: .combinedSessionState)
        
        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: true) // Cmd
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)   // V
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: false)
        
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        
        cmdDown?.post(tap: .cgAnnotatedSessionEventTap)
        vDown?.post(tap: .cgAnnotatedSessionEventTap)
        vUp?.post(tap: .cgAnnotatedSessionEventTap)
        cmdUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}