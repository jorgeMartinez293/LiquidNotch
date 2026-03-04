import SwiftUI
import Combine

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    // Physical notch width on MacBook M4 (~180pt)
    private let physicalNotchWidth: CGFloat = 180
    
    var body: some View {
        HStack(spacing: 0) {
            // LEFT SIDE: Album Art (Visible when Playing + Idle + No Indicator)
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
                
                // INDICATOR OVERLAY (Volume / Brightness)
                // Positioned in the WINGS — icon on the left wing, bar on the right wing
                // The physical notch (~180pt) is centered and blocks the middle
                ZStack {
                    if viewModel.shouldShowIndicator {
                        HStack(spacing: 0) {
                            // LEFT WING: Icon
                            Image(systemName: viewModel.indicatorIconName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(width: 65)
                            
                            Spacer()
                        }
                        .padding(.top, 0)
                        .padding(.leading, 4)
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                    }
                    
                    if viewModel.shouldShowIndicator {
                        HStack(spacing: 0) {
                            Spacer()
                            
                            // RIGHT WING: Progress bar
                            HStack(spacing: 0) {
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 33, height: 4)
                                    
                                    Capsule()
                                        .fill(Color.white)
                                        .frame(width: max(0, 33 * CGFloat(viewModel.indicatorLevel)), height: 4)
                                }
                                .padding(.leading, 2)
                                .padding(.trailing, 30)
                            }
                            .frame(width: 65)
                        }
                        .padding(.top, 0)
                        .transition(.identity) // Insta-hide without any animations
                    }
                }
                
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
                    .padding(.bottom, 30)
                    .transition(.opacity)
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
                                AsyncImage(url: URL(string: track.artworkUrl ?? "")) { image in
                                    image.resizable().aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
                                .frame(width: 100, height: 100)
                                .cornerRadius(8)
                                .shadow(radius: 4)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(track.title).bold().foregroundColor(.white).lineLimit(1)
                                    Text(track.artist).font(.caption).foregroundColor(.gray).lineLimit(1)
                                    
                                    HStack(spacing: 20) {
                                        Button(action: viewModel.previousTrack) {
                                            Image(systemName: "backward.fill")
                                                .padding(6)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        Button(action: viewModel.togglePlayPause) {
                                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                                .padding(10)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        Button(action: viewModel.nextTrack) {
                                            Image(systemName: "forward.fill")
                                                .padding(6)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(.white)
                                    .font(.title)
                                    
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
                                
                            VisualizerView(color: viewModel.albumColor, isMoving: viewModel.isPlaying)
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
        
        // RIGHT SIDE: Visualizer (COMPACT MODE ONLY — hidden when indicator is active)
        if viewModel.shouldShowMusicInfo {
            VStack {
               Spacer()
               VisualizerView(color: viewModel.albumColor, isMoving: viewModel.isPlaying)
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
        EmptyView()
    )
    .onHover { hovering in
        viewModel.setHover(hovering)
    }
}
}

struct VisualizerView: View {
var color: Color
var isMoving: Bool

var body: some View {
    TimelineView(.periodic(from: .now, by: 0.15)) { context in
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                // If moving, pick a random-ish height based on the timeline context to stay somewhat stable
                let height = isMoving ? 
                    CGFloat(8 + (abs(context.date.timeIntervalSince1970.remainder(dividingBy: Double(index + 1) * 0.5)) * 40)) : 10
                
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 3, height: min(24, max(8, height)))
                    .animation(.easeInOut(duration: 0.15), value: context.date)
            }
        }
    }
    .frame(height: 24)
}
}

struct NotchShape: Shape {
    var cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topRadius: CGFloat = 16
        
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.minX, y: rect.minY + topRadius),
                    radius: topRadius,
                    startAngle: Angle(degrees: 270),
                    endAngle: Angle(degrees: 0),
                    clockwise: false)
        
        path.addLine(to: CGPoint(x: rect.minX + topRadius, y: rect.maxY - cornerRadius))
        path.addArc(center: CGPoint(x: rect.minX + topRadius + cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: 180),
                    endAngle: Angle(degrees: 90),
                    clockwise: true)
                    
        path.addLine(to: CGPoint(x: rect.maxX - topRadius - cornerRadius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.maxX - topRadius - cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: 90),
                    endAngle: Angle(degrees: 0),
                    clockwise: true)
                    
        path.addLine(to: CGPoint(x: rect.maxX - topRadius, y: rect.minY + topRadius))
        path.addArc(center: CGPoint(x: rect.maxX, y: rect.minY + topRadius),
                    radius: topRadius,
                    startAngle: Angle(degrees: 180),
                    endAngle: Angle(degrees: 270),
                    clockwise: false)
        
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        
        path.closeSubpath()
        return path
    }
}
