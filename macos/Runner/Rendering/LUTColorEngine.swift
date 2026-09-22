import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO

// MARK: - 3D LUT Data Container
public struct LUTData {
    public let dimension: Int
    public let data: Data
    public let colorSpace: CGColorSpace
    
    public init(dimension: Int, data: Data, colorSpace: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!) {
        self.dimension = dimension
        self.data = data
        self.colorSpace = colorSpace
    }
}

// MARK: - Internal Color Math for Procedural LUT Generation
private struct LUTColorRGB {
    var r: Double
    var g: Double
    var b: Double
    
    func clamped() -> LUTColorRGB {
        return LUTColorRGB(
            r: min(max(r, 0.0), 1.0),
            g: min(max(g, 0.0), 1.0),
            b: min(max(b, 0.0), 1.0)
        )
    }
    
    var luminance: Double {
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
    
    func toHSV() -> (h: Double, s: Double, v: Double) {
        let maxVal = max(r, max(g, b))
        let minVal = min(r, min(g, b))
        let delta = maxVal - minVal
        
        var h: Double = 0.0
        let s: Double = maxVal > 0.0001 ? delta / maxVal : 0.0
        let v: Double = maxVal
        
        if delta > 0.0001 {
            if maxVal == r {
                h = 60.0 * ((g - b) / delta).truncatingRemainder(dividingBy: 6.0)
            } else if maxVal == g {
                h = 60.0 * (((b - r) / delta) + 2.0)
            } else {
                h = 60.0 * (((r - g) / delta) + 4.0)
            }
            if h < 0 { h += 360.0 }
        }
        return (h, s, v)
    }
    
    static func fromHSV(h: Double, s: Double, v: Double) -> LUTColorRGB {
        let c = v * s
        let x = c * (1.0 - abs((h / 60.0).truncatingRemainder(dividingBy: 2.0) - 1.0))
        let m = v - c
        
        var rgb = (0.0, 0.0, 0.0)
        if h < 60 { rgb = (c, x, 0.0) }
        else if h < 120 { rgb = (x, c, 0.0) }
        else if h < 180 { rgb = (0.0, c, x) }
        else if h < 240 { rgb = (0.0, x, c) }
        else if h < 300 { rgb = (x, 0.0, c) }
        else { rgb = (c, 0.0, x) }
        
        return LUTColorRGB(r: rgb.0 + m, g: rgb.1 + m, b: rgb.2 + m)
    }
    
    func adjustSaturation(_ factor: Double) -> LUTColorRGB {
        let lum = luminance
        return LUTColorRGB(
            r: lum + (r - lum) * factor,
            g: lum + (g - lum) * factor,
            b: lum + (b - lum) * factor
        )
    }
    
    func adjustContrast(_ factor: Double, pivot: Double = 0.5) -> LUTColorRGB {
        return LUTColorRGB(
            r: pivot + (r - pivot) * factor,
            g: pivot + (g - pivot) * factor,
            b: pivot + (b - pivot) * factor
        )
    }
    
    func sCurve(strength: Double) -> LUTColorRGB {
        func curve(_ x: Double) -> Double {
            let sc = x < 0.5 ? 2.0 * x * x : 1.0 - 2.0 * (1.0 - x) * (1.0 - x)
            return x * (1.0 - strength) + sc * strength
        }
        return LUTColorRGB(r: curve(r), g: curve(g), b: curve(b))
    }
    
    func liftGammaGain(lift: (Double, Double, Double), gamma: (Double, Double, Double), gain: (Double, Double, Double)) -> LUTColorRGB {
        func apply(_ x: Double, l: Double, g: Double, gn: Double) -> Double {
            let lifted = x * (1.0 - l) + l
            let gammaCorrected = pow(max(lifted, 0.0), 1.0 / max(g, 0.01))
            return gammaCorrected * gn
        }
        return LUTColorRGB(
            r: apply(r, l: lift.0, g: gamma.0, gn: gain.0),
            g: apply(g, l: lift.1, g: gamma.1, gn: gain.1),
            b: apply(b, l: lift.2, g: gamma.2, gn: gain.2)
        )
    }
    
    func filmicShoulder(threshold: Double = 0.7) -> LUTColorRGB {
        func shoulder(_ x: Double) -> Double {
            if x <= threshold { return x }
            let excess = x - threshold
            let maxExcess = 1.0 - threshold
            let compressed = threshold + maxExcess * (1.0 - exp(-excess / (maxExcess * 0.7)))
            return compressed
        }
        return LUTColorRGB(r: shoulder(r), g: shoulder(g), b: shoulder(b))
    }
}

// MARK: - LUT Color Engine
public final class LUTColorEngine {
    public static let shared = LUTColorEngine()
    
