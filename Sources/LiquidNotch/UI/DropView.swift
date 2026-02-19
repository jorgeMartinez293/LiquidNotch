import SwiftUI
import Cocoa

struct DropView: NSViewRepresentable {
    var onDrop: (URL) -> Void

    func makeNSView(context: Context) -> DropNSView {
        let view = DropNSView()
        view.onDrop = onDrop
        return view
    }

    func updateNSView(_ nsView: DropNSView, context: Context) {
    }
}

class DropNSView: NSView {
    var onDrop: ((URL) -> Void)?

    init() {
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.red.withAlphaComponent(0.001).cgColor // Almost clear but hit-testable
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        Logger.log("NSView draggingEntered")
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        Logger.log("NSView performDragOperation")
        let pasteboard = sender.draggingPasteboard
        
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let url = urls.first {
             Logger.log("NSView Dropped URL: \(url.path)")
             onDrop?(url)
             return true
        }
        
        return false
    }
}
