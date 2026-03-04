import Foundation
import Cocoa
import Combine
import IOKit.graphics

enum IndicatorType {
    case volume
    case brightness
}

class SystemStatusService: ObservableObject {
    @Published var volume: Double = 0.5
    @Published var brightness: Double = 0.5
    @Published var showingIndicator: IndicatorType? = nil
    
    private var cancellables = Set<AnyCancellable>()
    private var dismissTimer: Timer?
    var eventTap: CFMachPort?
    
    // DisplayServices private framework
    private typealias DSGetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias DSSetBrightness = @convention(c) (UInt32, Float) -> Int32
    private var dsGetBrightness: DSGetBrightness?
    private var dsSetBrightness: DSSetBrightness?
    
    // Polling fallback state
    private var previousVolume: Double = -1
    private var previousBrightness: Double = -1
    
    init() {
        loadDisplayServices()
        fetchVolume()
        fetchBrightness()
        previousVolume = volume
        previousBrightness = brightness
        
        setupEventTap()
        
        // Always poll brightness as a backup (event tap handles keys, polling catches external changes)
        Timer.publish(every: 0.15, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pollForChanges()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - DisplayServices Framework
    private func loadDisplayServices() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW) else {
            print("[SystemStatus] Could not load DisplayServices framework")
            return
        }
        if let sym = dlsym(handle, "DisplayServicesGetBrightness") {
            dsGetBrightness = unsafeBitCast(sym, to: DSGetBrightness.self)
        }
        if let sym = dlsym(handle, "DisplayServicesSetBrightness") {
            dsSetBrightness = unsafeBitCast(sym, to: DSSetBrightness.self)
        }
        print("[SystemStatus] DisplayServices loaded: get=\(dsGetBrightness != nil) set=\(dsSetBrightness != nil)")
    }
    
    // MARK: - CGEventTap (intercepts media keys to suppress OSD)
    private var accessibilityRetryTimer: Timer?
    
    private func setupEventTap() {
        // Check and request accessibility permissions
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if !trusted {
            print("[SystemStatus] ⚠️ Accessibility not granted — prompting user. Will retry...")
            // Retry every 3 seconds until permissions are granted
            accessibilityRetryTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.accessibilityRetryTimer = nil
                    print("[SystemStatus] ✅ Accessibility granted! Creating event tap...")
                    self?.createEventTap()
                }
            }
            return
        }
        
        createEventTap()
    }
    
    private func createEventTap() {
        // NX_SYSDEFINED = 14 (system-defined events including media keys)
        let eventMask: CGEventMask = (1 << 14)
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: mediaKeyCallback,
            userInfo: refcon
        ) else {
            print("[SystemStatus] ❌ Failed to create event tap even with accessibility granted")
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[SystemStatus] ✅ Event tap active — OSD will be suppressed")
    }
    
    // MARK: - Polling (fallback / brightness sync)
    private func pollForChanges() {
        fetchVolume()
        fetchBrightness()
        
        // Only trigger indicator from polling if event tap is NOT active
        if eventTap == nil {
            if abs(volume - previousVolume) > 0.005 {
                triggerIndicator(.volume)
            }
            if abs(brightness - previousBrightness) > 0.005 {
                triggerIndicator(.brightness)
            }
        }
        
        previousVolume = volume
        previousBrightness = brightness
    }
    
    // MARK: - Volume
    func fetchVolume() {
        let script = "output volume of (get volume settings)"
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            if let vol = result.stringValue, let intVol = Double(vol) {
                self.volume = intVol / 100.0
            }
        }
    }
    
    func adjustVolume(up: Bool) {
        let step = 1.0 / 16.0 // macOS standard step (6.25%)
        let newVolume = max(0, min(1, volume + (up ? step : -step)))
        setVolume(newVolume)
        triggerIndicator(.volume)
    }
    
    func setVolume(_ newVolume: Double) {
        let volumeInt = Int(newVolume * 100)
        let script = "set volume output volume \(volumeInt)"
        DispatchQueue.global(qos: .userInitiated).async {
            NSAppleScript(source: script)?.executeAndReturnError(nil)
        }
        self.volume = newVolume
    }
    
    func toggleMute() {
        if volume > 0.01 {
            setVolume(0)
        } else {
            setVolume(0.5)
        }
        triggerIndicator(.volume)
    }
    
    // MARK: - Brightness
    func fetchBrightness() {
        // Method 1: DisplayServices (most reliable on Apple Silicon)
        if let dsGetBrightness = dsGetBrightness {
            var val: Float = 0
            let result = dsGetBrightness(CGMainDisplayID(), &val)
            if result == 0 {
                self.brightness = Double(val)
                return
            }
        }
        
        // Method 2: IOKit iterator
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator)
        if result == kIOReturnSuccess {
            var service = IOIteratorNext(iterator)
            while service != 0 {
                var val: Float = 0
                let kr = IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &val)
                if kr == kIOReturnSuccess {
                    self.brightness = Double(val)
                    IOObjectRelease(service)
                    IOObjectRelease(iterator)
                    return
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
        }
    }
    
    func adjustBrightness(up: Bool) {
        fetchBrightness() // sync current value first
        let step = 1.0 / 16.0
        let newBrightness = max(0, min(1, brightness + (up ? step : -step)))
        setBrightness(newBrightness)
        triggerIndicator(.brightness)
    }
    
    func setBrightness(_ value: Double) {
        brightness = value
        // Method 1: DisplayServices
        if let dsSetBrightness = dsSetBrightness {
            _ = dsSetBrightness(CGMainDisplayID(), Float(value))
            return
        }
        // Method 2: IOKit
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator)
        if result == kIOReturnSuccess {
            var service = IOIteratorNext(iterator)
            while service != 0 {
                IODisplaySetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, Float(value))
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
        }
    }
    
    // MARK: - Indicator
    func triggerIndicator(_ type: IndicatorType) {
        DispatchQueue.main.async {
            self.showingIndicator = type
        }
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.showingIndicator = nil
            }
        }
    }
}

