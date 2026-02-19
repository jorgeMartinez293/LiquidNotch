import SwiftUI
import Cocoa

struct DraggableFileView<Content: View>: NSViewRepresentable {
    let fileURL: URL
    let content: Content
    var onDragEnded: ((NSDragOperation) -> Void)?
    
    init(fileURL: URL, onDragEnded: ((NSDragOperation) -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.fileURL = fileURL
        self.onDragEnded = onDragEnded
        self.content = content()
    }
    
    func makeNSView(context: Context) -> DraggableContainerView {
        let view = DraggableContainerView(fileURL: fileURL)
        view.onDragEnded = onDragEnded
        
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        view.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        return view
    }
    
    func updateNSView(_ nsView: DraggableContainerView, context: Context) {
        nsView.fileURL = fileURL
        nsView.onDragEnded = onDragEnded
    }
}

class DraggableContainerView: NSView, NSDraggingSource {
    var fileURL: URL
    var onDragEnded: ((NSDragOperation) -> Void)?
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with event: NSEvent) {
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(fileURL.absoluteString, forType: .fileURL)
        
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        
        // Capture a snapshot of the view for the drag image
        if let bitmapRep = self.bitmapImageRepForCachingDisplay(in: bounds) {
            self.cacheDisplay(in: bounds, to: bitmapRep)
            let image = NSImage(size: bounds.size)
            image.addRepresentation(bitmapRep)
            draggingItem.setDraggingFrame(bounds, contents: image)
        }
        
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }
    
    // MARK: - NSDraggingSource
    
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // Allow Move and Copy, but Move is preferred by returning it
        // If we want to FORCE move default, we should check semantics.
        // User asked for "mv x y".
        return .move
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        Logger.log("Drag Ended with operation: \(operation.rawValue)")
        if operation == .move {
             // If it was a move, the file is gone/moved.
             // We should notify the app to clear the reference.
        }
        onDragEnded?(operation)
    }
}
