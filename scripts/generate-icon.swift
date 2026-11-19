import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let green = CGColor(red: 0.09, green: 0.28, blue: 0.21, alpha: 1)
let cream = CGColor(red: 0.97, green: 0.96, blue: 0.93, alpha: 1)
context.setFillColor(green)
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
func rounded(_ rect: CGRect, radius: CGFloat, color: CGColor) {
    context.setFillColor(color)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.fillPath()
}
rounded(CGRect(x: 222, y: 193, width: 580, height: 580), radius: 130,
        color: CGColor(red: 0.23, green: 0.40, blue: 0.32, alpha: 1))
rounded(CGRect(x: 222, y: 263, width: 580, height: 580), radius: 130, color: cream)
let pin = CGMutablePath()
pin.move(to: CGPoint(x: 512, y: 380))
pin.addCurve(to: CGPoint(x: 365, y: 613), control1: CGPoint(x: 468, y: 450), control2: CGPoint(x: 365, y: 519))
pin.addCurve(to: CGPoint(x: 659, y: 613), control1: CGPoint(x: 365, y: 804), control2: CGPoint(x: 659, y: 804))
pin.addCurve(to: CGPoint(x: 512, y: 380), control1: CGPoint(x: 659, y: 519), control2: CGPoint(x: 556, y: 450))
pin.closeSubpath()
context.setFillColor(green)
context.addPath(pin)
context.fillPath()
context.setFillColor(cream)
context.fillEllipse(in: CGRect(x: 464, y: 572, width: 96, height: 96))
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write app icon") }