// MARK: - CGEvent Tap Callback (C-convention global function)
private func mediaKeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passRetained(event) }
    let service = Unmanaged<SystemStatusService>.fromOpaque(refcon).takeUnretainedValue()
    
    // Re-enable tap if it was disabled by timeout
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = service.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passRetained(event)
    }
    
    // Only process system-defined events (NX_SYSDEFINED = 14)
    guard type.rawValue == 14 else {
        return Unmanaged.passRetained(event)
    }
    
    // Parse via NSEvent for reliable data1 access
    guard let nsEvent = NSEvent(cgEvent: event) else {
        return Unmanaged.passRetained(event)
    }
    
    // NX_SUBTYPE_AUX_CONTROL_BUTTONS = 8
    guard nsEvent.subtype.rawValue == 8 else {
        return Unmanaged.passRetained(event)
    }
    
    let data1 = nsEvent.data1
    let keyCode = (data1 & 0xFFFF0000) >> 16
    let keyFlags = data1 & 0x0000FFFF
    let keyState = (keyFlags & 0xFF00) >> 8
    let isKeyDown = keyState == 0x0A
    
    // Consume both key-down and key-up for media keys to fully suppress OSD
    switch keyCode {
    case 0: // NX_KEYTYPE_SOUND_UP
        if isKeyDown { DispatchQueue.main.async { service.adjustVolume(up: true) } }
        return nil
    case 1: // NX_KEYTYPE_SOUND_DOWN
        if isKeyDown { DispatchQueue.main.async { service.adjustVolume(up: false) } }
        return nil
    case 2: // NX_KEYTYPE_BRIGHTNESS_UP
        if isKeyDown { DispatchQueue.main.async { service.adjustBrightness(up: true) } }
        return nil
    case 3: // NX_KEYTYPE_BRIGHTNESS_DOWN
        if isKeyDown { DispatchQueue.main.async { service.adjustBrightness(up: false) } }
        return nil
    case 7: // NX_KEYTYPE_MUTE
        if isKeyDown { DispatchQueue.main.async { service.toggleMute() } }
        return nil
    default:
        return Unmanaged.passRetained(event)
    }
}
