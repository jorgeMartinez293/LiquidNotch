import SwiftUI
import Cocoa
import Combine

class NotchViewModel: ObservableObject {
    @Published var isHovered: Bool = false {
        didSet { updateWindowFrame() }
    }
    

    
    private var hoverTimer: Timer?
    func setHover(_ hovering: Bool) {
        if hovering {
            hoverTimer?.invalidate()
            isHovered = true
        } else {
            // Delay closing to prevent flickering
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                self?.isHovered = false
            }
        }
    }
    

    
    // ... (rest of properties)
    
    func updateWindowFrame() {
        guard let window = window, let screen = window.screen else { return }
        
        // ... (rest of logic)
        
        var targetWidth: CGFloat
        var targetHeight: CGFloat
        

        if isHovered {
            targetWidth = expandedWidth
            targetHeight = expandedHeight
        } else {
            // Collapsed state (Music Info or Notch)
             targetWidth = isPlaying ? playingWidth : notchBaseWidth
             targetHeight = notchBaseHeight
        }
        
        let screenFrame = screen.frame
        let newX = screenFrame.minX + (screenFrame.width - targetWidth) / 2
        let topOffset: CGFloat = 0
        let newY = screenFrame.maxY - targetHeight + topOffset
        
        let newFrame = NSRect(x: newX, y: newY, width: targetWidth, height: targetHeight)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .default)
            window.animator().setFrame(newFrame, display: true)
        }
    }
    
    // We keep the service internal but sync state
    private var spotifyService = SpotifyService()
    private var systemService = SystemStatusService()
    
    @Published var isPlaying: Bool = false
    @Published var currentTrack: TrackInfo?
    @Published var playerPosition: Double = 0
    @Published var volume: Double = 0.5
    
    var artworkUrl: String? { currentTrack?.artworkUrl }
    
    var shouldShowMusicInfo: Bool {
        return isPlaying && !isHovered
    }
    
    // Dimensions
    let notchBaseWidth: CGFloat = 180
    let notchBaseHeight: CGFloat = 30 // Reduced to hide under real notch
    
    let expandedWidth: CGFloat = 440 // Increased to fit content

    let expandedHeight: CGFloat = 180 // Adjusted for increased vertical separation
    


    
    var playingWidth: CGFloat { notchBaseWidth + 80 }
    
    var currentNotchWidth: CGFloat {
        if isHovered || isTargeted { return expandedWidth }
        return isPlaying ? playingWidth : notchBaseWidth
    }
    
    var currentNotchHeight: CGFloat {
        if isHovered || isTargeted { return expandedHeight }
        return notchBaseHeight
    }
    
    weak var window: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    

    
    init() {
        // Sync Service -> ViewModel
        spotifyService.$isPlaying
            .receive(on: RunLoop.main)
            .sink { [weak self] playing in
                withAnimation(.easeInOut(duration: 0.3)) {
                    self?.isPlaying = playing
                }
            }
            .store(in: &cancellables)
            
        spotifyService.$currentTrack
            .receive(on: RunLoop.main)
            .sink { [weak self] track in
                print("ViewModel received track: \(String(describing: track))")
                self?.currentTrack = track
            }
            .store(in: &cancellables)
            
        spotifyService.$playerPosition
            .receive(on: RunLoop.main)
            .assign(to: \.playerPosition, on: self)
            .store(in: &cancellables)
            
        // Extract color when artwork URL changes
        spotifyService.$currentTrack
            .map { $0?.artworkUrl }
            .removeDuplicates()
            .sink { [weak self] url in
                self?.extractColor(from: url)
            }
            .store(in: &cancellables)
            
        systemService.$volume
            .receive(on: RunLoop.main)
            .assign(to: \.volume, on: self)
            .store(in: &cancellables)
            
        // Trigger Window Resize on Play/Hover change
        $isPlaying
            .sink { [weak self] playing in
                if playing {
                     DispatchQueue.main.async { self?.updateWindowFrame() }
                } else {
                     // Delay shrink to allow fade out animation
                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                         self?.updateWindowFrame()
                     }
                }
            }
            .store(in: &cancellables)
            
        $isHovered
             .sink { [weak self] _ in // Expanded is larger now
                 DispatchQueue.main.async { self?.updateWindowFrame() }
             }
             .store(in: &cancellables)
        
        $isTargeted
             .sink { [weak self] _ in
                 DispatchQueue.main.async { self?.updateWindowFrame() }
             }
             .store(in: &cancellables)
    }
    

    
    // Proxy methods
    func togglePlayPause() { spotifyService.togglePlayPause() }
    func nextTrack() { spotifyService.nextTrack() }
    func previousTrack() { spotifyService.previousTrack() }
    func setVolume(_ vol: Double) { systemService.setVolume(vol) }
    
    // MARK: - Color Extraction
    @Published var albumColor: Color = .green
    
    private func extractColor(from urlString: String?) {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            self.albumColor = .green
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let data = try? Data(contentsOf: url), let nsImage = NSImage(data: data) {
                if let color = nsImage.averageColor {
                    DispatchQueue.main.async {
                        self.albumColor = Color(nsColor: color)
                    }
                }
            }
        }
    }
    // MARK: - Drag and Drop
    @Published var droppedFile: URL?
    @Published var isTargeted: Bool = false
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        Logger.log("handleDrop called with \(providers.count) providers")
        guard let provider = providers.first else { return false }
        
        // Try loading as URL directly (preferred for file drops)
        if provider.canLoadObject(ofClass: URL.self) {
             Logger.log("Provider can load URL object")
             _ = provider.loadObject(ofClass: URL.self) { [weak self] url, error in
                 if let error = error {
                     Logger.log("Error loading URL object: \(error)")
                     return
                 }
                 
                 guard let url = url else {
                     Logger.log("URL object is nil")
                     return
                 }
                 
                 Logger.log("Successfully loaded URL: \(url.path)")
                 DispatchQueue.main.async {
                     self?.droppedFile = url
                     self?.isHovered = true // Expand to show
                     Logger.log("Updated droppedFile and isHovered on main thread")
                 }
             }
             return true
        }
        
        // Fallback to legacy identifier
        if provider.hasItemConformingToTypeIdentifier("public.file-url") {
            Logger.log("Provider has public.file-url (legacy check)")
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
                if let error = error {
                    Logger.log("Error loading item: \(error)")
                    return
                }
                
                DispatchQueue.main.async {
                    if let urlData = urlData as? Data,
                       let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                        Logger.log("Loaded URL from Data: \(url)")
                        self.droppedFile = url
                        self.isHovered = true 
                    } else if let url = urlData as? URL {
                        Logger.log("Loaded URL directly: \(url)")
                        self.droppedFile = url
                        self.isHovered = true
                    } else {
                         Logger.log("Could not convert urlData: \(String(describing: urlData))")
                    }
                }
            }
            return true
        } else {
             Logger.log("Provider DOES NOT match file-url. Identifiers: \(provider.registeredTypeIdentifiers)")
        }
        return false
    }
}



extension NSImage {
    var averageColor: NSColor? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let inputImage = CIImage(cgImage: cgImage)
        let extent = inputImage.extent
        let inputExtent = CIVector(x: extent.origin.x, y: extent.origin.y, z: extent.size.width, w: extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: inputExtent]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        return NSColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: CGFloat(bitmap[3]) / 255)
    }
}
