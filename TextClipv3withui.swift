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
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        floatingWindow?.title = "Text Clip"
        floatingWindow?.titlebarAppearsTransparent = true
        floatingWindow?.isMovableByWindowBackground = true
        floatingWindow?.backgroundColor = NSColor.clear
        floatingWindow?.isOpaque = false
        floatingWindow?.hasShadow = true
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
    @State private var copiedItemId: UUID? = nil
    
    var body: some View {
        ZStack {
            // Background with glass effect
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.05),
                                    Color.black.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 0) {
                // Header with glass effect
                HStack {
                    Text("Text Clip")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Clear All") {
                        viewModel.clearAll()
                    }
                    .buttonStyle(GlassButtonStyle())
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Search bar with glass effect
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search clipboard...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .font(.body)
                    
                    if !viewModel.searchText.isEmpty {
                        Button("Clear") {
                            viewModel.searchText = ""
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Items list
                if viewModel.filteredItems.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                            
                            Image(systemName: "clipboard")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 8) {
                            Text("No clipboard items")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text("Copy something to get started")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.filteredItems) { item in
                                ClipboardRow(item: item, isCopied: copiedItemId == item.id)
                                    .onTapGesture {
                                        copyToClipboard(item: item)
                                    }
                            }
                        }
                        .padding(16)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 600)
        .background(Color.clear)
    }
    
    func copyToClipboard(item: ClipboardItem) {
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
        
        // Set copied state with animation
        withAnimation(.easeInOut(duration: 0.2)) {
            copiedItemId = item.id
        }
        
        // Reset copied state after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                copiedItemId = nil
            }
        }
        
        // Close window after copying
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.floatingWindow?.orderOut(nil)
            }
        }
    }
}

// Custom glass button style
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// ClipboardRow.swift
import SwiftUI

struct ClipboardRow: View {
    let item: ClipboardItem
    let isCopied: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Type indicator with glass effect
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
                
                Image(systemName: item.type == .text ? "doc.text" : "photo")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                switch item.content {
                case .text(let string):
                    Text(string)
                        .font(.body)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                case .image(let image):
                    if let rep = image.representations.first,
                       let cgImage = rep.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                        Image(decorative: cgImage, scale: 1, orientation: .up)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                            )
                    } else {
                        Text("Image Preview Unavailable")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                HStack {
                    Text(item.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Reactive copy button with enhanced glass effect
                    HStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.ultraThinMaterial)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(
                                            isCopied ? Color.green.opacity(0.5) : Color.white.opacity(0.3),
                                            lineWidth: 0.5
                                        )
                                )
                            
                            if isCopied {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.green)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        
                        if isCopied {
                            Text("Copied!")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                                .transition(.opacity)
                        } else {
                            Text("Click to copy")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: isCopied)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.02),
                                    Color.black.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        .scaleEffect(isCopied ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isCopied)
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