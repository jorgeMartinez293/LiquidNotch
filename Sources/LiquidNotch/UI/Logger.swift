import Foundation

struct Logger {
    static func log(_ message: String) {
        let logMessage = "\(Date()): \(message)\n"
        print(logMessage) // Keep stdout
        
        let fileURL = URL(fileURLWithPath: "/tmp/notch_debug.log")
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write(logMessage.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? logMessage.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
}
