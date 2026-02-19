import SwiftUI
import Combine

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            // LEFT SIDE: Album Art (Visible when Playing + Idle, or Expanded)
            if viewModel.shouldShowMusicInfo {
                AsyncImage(url: URL(string: viewModel.artworkUrl ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.gray
                }
                .frame(width: 22, height: 22)
                .cornerRadius(6)
                .padding(.leading, 6)
                .padding(.trailing, 6)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            
            // CENTER: Notch Area
            ZStack(alignment: .top) {
                // Background
                NotchShape(cornerRadius: 20)
                    .fill(Color.black)
                    // Frame removed, fills container
                    .overlay(
                        NotchShape(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(radius: 10) // Shadow for depth
                
                // Expanded Content
                // Expanded Content
                // Expanded Content
                if viewModel.isTargeted {
                    // Central Drop Area
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5]))
                            )
                        
                        VStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                            Text("Drop File Here")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 40)
                    .padding(.bottom, 30) // Increased bottom margin
                    .transition(.opacity) // Fade in/out
                } else if viewModel.isHovered {
                    VStack {
                        Spacer().frame(height: 12)
                        
                        HStack {
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 20)
                        
                        Spacer().frame(height: 12)
                        
                        if let droppedFile = viewModel.droppedFile {
                            // Dropped File Preview - Draggable (Move)
                            DraggableFileView(fileURL: droppedFile, onDragEnded: { operation in
                                if operation == .move {
                                    DispatchQueue.main.async {
                                        withAnimation {
                                            viewModel.droppedFile = nil
                                        }
                                    }
                                }
                            }) {
                                HStack(alignment: .center, spacing: 16) {
                                    // File Icon / Preview
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: droppedFile.path))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 60, height: 60)
                                    
                                    VStack(alignment: .leading) {
                                        Text(droppedFile.lastPathComponent)
                                            .foregroundColor(.white)
                                            .font(.headline)
                                        Text(droppedFile.path)
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: { 
                                        withAnimation {
                                            viewModel.droppedFile = nil 
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 40)
                                .padding(.bottom, 20)
                                .contentShape(Rectangle())
                            }
                            .transition(.opacity)
                        } else if let track = viewModel.currentTrack {
                            HStack(alignment: .center, spacing: 16) {
                                // Left: Album Art
                                AsyncImage(url: URL(string: track.artworkUrl ?? "")) { image in
                                    image.resizable().aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
                                .frame(width: 100, height: 100)
                                .cornerRadius(8)
                                .shadow(radius: 4)
                                
                                // Center: Info + Controls + Progress
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(track.title).bold().foregroundColor(.white).lineLimit(1)
                                    Text(track.artist).font(.caption).foregroundColor(.gray).lineLimit(1)
                                    
                                    // Controls
                                    HStack(spacing: 20) {
                                        Button(action: viewModel.previousTrack) {
                                            Image(systemName: "backward.fill")
                                                .padding(6)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        Button(action: viewModel.togglePlayPause) {
                                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                                .padding(10) // Slightly larger for play button
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        Button(action: viewModel.nextTrack) {
                                            Image(systemName: "forward.fill")
                                                .padding(6)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .frame(maxWidth: .infinity) // Center the controls horizontally
                                    .foregroundColor(.white)
                                    .font(.title)
                                    
                                    // Progress Bar
                                    let durationSec = track.duration / 1000
                                    let progress = durationSec > 0 ? (viewModel.playerPosition / durationSec) : 0
                                    
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.gray.opacity(0.3)).frame(height: 4)
                                            Capsule().fill(viewModel.albumColor).frame(width: geo.size.width * CGFloat(progress), height: 4)
                                        }
                                    }
                                    .frame(height: 4)
                                    .padding(.top, 4)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Right: Visualizer (Inside Menu)
                                VisualizerView(color: viewModel.albumColor)
                                    .frame(height: 30)
                            }
                            .padding(.horizontal, 40)
                            .padding(.bottom, 20)
                            .transition(.opacity)
                        } else {
                            Text("No Music Playing").foregroundColor(.gray)
                                .padding(.vertical, 20)
                        }
                    }
                    .transition(.opacity)

                }
            }
            .zIndex(10)
            
            // RIGHT SIDE: Visualizer (COMPACT MODE ONLY)
            if viewModel.shouldShowMusicInfo {
                VStack {
                   Spacer()
                   VisualizerView(color: viewModel.albumColor)
                   Spacer()
                }
                .frame(height: 24)
                .padding(.leading, 6)
                .padding(.trailing, 6)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            // Removed DropView to use DragContainerView in AppDelegate
            EmptyView()
        )
        .onHover { hovering in
            // Direct set, no swiftui animation for frame
            viewModel.setHover(hovering)
        }
    }
}

