import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
import BrainstormCore

struct DemoCredentials: CredentialStore {
    func credential(for provider: ProviderID) async throws -> ProviderCredential { .apiKey("demo-no-network") }
}

actor DemoProvider: ImageProvider {
    private var sequence = 0
    func generate(prompt: String, references: [ImageReference], settings: GenerationSettings, credential: ProviderCredential) async throws -> ImageOutput {
        let index = sequence; sequence += 1
        try await Task.sleep(for: .milliseconds(500 + (index % 3) * 350))
        return ImageOutput(data: try DemoArtwork.image(index: index, refinement: !references.isEmpty))
    }
    func refinePrompt(_ prompt: String, direction: String, references: [ImageReference], credential: ProviderCredential) async throws -> String {
        try await Task.sleep(for: .milliseconds(600))
        return "Create a minimal coastal travel poster with warm ivory paper, a terracotta sun, deep green shapes, and generous negative space. Use the exact heading ‘A slower kind of summer’. Explore a calm, geometric composition.\n\nAdditional direction: \(direction)"
    }
}

enum DemoArtwork {
    static func image(index: Int, refinement: Bool = false) throws -> Data {
        let size = 900
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw BrainstormError.storage("Cannot draw demo image.")
        }
        let palettes: [(CGColor, CGColor, CGColor)] = [
            (color(0.94,0.90,0.81),color(0.78,0.31,0.18),color(0.16,0.32,0.27)),
            (color(0.16,0.28,0.25),color(0.94,0.70,0.36),color(0.91,0.87,0.75)),
            (color(0.91,0.78,0.64),color(0.68,0.24,0.15),color(0.21,0.37,0.32)),
            (color(0.93,0.92,0.85),color(0.90,0.56,0.27),color(0.25,0.41,0.48))
        ]
        let palette = palettes[index % palettes.count]
        context.setFillColor(palette.0); context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        context.setFillColor(palette.1)
        let radius = refinement ? 170.0 : 130.0 + Double(index % 3) * 35
        context.fillEllipse(in: CGRect(x: 450 - radius + Double(index % 2) * 75, y: 390, width: radius * 2, height: radius * 2))
        context.setFillColor(palette.2)
        for layer in 0..<3 {
            let path = CGMutablePath()
            let offset = Double(layer) * 65
            path.move(to: CGPoint(x: 70, y: 150 + offset))
            path.addCurve(to: CGPoint(x: 830, y: 250 + offset), control1: CGPoint(x: 280, y: 500 + offset - Double(index % 3) * 70), control2: CGPoint(x: 570, y: 40 + offset))
            path.addLine(to: CGPoint(x: 830, y: 115 + offset))
            path.addCurve(to: CGPoint(x: 70, y: 110 + offset), control1: CGPoint(x: 580, y: 0 + offset), control2: CGPoint(x: 260, y: 400 + offset))
            path.closeSubpath(); context.addPath(path); context.fillPath()
        }
        context.setStrokeColor(palette.2); context.setLineWidth(1.3)
        context.stroke(CGRect(x: 40, y: 40, width: 820, height: 820))
        drawText("A SLOWER KIND", x: 77, y: 780, size: 30, color: palette.2, context: context)
        drawText("of summer.", x: 72, y: 693, size: 80, color: palette.2, context: context, serif: true)
        drawText("COASTAL STUDIES    /    \(String(format: "%02d", index + 1))", x: 77, y: 72, size: 18, color: palette.2, context: context)
        guard let image = context.makeImage() else { throw BrainstormError.storage("Cannot draw demo image.") }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { throw BrainstormError.storage("Cannot encode demo image.") }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw BrainstormError.storage("Cannot encode demo image.") }
        return data as Data
    }
    private static func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGColor { CGColor(red: red, green: green, blue: blue, alpha: 1) }
    private static func drawText(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, color: CGColor, context: CGContext, serif: Bool = false) {
        let font = CTFontCreateWithName((serif ? "Georgia" : "HelveticaNeue-Medium") as CFString, size, nil)
        let string = NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color
        ])
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(CTLineCreateWithAttributedString(string), context)
    }
}

extension WorkspaceModel {
    func seedDemo() async {
        await createProject(prompt: "A minimal coastal poster. Warm paper, a terracotta sun, deep green shapes. A slower kind of summer.")
        count = 4
        await generate()
    }
}
