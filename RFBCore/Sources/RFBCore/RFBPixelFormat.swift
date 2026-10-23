import Foundation

/// 16-byte RFB Pixel Format structure (RFC 6143 Section 7.4).
public struct RFBPixelFormat: Equatable, CustomStringConvertible {
    public var bitsPerPixel: UInt8
    public var depth: UInt8
    public var bigEndianFlag: UInt8
    public var trueColourFlag: UInt8
    public var redMax: UInt16
    public var greenMax: UInt16
    public var blueMax: UInt16
    public var redShift: UInt8
    public var greenShift: UInt8
    public var blueShift: UInt8
    public var padding: (UInt8, UInt8, UInt8)

    public init(
        bitsPerPixel: UInt8 = 32,
        depth: UInt8 = 24,
        bigEndianFlag: UInt8 = 0,
        trueColourFlag: UInt8 = 1,
        redMax: UInt16 = 255,
        greenMax: UInt16 = 255,
        blueMax: UInt16 = 255,
        redShift: UInt8 = 16,
        greenShift: UInt8 = 8,
        blueShift: UInt8 = 0
    ) {
        self.bitsPerPixel = bitsPerPixel
        self.depth = depth
        self.bigEndianFlag = bigEndianFlag
        self.trueColourFlag = trueColourFlag
        self.redMax = redMax
        self.greenMax = greenMax
        self.blueMax = blueMax
        self.redShift = redShift
        self.greenShift = greenShift
        self.blueShift = blueShift
        self.padding = (0, 0, 0)
    }

    /// Standard 32-bit BGRA / RGBA true colour format for efficient CoreGraphics display.
    public static let standard32 = RFBPixelFormat(
        bitsPerPixel: 32,
        depth: 24,
        bigEndianFlag: 0,
        trueColourFlag: 1,
        redMax: 255,
        greenMax: 255,
        blueMax: 255,
        redShift: 16,
        greenShift: 8,
        blueShift: 0
    )

    public var bytesPerPixel: Int {
        return Int((bitsPerPixel + 7) / 8)
    }

    public var wireData: Data {
        var data = Data()
        data.append(bitsPerPixel)
        data.append(depth)
        data.append(bigEndianFlag)
        data.append(trueColourFlag)
        
        var rMax = redMax.bigEndian
        var gMax = greenMax.bigEndian
        var bMax = blueMax.bigEndian
        data.append(Data(bytes: &rMax, count: 2))
        data.append(Data(bytes: &gMax, count: 2))
        data.append(Data(bytes: &bMax, count: 2))
        
        data.append(redShift)
        data.append(greenShift)
        data.append(blueShift)
        data.append(padding.0)
        data.append(padding.1)
        data.append(padding.2)
        return data
    }

    public static func parse(from data: Data) -> RFBPixelFormat? {
        guard data.count >= 16 else { return nil }
        let bpp = data[0]
        let depth = data[1]
        let be = data[2]
        let tc = data[3]
        
        let rMax = UInt16(data[4]) << 8 | UInt16(data[5])
        let gMax = UInt16(data[6]) << 8 | UInt16(data[7])
        let bMax = UInt16(data[8]) << 8 | UInt16(data[9])
        
        let rShift = data[10]
        let gShift = data[11]
        let bShift = data[12]
        
        var format = RFBPixelFormat(
            bitsPerPixel: bpp,
            depth: depth,
            bigEndianFlag: be,
            trueColourFlag: tc,
            redMax: rMax,
            greenMax: gMax,
            blueMax: bMax,
            redShift: rShift,
            greenShift: gShift,
            blueShift: bShift
        )
        format.padding = (data[13], data[14], data[15])
        return format
    }

    public var description: String {
        return "PixelFormat(bpp: \(bitsPerPixel), depth: \(depth), trueColour: \(trueColourFlag == 1), rMax: \(redMax), gMax: \(greenMax), bMax: \(blueMax))"
    }

    public static func == (lhs: RFBPixelFormat, rhs: RFBPixelFormat) -> Bool {
        return lhs.bitsPerPixel == rhs.bitsPerPixel &&
               lhs.depth == rhs.depth &&
               lhs.bigEndianFlag == rhs.bigEndianFlag &&
               lhs.trueColourFlag == rhs.trueColourFlag &&
               lhs.redMax == rhs.redMax &&
               lhs.greenMax == rhs.greenMax &&
               lhs.blueMax == rhs.blueMax &&
               lhs.redShift == rhs.redShift &&
               lhs.greenShift == rhs.greenShift &&
               lhs.blueShift == rhs.blueShift
    }
}
