import SwiftUI
import AppKit

@main
struct ClipboardManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            EmptyView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var floatingWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Load custom image from project bundle
            if let customImage = NSImage(named: "clipboard-icon") {
                // Configure the image for status bar usage
                customImage.isTemplate = false
                customImage.size = NSSize(width: 18, height: 18)
                button.image = customImage
            } else {
                // Fallback to system symbol if custom image is not found
                print("Warning: Custom clipboard icon not found, using system symbol")
                button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Text Clip")
            }
            
            button.action = #selector(toggleWindow)
            button.target = self
        }
        
        createFloatingWindow()
    }
    
    // Alternative method if you want to load from a specific file path
    func loadCustomStatusBarIcon() -> NSImage? {
        // Option 1: Load from main bundle
        if let image = NSImage(named: "clipboard-icon") {
            image.isTemplate = false
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        
        // Option 2: Load from specific path in bundle
        if let path = Bundle.main.path(forResource: "clipboard-icon", ofType: "png"),
           let image = NSImage(contentsOfFile: path) {
            image.isTemplate = false
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        
        return nil
    }
    
    @objc func toggleWindow() {
        guard let window = floatingWindow else { return }
        
        if window.isVisible {
            window.orderOut(nil)
        } else {
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
        
        floatingWindow?.orderOut(nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        statusItem = nil
    }
}

// MARK: - Liquid Glass Implementation (Based on Apple's Official Documentation)
struct LiquidGlassMaterial: View {
    let cornerRadius: CGFloat
    let thickness: CGFloat
    let isInteractive: Bool
    
    @State private var animationPhase: Double = 0
    @State private var isPressed: Bool = false
    @State private var isHovered: Bool = false
    
    init(cornerRadius: CGFloat = 12, thickness: CGFloat = 1.0, isInteractive: Bool = false) {
        self.cornerRadius = cornerRadius
        self.thickness = thickness
        self.isInteractive = isInteractive
    }
    
    var body: some View {
        ZStack {
            // Base glass layer with refraction
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.regularMaterial)
                .background(
                    // Refracted content layer
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.1),
                                    .clear,
                                    .black.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blur(radius: 0.5)
                )
            
            // Liquid Glass dynamic layer
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    // Dynamic fluid gradient based on Apple's implementation
                    EllipticalGradient(
                        colors: [
                            .clear,
                            .blue.opacity(0.1),
                            .purple.opacity(0.05),
                            .clear
                        ],
                        center: UnitPoint(
                            x: 0.5 + sin(animationPhase * 0.7) * 0.3,
                            y: 0.5 + cos(animationPhase * 0.5) * 0.2
                        ),
                        startRadiusFraction: 0.1,
                        endRadiusFraction: 0.8
                    )
                )
                .opacity(isHovered ? 0.6 : 0.3)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animationPhase)
            
            // Light reflection layer
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.4),
                            .clear,
                            .white.opacity(0.2)
                        ],
                        startPoint: UnitPoint(
                            x: 0.2 + sin(animationPhase * 0.3) * 0.1,
                            y: 0.0
                        ),
                        endPoint: UnitPoint(
                            x: 0.8 + sin(animationPhase * 0.3) * 0.1,
                            y: 1.0
                        )
                    )
                )
                .blendMode(.overlay)
            
            // Lensing effect at edges (Apple's signature feature)
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.8),
                            .blue.opacity(0.3),
                            .purple.opacity(0.2),
                            .white.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: thickness
                )
                .opacity(isHovered ? 0.8 : 0.5)
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
        .animation(.easeInOut(duration: 0.3), value: isHovered)
        .onAppear {
            animationPhase = 0
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                animationPhase = 2 * .pi
            }
        }
        .onHover { hovering in
            if isInteractive {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if isInteractive {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    if isInteractive {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Enhanced Button Style with Official Liquid Glass
struct LiquidGlassButton: ButtonStyle {
    @State private var isPressed: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                LiquidGlassMaterial(cornerRadius: 8, thickness: 0.5, isInteractive: true)
            }
            .foregroundStyle(.primary)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - Clipboard Models
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

// MARK: - Clipboard ViewModel
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
                    return false
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
            
            if let content = pasteboard.string(forType: .string), !content.isEmpty {
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
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            self.items.insert(item, at: 0)
                            if self.items.count > 50 {
                                self.items.removeLast()
                            }
                        }
                    }
                }
            }
            else if let data = pasteboard.data(forType: .tiff), let image = NSImage(data: data) {
                let item = ClipboardItem(
                    id: UUID(),
                    type: .image,
                    content: .image(image),
                    timestamp: Date()
                )
                
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self.items.insert(item, at: 0)
                        if self.items.count > 50 {
                            self.items.removeLast()
                        }
                    }
                }
            }
        }
    }
    
    func clearAll() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            items.removeAll()
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var viewModel = ClipboardViewModel()
    @State private var copiedItemId: UUID? = nil
    @State private var windowAppeared: Bool = false
    
    var body: some View {
        ZStack {
            // Main Liquid Glass background
            LiquidGlassMaterial(cornerRadius: 16, thickness: 1.5, isInteractive: false)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with Liquid Glass
                HStack {
                    Text("Text Clip")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Button("Clear All") {
                        viewModel.clearAll()
                    }
                    .buttonStyle(LiquidGlassButton())
                }
                .padding()
                .background {
                    LiquidGlassMaterial(cornerRadius: 12, thickness: 0.5, isInteractive: false)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Search bar with Liquid Glass
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                    
                    TextField("Search clipboard...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .font(.body)
                    
                    if !viewModel.searchText.isEmpty {
                        Button("Clear") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.searchText = ""
                            }
                        }
                        .buttonStyle(LiquidGlassButton())
                        .font(.caption)
                    }
                }
                .padding()
                .background {
                    LiquidGlassMaterial(cornerRadius: 12, thickness: 0.5, isInteractive: false)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Items list or empty state
                if viewModel.filteredItems.isEmpty {
                    VStack(spacing: 24) {
                        Spacer()
                        
                        // Empty state with Liquid Glass
                        VStack(spacing: 16) {
                            ZStack {
                                LiquidGlassMaterial(cornerRadius: 40, thickness: 1.0, isInteractive: false)
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "clipboard")
                                    .font(.system(size: 32, weight: .light))
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
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .opacity(windowAppeared ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.8), value: windowAppeared)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.filteredItems) { item in
                                ClipboardRowView(
                                    item: item,
                                    isCopied: copiedItemId == item.id
                                )
                                .onTapGesture {
                                    copyToClipboard(item: item)
                                }
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
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
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1)) {
                windowAppeared = true
            }
        }
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
        
        // Instant flex and energize effect as described in Apple docs
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            copiedItemId = item.id
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                copiedItemId = nil
            }
        }
        
        // Close window after copying
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.floatingWindow?.orderOut(nil)
            }
        }
    }
}

// MARK: - Clipboard Row with Liquid Glass
struct ClipboardRowView: View {
    let item: ClipboardItem
    let isCopied: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Type indicator with Liquid Glass
            ZStack {
                LiquidGlassMaterial(cornerRadius: 8, thickness: 0.5, isInteractive: false)
                    .frame(width: 40, height: 40)
                
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
                                    .stroke(.secondary.opacity(0.3), lineWidth: 0.5)
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
                    
                    // Copy status with Liquid Glass
                    HStack(spacing: 8) {
                        ZStack {
                            LiquidGlassMaterial(cornerRadius: 6, thickness: 0.5, isInteractive: false)
                                .frame(width: 24, height: 24)
                            
                            if isCopied {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.green)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        
                        Group {
                            if isCopied {
                                Text("Copied!")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            } else {
                                Text("Click to copy")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .transition(.opacity)
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isCopied)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background {
            LiquidGlassMaterial(cornerRadius: 12, thickness: 0.5, isInteractive: true)
        }
        .scaleEffect(isCopied ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isCopied)
    }
}

// MARK: - Paste Simulation
func simulateCmdV() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        let src = CGEventSource(stateID: .combinedSessionState)
        
        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
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