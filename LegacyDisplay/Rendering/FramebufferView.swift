import UIKit
import CoreGraphics

/// High-performance CoreGraphics framebuffer view for rendering remote desktop bitmap.
public final class FramebufferView: UIView {

    public private(set) var desktopWidth: Int = 0
    public private(set) var desktopHeight: Int = 0

    private var rawBuffer: [UInt8] = []
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private let renderQueue = DispatchQueue(label: "com.legacydisplay.render", qos: .userInteractive)

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .black
        contentMode = .scaleAspectFit
        isOpaque = true
        clearsContextBeforeDrawing = false
    }

    /// Reconfigures framebuffer dimensions.
    public func updateDesktopDimensions(width: Int, height: Int) {
        self.desktopWidth = width
        self.desktopHeight = height
        let bytesNeeded = width * height * 4
        self.rawBuffer = [UInt8](repeating: 0, count: bytesNeeded)
        setNeedsDisplay()
    }

    /// Ingests a new slice of the framebuffer and schedules redraw.
    public func updateBuffer(from source: [UInt8], dirtyRect: CGRect? = nil) {
        guard !source.isEmpty else { return }
        if rawBuffer.count != source.count {
            rawBuffer = source
        } else {
            rawBuffer.withUnsafeMutableBufferPointer { dstPtr in
                source.withUnsafeBufferPointer { srcPtr in
                    guard let dst = dstPtr.baseAddress, let src = srcPtr.baseAddress else { return }
                    memcpy(dst, src, source.count)
                }
            }
        }

        if let rect = dirtyRect {
            // Map framebuffer dirty rect to view bounds
            let viewRect = convertFramebufferRectToView(rect)
            setNeedsDisplay(viewRect)
        } else {
            setNeedsDisplay()
        }
    }

    public override func draw(_ rect: CGRect) {
        guard desktopWidth > 0, desktopHeight > 0, !rawBuffer.isEmpty,
              let context = UIGraphicsGetCurrentContext() else {
            return
        }

        let bitmapInfo: CGBitmapInfo = [
            .byteOrder32Little,
            CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
        ]

        rawBuffer.withUnsafeBytes { rawPtr in
            guard let baseAddress = rawPtr.baseAddress else { return }
            guard let dataProvider = CGDataProvider(dataInfo: nil, data: baseAddress, size: rawBuffer.count, releaseData: { _, _, _ in }) else {
                return
            }

            guard let cgImage = CGImage(
                width: desktopWidth,
                height: desktopHeight,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: desktopWidth * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: dataProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            ) else {
                return
            }

            // Draw full image scaled into aspect-fit bounds
            let drawRect = calculateAspectFitRect(for: bounds, contentWidth: CGFloat(desktopWidth), contentHeight: CGFloat(desktopHeight))
            
            // Flip context because CGContext is bottom-left origin
            context.saveGState()
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1.0, y: -1.0)
            
            let flippedDrawRect = CGRect(x: drawRect.origin.x, y: bounds.height - drawRect.origin.y - drawRect.height, width: drawRect.width, height: drawRect.height)
            context.draw(cgImage, in: flippedDrawRect)
            context.restoreGState()
        }
    }

    // MARK: - Coordinate Transformations

    public func calculateAspectFitRect(for container: CGRect, contentWidth: CGFloat, contentHeight: CGFloat) -> CGRect {
        guard contentWidth > 0, contentHeight > 0 else { return container }
        let scale = min(container.width / contentWidth, container.height / contentHeight)
        let w = contentWidth * scale
        let h = contentHeight * scale
        let x = container.origin.x + (container.width - w) / 2.0
        let y = container.origin.y + (container.height - h) / 2.0
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Converts a point from view coordinates to remote framebuffer pixel coordinates.
    public func convertPointToFramebuffer(_ point: CGPoint) -> CGPoint? {
        guard desktopWidth > 0, desktopHeight > 0 else { return nil }
        let fitRect = calculateAspectFitRect(for: bounds, contentWidth: CGFloat(desktopWidth), contentHeight: CGFloat(desktopHeight))
        
        guard fitRect.contains(point) else { return nil }
        
        let normalizedX = (point.x - fitRect.origin.x) / fitRect.width
        let normalizedY = (point.y - fitRect.origin.y) / fitRect.height
        
        let fbX = normalizedX * CGFloat(desktopWidth)
        let fbY = normalizedY * CGFloat(desktopHeight)
        
        let clampedX = max(0, min(CGFloat(desktopWidth - 1), fbX))
        let clampedY = max(0, min(CGFloat(desktopHeight - 1), fbY))
        return CGPoint(x: clampedX, y: clampedY)
    }

    private func convertFramebufferRectToView(_ fbRect: CGRect) -> CGRect {
        guard desktopWidth > 0, desktopHeight > 0 else { return bounds }
        let fitRect = calculateAspectFitRect(for: bounds, contentWidth: CGFloat(desktopWidth), contentHeight: CGFloat(desktopHeight))
        
        let scaleX = fitRect.width / CGFloat(desktopWidth)
        let scaleY = fitRect.height / CGFloat(desktopHeight)
        
        let x = fitRect.origin.x + fbRect.origin.x * scaleX
        let y = fitRect.origin.y + fbRect.origin.y * scaleY
        let w = fbRect.width * scaleX
        let h = fbRect.height * scaleY
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
