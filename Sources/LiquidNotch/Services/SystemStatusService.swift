import Foundation
import Cocoa
import Combine

class SystemStatusService: ObservableObject {
    @Published var volume: Double = 0.5
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        fetchVolume()
        // Poll volume occasionally
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchVolume()
            }
            .store(in: &cancellables)
    }
    
    func fetchVolume() {
        let script = "output volume of (get volume settings)"
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            if let vol = result.stringValue, let intVol = Double(vol) {
                DispatchQueue.main.async {
                    self.volume = intVol / 100.0
                }
            }
        }
    }
    
    func setVolume(_ newVolume: Double) {
        let volumeInt = Int(newVolume * 100)
        let script = "set volume output volume \(volumeInt)"
        DispatchQueue.global(qos: .userInitiated).async {
            NSAppleScript(source: script)?.executeAndReturnError(nil)
        }
        self.volume = newVolume
    }
}
