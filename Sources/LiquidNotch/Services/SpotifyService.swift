import Foundation
import Cocoa

struct TrackInfo {
    let title: String
    let artist: String
    let artworkUrl: String?
    let duration: Double // milliseconds
}

class SpotifyService: ObservableObject {
    @Published var currentTrack: TrackInfo?
    @Published var isPlaying: Bool = false
    @Published var playerPosition: Double = 0 // seconds
    
    private var timer: Timer?
    
    init() {
        startPolling()
    }
    
    func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.fetchSpotifyData()
        }
    }
    
    private func fetchSpotifyData() {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify"
                set cTrack to current track
                set tName to name of cTrack
                set tArtist to artist of cTrack
                set tArtwork to artwork url of cTrack
                set tDuration to duration of cTrack
                set pState to player state
                set pPos to player position
                return {tName, tArtist, tArtwork, pState, tDuration, pPos}
            end tell
        else
            return "stopped"
        end if
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            
            // Note: AppleScript return value is implicitly a descriptor.
            // Check if it's a list (AEDescList)
            print("Spotify AppleScript Result: \(result)") 
            
            if result.descriptorType == typeAEList {
                // Parse the list: [Name, Artist, Artwork, State, Duration, Position]
                if result.numberOfItems >= 6 {
                    let title = result.atIndex(1)?.stringValue ?? ""
                    let artist = result.atIndex(2)?.stringValue ?? ""
                    let artwork = result.atIndex(3)?.stringValue
                    let state = result.atIndex(4)?.stringValue // "playing", "paused", "stopped"
                    let duration = result.atIndex(5)?.doubleValue ?? 0 // ms
                    let position = result.atIndex(6)?.doubleValue ?? 0 // seconds
                    
                    print("Parsed: Title=\(title), State=\(String(describing: state))")
                    
                    DispatchQueue.main.async {
                        self.currentTrack = TrackInfo(title: title, artist: artist, artworkUrl: artwork, duration: duration)
                        self.isPlaying = (state == "kPSP") // Spotify often returns this constant code
                        if state == "playing" { self.isPlaying = true }
                        self.playerPosition = position
                    }
                }
            } else if result.stringValue == "stopped" {
                DispatchQueue.main.async {
                    self.isPlaying = false
                }
            }
        }
    }
    
    func togglePlayPause() {
        let script = "tell application \"Spotify\" to playpause"
        NSAppleScript(source: script)?.executeAndReturnError(nil)
        fetchSpotifyData() // Immediate update
    }
    
    func nextTrack() {
        let script = "tell application \"Spotify\" to next track"
        NSAppleScript(source: script)?.executeAndReturnError(nil)
        fetchSpotifyData()
    }
    
    func previousTrack() {
        let script = "tell application \"Spotify\" to previous track"
        NSAppleScript(source: script)?.executeAndReturnError(nil)
        fetchSpotifyData()
    }
}