struct VisualizerView: View {
    var color: Color
    @State private var barHeights: [CGFloat] = Array(repeating: 10, count: 4)
    // Slower timer: 0.2s
    let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 3, height: barHeights[index])
            }
        }
        .frame(height: 24) // Stabilize height to prevent layout jitter
        .onReceive(timer) { _ in
            // Slower animation: 0.3s
            withAnimation(.easeInOut(duration: 0.3)) {
                for i in 0..<4 {
                    // Generate fluid random heights
                    barHeights[i] = CGFloat.random(in: 8...24)
                }
            }
        }
    }
}

struct NotchShape: Shape {
    var cornerRadius: CGFloat
    // Add a smaller or equal radius for the top to "soften" the connection
    // The user asked for a curve "arriving" at the top.
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topRadius: CGFloat = 16 // Curve "outwards" to the top edge (Concave)
        
        // --- Top Left (Concave) ---
        // Start at Top Edge (minX)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        
        // Arc down-and-right to the vertical side (minX + topRadius)
        // Center is at (minX, minY + topRadius)
        // Start Angle: 270 (Top) -> End Angle: 0/360 (Right)
        // To curve "inwards" into the rect from the edge, we use center at (0, r).
        // Angle 270 is (0, 0). Angle 0 is (r, r).
        // This creates a defined "scoop".
        path.addArc(center: CGPoint(x: rect.minX, y: rect.minY + topRadius),
                    radius: topRadius,
                    startAngle: Angle(degrees: 270),
                    endAngle: Angle(degrees: 0),
                    clockwise: false) // SwiftUI Path: clockwise means visually clockwise (increasing angle check needed)
                    // Actually, let's trace points.
                    // Center (0, 16). Radius 16.
                    // 270 deg: (0, 0).
                    // 0 deg: (16, 16).
                    // We want 270 -> 360.
        
        // --- Bottom Left (Rounded) ---
        // Line down to start of bottom-left corner
        path.addLine(to: CGPoint(x: rect.minX + topRadius, y: rect.maxY - cornerRadius))
        
        // Standard rounded corner
        path.addArc(center: CGPoint(x: rect.minX + topRadius + cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: 180),
                    endAngle: Angle(degrees: 90),
                    clockwise: true) // 180 -> 90 is counter-clockwise mathematically, but Y-down?
                    // Let's use simple logic:
                    // Center (r+tr, h-r).
                    // Start (tr, h-r) -> 180.
                    // End (tr+r, h) -> 90.
                    // 180 -> 90. Decreasing.
                    
        // --- Bottom Right (Rounded) ---
        path.addLine(to: CGPoint(x: rect.maxX - topRadius - cornerRadius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.maxX - topRadius - cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: 90),
                    endAngle: Angle(degrees: 0),
                    clockwise: true) // 90 -> 0. Decreasing.
                    
        // --- Top Right (Concave) ---
        // Line up to start of top-right arc
        path.addLine(to: CGPoint(x: rect.maxX - topRadius, y: rect.minY + topRadius))
        
        // Arc up-and-right to the top edge (maxX)
        // Center is at (maxX, minY + topRadius)
        // Start Angle: 180 (Left) -> (maxX-r, r)
        // End Angle: 270 (Top) -> (maxX, 0)
        path.addArc(center: CGPoint(x: rect.maxX, y: rect.minY + topRadius),
                    radius: topRadius,
                    startAngle: Angle(degrees: 180),
                    endAngle: Angle(degrees: 270),
                    clockwise: false) // 180 -> 270. Increasing.
        
        // Close Top
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        
        path.closeSubpath()
        return path
    }
}
