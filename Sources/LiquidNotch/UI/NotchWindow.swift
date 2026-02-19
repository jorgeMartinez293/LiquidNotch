import Cocoa

class NotchWindow: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .statusBar // High enough for notch, low enough for drags (hopefully)
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        // Register for dragging
        self.registerForDraggedTypes([.fileURL])
    }
    
    override var canBecomeKey: Bool {
        return true // Needed for interaction
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    // MARK: - NSDraggingDestination Protocol Methods
    // Note: NSWindow does not conform to NSDraggingDestination by default, but we can implement the methods 
    // and if we register types, the window machinery will call them if they exist on the window itself 
    // (or we can set the delegate). 
    // Actually, for NSWindow, the `draggingEntered` etc are sent to the delegate OR the window subclass 
    // if it implements them. Let's try implementing them directly.
    
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        Logger.log("Window draggingEntered")
        return .copy
    }
    
    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        Logger.log("Window performDragOperation")
        guard let item = sender.draggingPasteboard.pasteboardItems?.first else { return false }
        
        if let urlString = item.string(forType: .fileURL), let url = URL(string: urlString) {
             Logger.log("Window Dropped URL: \(url)")
             
             // Access ViewModel via AppDelegate
             if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                 DispatchQueue.main.async {
                     appDelegate.viewModel.droppedFile = url
                     appDelegate.viewModel.isHovered = true
                 }
             }
             return true
        }
        return false
    }
}
