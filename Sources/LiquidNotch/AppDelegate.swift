import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var notchWindow: NotchWindow!
    var viewModel = NotchViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupNotchWindow()
    }

    func setupNotchWindow() {
        // Find Built-in Retina Display
        let screen = NSScreen.screens.first { $0.localizedName.contains("Built-in") } ?? NSScreen.main!
        let screenFrame = screen.frame
        
        // Initial Geometry from ViewModel
        let width = viewModel.notchBaseWidth
        let height = viewModel.notchBaseHeight
        
        // Calculate centered position relative to the specific screen
        let initialFrame = NSRect(
            x: screenFrame.minX + (screenFrame.width - width) / 2,
            y: screenFrame.maxY - height,
            width: width,
            height: height
        )

        notchWindow = NotchWindow(contentRect: initialFrame)
        viewModel.window = notchWindow
        
        let hostingView = NSHostingView(rootView: NotchView(viewModel: viewModel))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.autoresizingMask = [.width, .height]
        
        // Create a wrapper view that handles drags
        let dragView = DragContainerView(frame: initialFrame)
        dragView.addSubview(hostingView)
        hostingView.frame = dragView.bounds
        
        notchWindow.contentView = dragView
        notchWindow.orderFront(nil)
        
        Logger.log("App launched and window setup complete")
    }
}

class DragContainerView: NSView {
    private var dragExitTimer: Timer?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.01).cgColor // Hit-testable
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        Logger.log("Container draggingEntered")
        // Cancel any pending exit — cursor came back
        dragExitTimer?.invalidate()
        dragExitTimer = nil
        
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
             DispatchQueue.main.async {
                 // Set isTargeted FIRST so updateWindowFrame() sees expanded dimensions
                 withAnimation(.easeInOut(duration: 0.2)) {
                     appDelegate.viewModel.isTargeted = true
                 }
                 appDelegate.viewModel.setHover(true)
             }
         }
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        Logger.log("Container draggingExited")
        // Delay exit to avoid collapse when cursor hits the top screen edge
        dragExitTimer?.invalidate()
        dragExitTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.dragExitTimer = nil
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                 DispatchQueue.main.async {
                     withAnimation(.easeInOut(duration: 0.2)) {
                         appDelegate.viewModel.isTargeted = false
                     }
                     appDelegate.viewModel.setHover(false)
                 }
             }
        }
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        Logger.log("Container performDragOperation")
        dragExitTimer?.invalidate()
        dragExitTimer = nil
        
        // Reset targeted state
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
             DispatchQueue.main.async {
                 withAnimation(.easeInOut(duration: 0.2)) {
                     appDelegate.viewModel.isTargeted = false
                 }
             }
         }
        
        let pasteboard = sender.draggingPasteboard
        
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let url = urls.first {
             Logger.log("Container Dropped URL via readObjects: \(url.path)")
             
             if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                 DispatchQueue.main.async {
                     withAnimation(.spring()) {
                         appDelegate.viewModel.droppedFile = url
                         appDelegate.viewModel.isHovered = true
                     }
                     Logger.log("Updated ViewModel with dropped file")
                 }
             }
             return true
        }
        
        Logger.log("Container failed to find URL in pasteboard")
        return false
    }
}