    private var lutCache: [String: LUTData] = [:]
    private let lock = NSLock()
    private let defaultDimension = 32
    
    private init() {
        // Pre-warm common LUTs in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            _ = self?.getOrLoadLUT(filterId: "douyin_fairy")
            _ = self?.getOrLoadLUT(filterId: "milk")
            _ = self?.getOrLoadLUT(filterId: "clear")
            _ = self?.getOrLoadLUT(filterId: "film")
        }
    }
    
    // MARK: - Main Apply API
    public func applyLUT(to image: CIImage, filterId: String, intensity: Double) -> CIImage {
        guard filterId != "original" && intensity > 0.005 else {
            return image
        }
        
        guard let lut = getOrLoadLUT(filterId: filterId) else {
            return image
        }
        
        // Use CIColorCubeWithColorSpace (GPU accelerated, 60+ FPS)
        let filterName = "CIColorCubeWithColorSpace"
        guard let cubeFilter = CIFilter(name: filterName) ?? CIFilter(name: "CIColorCube") else {
            return image
        }
        
        cubeFilter.setValue(image, forKey: kCIInputImageKey)
        cubeFilter.setValue(lut.dimension, forKey: "inputCubeDimension")
        cubeFilter.setValue(lut.data, forKey: "inputCubeData")
        if cubeFilter.inputKeys.contains("inputColorSpace") {
            cubeFilter.setValue(lut.colorSpace, forKey: "inputColorSpace")
        }
        
        guard let graded = cubeFilter.outputImage else {
            return image
        }
        
        if intensity < 0.999 {
            if let blend = CIFilter(name: "CIBlendWithAlphaMask") {
                blend.setValue(graded, forKey: kCIInputImageKey)
                blend.setValue(image, forKey: kCIInputBackgroundImageKey)
                let mask = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: CGFloat(intensity))).cropped(to: image.extent)
                blend.setValue(mask, forKey: kCIInputMaskImageKey)
                if let blended = blend.outputImage {
                    return blended
                }
            }
        }
        
        return graded
    }
    
    // MARK: - LUT Resolution & Caching
    public func getOrLoadLUT(filterId: String) -> LUTData? {
        lock.lock()
        if let cached = lutCache[filterId] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        // 1. Try loading .cube file from bundle / disk
        if let cubeData = loadCubeFromDisk(filterId: filterId) {
            lock.lock()
            lutCache[filterId] = cubeData
            lock.unlock()
            return cubeData
        }
        
        // 2. Try loading .png Strip LUT from bundle / disk
        if let pngData = loadPngFromDisk(filterId: filterId) {
            lock.lock()
            lutCache[filterId] = pngData
            lock.unlock()
            return pngData
        }
        
        // 3. Fallback to procedural 3D LUT generation (never fails)
        if let proceduralData = generateProceduralLUT(filterId: filterId) {
            lock.lock()
            lutCache[filterId] = proceduralData
            lock.unlock()
            return proceduralData
        }
        
        return nil
    }
    
    public func reloadLUT(filterId: String) {
        lock.lock()
        lutCache.removeValue(forKey: filterId)
        lock.unlock()
        _ = getOrLoadLUT(filterId: filterId)
    }
    
    public func clearCache() {
        lock.lock()
        lutCache.removeAll()
        lock.unlock()
    }
    
    // MARK: - Candidate URL Resolution
    private func candidateURLs(for filename: String) -> [URL] {
        var urls: [URL] = []
        
        // User custom LUTs in Application Support
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            urls.append(appSupport.appendingPathComponent("viturecam/luts/\(filename)"))
            urls.append(appSupport.appendingPathComponent("luts/\(filename)"))
        }
        
        // Flutter assets in main bundle
        if let resURL = Bundle.main.resourceURL {
            urls.append(resURL.appendingPathComponent("flutter_assets/assets/luts/\(filename)"))
            urls.append(resURL.appendingPathComponent("assets/luts/\(filename)"))
        }
        if let bundleUrl = Bundle.main.url(forResource: filename, withExtension: nil) {
            urls.append(bundleUrl)
        }
        if let flutterUrl = Bundle.main.url(forResource: "flutter_assets/assets/luts/\(filename)", withExtension: nil) {
            urls.append(flutterUrl)
        }
        
        // App.framework resources
        let appFramework = Bundle.main.bundleURL.appendingPathComponent("Contents/Frameworks/App.framework")
        urls.append(appFramework.appendingPathComponent("Resources/flutter_assets/assets/luts/\(filename)"))
        urls.append(appFramework.appendingPathComponent("Versions/A/Resources/flutter_assets/assets/luts/\(filename)"))
        
        // Local relative assets directory
        urls.append(URL(fileURLWithPath: "assets/luts/\(filename)"))
        
        return urls
    }
    
    // MARK: - File Loaders & Parsers
    private func loadCubeFromDisk(filterId: String) -> LUTData? {
        let filename = "\(filterId).cube"
        for url in candidateURLs(for: filename) {
            if FileManager.default.fileExists(atPath: url.path) {
                if let lut = parseCubeFile(url: url) {
                    return lut
                }
            }
        }
        return nil
    }
    
    private func loadPngFromDisk(filterId: String) -> LUTData? {
        let filename = "\(filterId).png"
        for url in candidateURLs(for: filename) {
            if FileManager.default.fileExists(atPath: url.path) {
                if let lut = parseStripPNG(url: url) {
                    return lut
                }
            }
        }
        return nil
    }
    
    public func parseCubeFile(url: URL) -> LUTData? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var dimension = defaultDimension
        var floatValues = [Float]()
        
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if trimmed.hasPrefix("LUT_3D_SIZE") {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2, let dim = Int(parts[1]) {
                    dimension = dim
                    floatValues.reserveCapacity(dimension * dimension * dimension * 4)
                }
                continue
            }
            if trimmed.hasPrefix("TITLE") || trimmed.hasPrefix("DOMAIN_") { continue }
            
            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if parts.count >= 3,
               let r = Float(parts[0]),
               let g = Float(parts[1]),
               let b = Float(parts[2]) {
                floatValues.append(r)
                floatValues.append(g)
                floatValues.append(b)
                floatValues.append(1.0)
            }
        }
        
        guard floatValues.count == dimension * dimension * dimension * 4 else {
            return nil
        }
        
        let data = floatValues.withUnsafeBufferPointer { Data(buffer: $0) }
        return LUTData(dimension: dimension, data: data)
    }
    
    public func parseStripPNG(url: URL) -> LUTData? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        let width = cgImage.width
        let height = cgImage.height
        guard width == height * height else {
            return nil
        }
        let dimension = height
        var rawPixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(
            data: &rawPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var floatValues = [Float]()
        floatValues.reserveCapacity(dimension * dimension * dimension * 4)
        
        // Core Image cube order: b outer, g middle, r inner
        for b in 0..<dimension {
            for g in 0..<dimension {
                for r in 0..<dimension {
                    let px = b * dimension + r
                    let py = g
                    let offset = (py * width + px) * 4
                    let redVal = Float(rawPixels[offset + 0]) / 255.0
                    let greenVal = Float(rawPixels[offset + 1]) / 255.0
                    let blueVal = Float(rawPixels[offset + 2]) / 255.0
                    floatValues.append(redVal)
                    floatValues.append(greenVal)
                    floatValues.append(blueVal)
                    floatValues.append(1.0)
                }
            }
        }
        let data = floatValues.withUnsafeBufferPointer { Data(buffer: $0) }
        return LUTData(dimension: dimension, data: data)
    }
    
    // MARK: - Built-in Procedural Fallback Engine
    private func generateProceduralLUT(filterId: String) -> LUTData? {
        let dim = defaultDimension
        var floatValues = [Float]()
        floatValues.reserveCapacity(dim * dim * dim * 4)
        
        let transform = proceduralTransform(for: filterId)
        
        for bIdx in 0..<dim {
            let bVal = Double(bIdx) / Double(dim - 1)
            for gIdx in 0..<dim {
                let gVal = Double(gIdx) / Double(dim - 1)
                for rIdx in 0..<dim {
                    let rVal = Double(rIdx) / Double(dim - 1)
                    let input = LUTColorRGB(r: rVal, g: gVal, b: bVal)
                    let out = transform(input).clamped()
                    floatValues.append(Float(out.r))
                    floatValues.append(Float(out.g))
                    floatValues.append(Float(out.b))
                    floatValues.append(1.0)
                }
            }
        }
        
        let data = floatValues.withUnsafeBufferPointer { Data(buffer: $0) }
        return LUTData(dimension: dim, data: data)
    }
    
    private func proceduralTransform(for filterId: String) -> (LUTColorRGB) -> LUTColorRGB {
        switch filterId {
        // --- Douyin Filters ---
        case "douyin_fairy":
            return { c in
                var (h, s, v) = c.toHSV()
                if h > 35 && h < 70 { s *= 0.82 }
                if h > 330 || h < 25 { s = min(s * 1.12, 1.0) }
                var rgb = LUTColorRGB.fromHSV(h: h, s: s, v: v)
                rgb = rgb.liftGammaGain(lift: (0.03, 0.01, 0.05), gamma: (1.10, 1.06, 1.12), gain: (1.04, 1.01, 1.03))
                return rgb.filmicShoulder(threshold: 0.75).adjustSaturation(1.06)
            }
        case "douyin_sweet":
            return { c in
                var (h, s, v) = c.toHSV()
                if h > 10 && h < 45 { s = min(s * 1.15, 1.0) }
                var rgb = LUTColorRGB.fromHSV(h: h, s: s, v: v)
                rgb = rgb.liftGammaGain(lift: (0.02, 0.01, 0.01), gamma: (1.12, 1.05, 1.02), gain: (1.06, 1.02, 0.98))
                return rgb.adjustContrast(1.05).filmicShoulder()
            }
        case "douyin_moon":
            return { c in
                var (h, s, v) = c.toHSV()
                if h > 40 && h < 75 { s *= 0.72 }
                var rgb = LUTColorRGB.fromHSV(h: h, s: s, v: v)
                rgb = rgb.liftGammaGain(lift: (0.01, 0.02, 0.04), gamma: (1.06, 1.08, 1.14), gain: (1.02, 1.04, 1.08))
                return rgb.adjustContrast(1.08).filmicShoulder()
            }
        case "douyin_dreamy":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.05, 0.03, 0.06), gamma: (1.14, 1.08, 1.14), gain: (1.00, 0.98, 1.02))
                return rgb.adjustSaturation(0.92).adjustContrast(0.94)
            }
        case "douyin_doll":
            return { c in
                var (h, s, v) = c.toHSV()
                if h > 320 || h < 30 { s = min(s * 1.25, 1.0) }
                var rgb = LUTColorRGB.fromHSV(h: h, s: s, v: v)
                rgb = rgb.liftGammaGain(lift: (0.01, 0.00, 0.02), gamma: (1.10, 1.04, 1.08), gain: (1.08, 1.02, 1.06))
                return rgb.adjustContrast(1.10).filmicShoulder()
            }
        case "douyin_radiant":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.01, 0.01, 0.01), gamma: (1.16, 1.14, 1.12), gain: (1.08, 1.06, 1.04))
                return rgb.sCurve(strength: 0.15).adjustSaturation(1.08).filmicShoulder()
            }
        case "douyin_vintage":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.04, 0.02, 0.02), gamma: (1.08, 1.02, 0.98), gain: (1.04, 0.98, 0.95))
                return rgb.sCurve(strength: 0.12).adjustSaturation(1.04)
            }
            
        // --- Korean Filters ---
        case "milk":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.04, 0.04, 0.05), gamma: (1.15, 1.12, 1.16), gain: (1.02, 1.02, 1.04))
                return rgb.adjustContrast(0.96).adjustSaturation(0.94).filmicShoulder()
            }
        case "peach":
            return { c in
                var (h, s, v) = c.toHSV()
                if h > 15 && h < 45 { s = min(s * 1.20, 1.0) }
                var rgb = LUTColorRGB.fromHSV(h: h, s: s, v: v)
                rgb = rgb.liftGammaGain(lift: (0.02, 0.01, 0.01), gamma: (1.12, 1.06, 1.02), gain: (1.06, 1.02, 0.98))
                return rgb.sCurve(strength: 0.12).filmicShoulder()
            }
        case "sakura":
            return { c in
                var (h, s, v) = c.toHSV()
                if h > 320 || h < 20 { s = min(s * 1.18, 1.0) }
                var rgb = LUTColorRGB.fromHSV(h: h, s: s, v: v)
                rgb = rgb.liftGammaGain(lift: (0.03, 0.01, 0.03), gamma: (1.10, 1.04, 1.08), gain: (1.05, 1.01, 1.04))
                return rgb.adjustContrast(1.04).filmicShoulder()
            }
        case "cream":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.03, 0.03, 0.02), gamma: (1.08, 1.07, 1.02), gain: (1.04, 1.03, 0.97))
                return rgb.adjustContrast(0.98).adjustSaturation(0.95)
            }
        case "idol":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.00, 0.00, 0.01), gamma: (1.12, 1.08, 1.14), gain: (1.08, 1.05, 1.08))
                return rgb.adjustContrast(1.14).adjustSaturation(1.15).filmicShoulder(threshold: 0.8)
            }
            
        // --- Natural Filters ---
        case "clear":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.005, 0.005, 0.005), gamma: (1.06, 1.06, 1.06), gain: (1.03, 1.03, 1.03))
                return rgb.adjustContrast(1.08).adjustSaturation(1.05).filmicShoulder()
            }
        case "pure":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.01, 0.02, 0.03), gamma: (1.08, 1.08, 1.10), gain: (1.02, 1.02, 1.04))
                return rgb.adjustContrast(0.98).adjustSaturation(0.96).filmicShoulder()
            }
        case "clean":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.01, 0.01, 0.01), gamma: (1.05, 1.05, 1.05), gain: (1.02, 1.02, 1.02))
                return rgb.adjustContrast(1.04)
            }
        case "dewy":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.01, 0.01, 0.005), gamma: (1.10, 1.08, 1.05), gain: (1.05, 1.04, 1.01))
                return rgb.sCurve(strength: 0.14).adjustSaturation(1.06).filmicShoulder()
            }
            
        // --- Film Filters ---
        case "film":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.02, 0.04, 0.04), gamma: (1.04, 1.01, 0.96), gain: (1.05, 1.02, 0.96))
                return rgb.sCurve(strength: 0.22).adjustSaturation(1.08).filmicShoulder()
            }
        case "kodak":
            return { c in
                var (h, s, v) = c.toHSV()
                if h > 20 && h < 55 { s = min(s * 1.12, 1.0) }
                var rgb = LUTColorRGB.fromHSV(h: h, s: s, v: v)
                rgb = rgb.liftGammaGain(lift: (0.01, 0.03, 0.04), gamma: (1.06, 1.02, 0.94), gain: (1.06, 1.02, 0.94))
                return rgb.sCurve(strength: 0.18).adjustSaturation(1.10).filmicShoulder()
            }
        case "fuji":
            return { c in
                var (h, s, v) = c.toHSV()
                if h > 70 && h < 240 { s = min(s * 1.25, 1.0) }
                var rgb = LUTColorRGB.fromHSV(h: h, s: s, v: v)
                rgb = rgb.liftGammaGain(lift: (0.01, 0.01, 0.02), gamma: (1.00, 1.03, 1.05), gain: (1.02, 1.01, 1.06))
                return rgb.sCurve(strength: 0.24).adjustSaturation(1.12).filmicShoulder()
            }
        case "retro":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.04, 0.02, 0.04), gamma: (1.06, 1.00, 0.95), gain: (1.02, 0.98, 0.92))
                return rgb.sCurve(strength: 0.15).adjustSaturation(1.05)
            }
        case "vintage":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.05, 0.04, 0.02), gamma: (1.08, 1.02, 0.88), gain: (1.04, 0.96, 0.84))
                return rgb.adjustContrast(0.95).adjustSaturation(0.98)
            }
        case "cinema":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.00, 0.04, 0.06), gamma: (1.08, 0.98, 0.90), gain: (1.08, 1.02, 0.92))
                return rgb.sCurve(strength: 0.26).adjustSaturation(1.14).filmicShoulder()
            }
            
        // --- Warm Filters ---
        case "warm":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.02, 0.01, 0.00), gamma: (1.08, 1.04, 0.96), gain: (1.06, 1.02, 0.94))
                return rgb.sCurve(strength: 0.12).adjustSaturation(1.08)
            }
        case "sunset":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.03, 0.01, 0.02), gamma: (1.14, 1.02, 0.92), gain: (1.10, 1.00, 0.90))
                return rgb.adjustContrast(1.10).adjustSaturation(1.18).filmicShoulder()
            }
        case "latte":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.04, 0.03, 0.02), gamma: (1.06, 1.01, 0.92), gain: (1.02, 0.98, 0.90))
                return rgb.adjustContrast(1.02).adjustSaturation(0.96)
            }
        case "autumn":
            return { c in
                var (h, s, v) = c.toHSV()
                if h > 15 && h < 60 { s = min(s * 1.25, 1.0) }
                var rgb = LUTColorRGB.fromHSV(h: h, s: s, v: v)
                rgb = rgb.liftGammaGain(lift: (0.02, 0.01, 0.00), gamma: (1.08, 1.00, 0.90), gain: (1.06, 0.98, 0.88))
                return rgb.adjustContrast(1.12).filmicShoulder()
            }
            
        // --- Cool Filters ---
        case "cool":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.00, 0.01, 0.03), gamma: (0.98, 1.02, 1.08), gain: (0.96, 1.00, 1.06))
                return rgb.adjustContrast(1.06).adjustSaturation(1.02)
            }
        case "nordic":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.02, 0.03, 0.05), gamma: (0.96, 1.00, 1.06), gain: (0.98, 1.00, 1.04))
                return rgb.adjustContrast(1.04).adjustSaturation(0.88)
            }
        case "cyber":
            return { c in
                let rgb = c.liftGammaGain(lift: (0.02, 0.00, 0.05), gamma: (1.05, 0.95, 1.15), gain: (1.10, 0.96, 1.15))
                return rgb.sCurve(strength: 0.28).adjustSaturation(1.30).filmicShoulder()
            }
            
        // --- B&W Filters ---
        case "bw":
            return { c in
                let panchromaticLum = 0.25 * c.r + 0.65 * c.g + 0.10 * c.b
                let rgb = LUTColorRGB(r: panchromaticLum, g: panchromaticLum, b: panchromaticLum)
                return rgb.sCurve(strength: 0.18).filmicShoulder()
            }
        case "noir":
            return { c in
                let lum = 0.28 * c.r + 0.62 * c.g + 0.10 * c.b
                let rgb = LUTColorRGB(r: lum, g: lum, b: lum)
                return rgb.adjustContrast(1.35)
            }
        case "silver":
            return { c in
                let lum = 0.22 * c.r + 0.70 * c.g + 0.08 * c.b
                var rgb = LUTColorRGB(r: lum, g: lum, b: lum)
                rgb = rgb.liftGammaGain(lift: (0.03, 0.03, 0.03), gamma: (1.10, 1.10, 1.10), gain: (1.02, 1.02, 1.02))
                return rgb.sCurve(strength: 0.12).filmicShoulder()
            }
            
        default:
            return { $0 }
        }
    }
}
