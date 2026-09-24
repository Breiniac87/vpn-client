import SwiftUI

public struct PingGraphView: View {
    let pingHistory: [Int] // Ping values in milliseconds (e.g. [45, 48, 52, 46, 55, 49])
    let currentPing: Int?
    
    public init(pingHistory: [Int], currentPing: Int?) {
        self.pingHistory = pingHistory
        self.currentPing = currentPing
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label {
                    Text("Задержка")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 11))
                        .foregroundStyle(pingColor)
                }
                
                Spacer()
                
                if let ping = currentPing {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(pingColor)
                            .frame(width: 6, height: 6)
                        Text("\(ping) ms")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(pingColor)
                    }
                } else {
                    Text("— ms")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            
            // Sparkline Curve
            GeometryReader { geo in
                ZStack {
                    if pingHistory.count > 1 {
                        // Area gradient
                        SparklineShape(dataPoints: normalizedPoints, isClosed: true)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        pingColor.opacity(0.25),
                                        pingColor.opacity(0.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        // Line stroke
                        SparklineShape(dataPoints: normalizedPoints, isClosed: false)
                            .stroke(
                                pingColor,
                                style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                            )
                    } else {
                        // Flat placeholder line
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                            path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                        }
                        .stroke(
                            Color.secondary.opacity(0.2),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                    }
                }
            }
            .frame(height: 36)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }
    
    private var pingColor: Color {
        guard let ping = currentPing else { return .secondary }
        if ping < 80 {
            return ModernMacTheme.neonGreen
        } else if ping < 160 {
            return Color.orange
        } else {
            return ModernMacTheme.redDanger
        }
    }
    
    private var normalizedPoints: [CGFloat] {
        guard !pingHistory.isEmpty else { return [] }
        let maxVal = max(pingHistory.max() ?? 100, 100)
        let minVal = max(0, (pingHistory.min() ?? 0) - 10)
        let range = max(1, maxVal - minVal)
        
        return pingHistory.map { CGFloat($0 - minVal) / CGFloat(range) }
    }
}

// Sparkline shape helper
struct SparklineShape: Shape {
    let dataPoints: [CGFloat]
    let isClosed: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard dataPoints.count > 1 else { return path }
        
        let stepX = rect.width / CGFloat(dataPoints.count - 1)
        
        let points = dataPoints.enumerated().map { idx, val in
            CGPoint(
                x: CGFloat(idx) * stepX,
                y: rect.height - (val * (rect.height - 4)) - 2
            )
        }
        
        path.move(to: points[0])
        for idx in 1..<points.count {
            let prev = points[idx - 1]
            let curr = points[idx]
            let mid = CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2)
            path.addQuadCurve(to: mid, control: prev)
            path.addLine(to: curr)
        }
        
        if isClosed {
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }
        
        return path
    }
}
