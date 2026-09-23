import Foundation

public struct BeautySettings {
    public var smooth: Double = 0.0          // 0.0 .. 1.0
    public var skinTexture: Double = 0.5     // 0.0 .. 1.0
    public var skinTone: Double = 0.0        // 0.0 .. 1.0
    public var skinToneType: String = "natural" // "natural", "porcelain", "snow", "rosy", "cherry", "peach", "coral", "warm", "honey", "wheat", "olive", "tan"
    public var skinBrightness: Double = 0.0  // 0.0 .. 1.0
    public var whitening: Double = 0.0       // 0.0 .. 1.0
    public var redness: Double = 0.0         // 0.0 .. 1.0
    public var darkCircle: Double = 0.0      // 0.0 .. 1.0
    public var eyeBag: Double = 0.0          // 0.0 .. 1.0
    public var eyeWrinkle: Double = 0.0       // 0.0 .. 1.0
    public var crowsFeet: Double = 0.0        // 0.0 .. 1.0
    public var teethWhitening: Double = 0.0  // 0.0 .. 1.0
    public var glassSkin: Double = 0.0       // 0.0 .. 1.0

    public init(from dict: [String: Any]? = nil) {
        guard let dict = dict else { return }
        if let v = dict["smooth"] as? Double { smooth = v }
        if let v = dict["skinTexture"] as? Double { skinTexture = v }
        if let v = dict["skinTone"] as? Double { skinTone = v }
        if let v = dict["skinToneType"] as? String { skinToneType = v }
        if let v = dict["skinBrightness"] as? Double { skinBrightness = v }
        if let v = dict["whitening"] as? Double { whitening = v }
        if let v = dict["redness"] as? Double { redness = v }
        if let v = dict["darkCircle"] as? Double { darkCircle = v }
        if let v = dict["eyeBag"] as? Double { eyeBag = v }
        if let v = dict["eyeWrinkle"] as? Double { eyeWrinkle = v }
        if let v = dict["crowsFeet"] as? Double { crowsFeet = v }
        if let v = dict["teethWhitening"] as? Double { teethWhitening = v }
        if let v = dict["glassSkin"] as? Double { glassSkin = v }
    }
}

public struct FaceSettings {
    public var slimFace: Double = 0.0        // 0.0 .. 1.0
    public var smallFace: Double = 0.0       // 0.0 .. 1.0
    public var vFace: Double = 0.0           // 0.0 .. 1.0
    public var jawWidth: Double = 0.0        // -1.0 .. 1.0 (0 = default)
    public var cheekWidth: Double = 0.0      // -1.0 .. 1.0
    public var chinLength: Double = 0.0      // -1.0 .. 1.0
    public var chinWidth: Double = 0.0       // -1.0 .. 1.0
    public var forehead: Double = 0.0        // -1.0 .. 1.0
    public var templeWidth: Double = 0.0     // -1.0 .. 1.0
    public var hairline: Double = 0.0        // -1.0 .. 1.0
    public var doubleChin: Double = 0.0      // 0.0 .. 1.0
    public var jawline: Double = 0.0         // 0.0 .. 1.0

    public var eyeSize: Double = 0.0         // 0.0 .. 1.0
    public var eyeWidth: Double = 0.0        // -1.0 .. 1.0
    public var eyeHeight: Double = 0.0       // -1.0 .. 1.0
    public var eyeDistance: Double = 0.0     // -1.0 .. 1.0
    public var eyeAngle: Double = 0.0        // -1.0 .. 1.0
    public var eyeBrightness: Double = 0.0   // 0.0 .. 1.0
    public var eyeSparkle: Double = 0.0      // 0.0 .. 1.0
    public var eyeSparkleStyle: String = "starlight" // "natural", "starlight", "ring", "crystal"
    public var aegyoSal: Double = 0.0        // 0.0 .. 1.0

    public var eyebrowHeight: Double = 0.0   // -1.0 .. 1.0 (0 = default)
    public var eyebrowArch: Double = 0.0     // -1.0 .. 1.0 (0 = default)
    public var eyebrowTilt: Double = 0.0     // -1.0 .. 1.0 (0 = default)

    public var noseWidth: Double = 0.0       // -1.0 .. 1.0
    public var noseLength: Double = 0.0      // -1.0 .. 1.0
    public var noseBridge: Double = 0.0      // -1.0 .. 1.0
    public var noseTip: Double = 0.0         // -1.0 .. 1.0
    public var nostrilWidth: Double = 0.0    // -1.0 .. 1.0

    public var mouthSize: Double = 0.0       // -1.0 .. 1.0
    public var mouthWidth: Double = 0.0      // -1.0 .. 1.0
    public var lipThickness: Double = 0.0    // -1.0 .. 1.0
    public var smile: Double = 0.0           // 0.0 .. 1.0
    public var smileCorners: Double = 0.0    // 0.0 .. 1.0
    public var mShapeLips: Double = 0.0       // 0.0 .. 1.0
    public var mouthPosition: Double = 0.0   // -1.0 .. 1.0

    public init(from dict: [String: Any]? = nil) {
        guard let dict = dict else { return }
        if let v = dict["slimFace"] as? Double { slimFace = v }
        if let v = dict["smallFace"] as? Double { smallFace = v }
        if let v = dict["vFace"] as? Double { vFace = v }
        if let v = dict["jawWidth"] as? Double { jawWidth = v }
        if let v = dict["cheekWidth"] as? Double { cheekWidth = v }
        if let v = dict["chinLength"] as? Double { chinLength = v }
        if let v = dict["chinWidth"] as? Double { chinWidth = v }
        if let v = dict["forehead"] as? Double { forehead = v }
        if let v = dict["templeWidth"] as? Double { templeWidth = v }
        if let v = dict["hairline"] as? Double { hairline = v }
        if let v = dict["doubleChin"] as? Double { doubleChin = v }
        if let v = dict["jawline"] as? Double { jawline = v }

        if let v = dict["eyeSize"] as? Double { eyeSize = v }
        if let v = dict["eyeWidth"] as? Double { eyeWidth = v }
        if let v = dict["eyeHeight"] as? Double { eyeHeight = v }
        if let v = dict["eyeDistance"] as? Double { eyeDistance = v }
        if let v = dict["eyeAngle"] as? Double { eyeAngle = v }
        if let v = dict["eyeBrightness"] as? Double { eyeBrightness = v }
        if let v = dict["eyeSparkle"] as? Double { eyeSparkle = v }
        if let v = dict["eyeSparkleStyle"] as? String { eyeSparkleStyle = v }
        if let v = dict["aegyoSal"] as? Double { aegyoSal = v }

        if let v = dict["eyebrowHeight"] as? Double { eyebrowHeight = v }
        if let v = dict["eyebrowArch"] as? Double { eyebrowArch = v }
        if let v = dict["eyebrowTilt"] as? Double { eyebrowTilt = v }

        if let v = dict["noseWidth"] as? Double { noseWidth = v }
        if let v = dict["noseLength"] as? Double { noseLength = v }
        if let v = dict["noseBridge"] as? Double { noseBridge = v }
        if let v = dict["noseTip"] as? Double { noseTip = v }
        if let v = dict["nostrilWidth"] as? Double { nostrilWidth = v }

        if let v = dict["mouthSize"] as? Double { mouthSize = v }
        if let v = dict["mouthWidth"] as? Double { mouthWidth = v }
        if let v = dict["lipThickness"] as? Double { lipThickness = v }
        if let v = dict["smile"] as? Double { smile = v }
        if let v = dict["smileCorners"] as? Double { smileCorners = v }
        if let v = dict["mShapeLips"] as? Double { mShapeLips = v }
        if let v = dict["mouthPosition"] as? Double { mouthPosition = v }
    }
}

public struct MakeupSettings {
    public var lipPreset: String = "none"
    public var lipOpacity: Double = 0.0
    public var lipStyle: String = "full"       // "full", "gradient", "liner", "gloss"
    public var blushPreset: String = "none"
    public var blushOpacity: Double = 0.0
    public var blushStyle: String = "apple"    // "apple", "sunkissed", "lifted", "undereye", "contour"
    public var eyebrowPreset: String = "none"
    public var eyebrowOpacity: Double = 0.0
    public var eyebrowStyle: String = "natural" // "natural", "korean", "arched", "feathered", "willow", "male_natural", "male_sword", "male_bold", "male_feathered"
    public var eyelinerPreset: String = "none"
    public var eyelinerOpacity: Double = 0.0
    public var eyelinerStyle: String = "classic" // "natural", "classic", "cat", "puppy", "fox"
    public var eyeshadowPreset: String = "none"
    public var eyeshadowOpacity: Double = 0.0
    public var eyeshadowStyle: String = "gradient" // "korean", "gradient", "sheer", "shimmer", "halo", "puppy", "douyin", "outerV", "cutCrease"
    public var eyelashesPreset: String = "none"
    public var eyelashesOpacity: Double = 0.0
    public var contactLensPreset: String = "none"
    public var contactLensOpacity: Double = 0.70
    public var contactLensStyle: String = "natural" // "natural", "limbalRing", "galaxy", "starburst"
    public var sparklePreset: String = "none"
    public var sparkleOpacity: Double = 0.60
    public var sparkleStyle: String = "starlight" // 10 styles
    public var contourPreset: String = "none"
    public var contourOpacity: Double = 0.0
    public var contourStyle: String = "vShape" // "vShape", "natural", "sculpted", "nose", "soft"

    public init(from dict: [String: Any]? = nil) {
        guard let dict = dict else { return }
        if let v = dict["lipPreset"] as? String { lipPreset = v }
        if let v = dict["lipOpacity"] as? Double { lipOpacity = v }
        if let v = dict["lipStyle"] as? String { lipStyle = v }
        if let v = dict["blushPreset"] as? String { blushPreset = v }
        if let v = dict["blushOpacity"] as? Double { blushOpacity = v }
        if let v = dict["blushStyle"] as? String { blushStyle = v }
        if let v = dict["eyebrowPreset"] as? String { eyebrowPreset = v }
        if let v = dict["eyebrowOpacity"] as? Double { eyebrowOpacity = v }
        if let v = dict["eyebrowStyle"] as? String { eyebrowStyle = v }
        if let v = dict["eyelinerPreset"] as? String { eyelinerPreset = v }
        if let v = dict["eyelinerOpacity"] as? Double { eyelinerOpacity = v }
        if let v = dict["eyelinerStyle"] as? String { eyelinerStyle = v }
        if let v = dict["eyeshadowPreset"] as? String { eyeshadowPreset = v }
        if let v = dict["eyeshadowOpacity"] as? Double { eyeshadowOpacity = v }
        if let v = dict["eyeshadowStyle"] as? String { eyeshadowStyle = v }
        if let v = dict["eyelashesPreset"] as? String { eyelashesPreset = v }
        if let v = dict["eyelashesOpacity"] as? Double { eyelashesOpacity = v }
        if let v = dict["contactLensPreset"] as? String { contactLensPreset = v }
        if let v = dict["contactLensOpacity"] as? Double { contactLensOpacity = v }
        if let v = dict["contactLensStyle"] as? String { contactLensStyle = v }
        if let v = dict["sparklePreset"] as? String { sparklePreset = v }
        if let v = dict["sparkleOpacity"] as? Double { sparkleOpacity = v }
        if let v = dict["sparkleStyle"] as? String { sparkleStyle = v }
        if let v = dict["contourPreset"] as? String { contourPreset = v }
        if let v = dict["contourOpacity"] as? Double { contourOpacity = v }
        if let v = dict["contourStyle"] as? String { contourStyle = v }
    }
}

public struct FilterSettings {
    public var filterId: String = "original"
    public var intensity: Double = 0.8 // 0.0 .. 1.0

    public init(from dict: [String: Any]? = nil) {
        guard let dict = dict else { return }
        if let v = dict["filterId"] as? String { filterId = v }
        if let v = dict["intensity"] as? Double { intensity = v }
    }
}

public struct ColorSettings {
    public var exposure: Double = 0.0       // -1.0 .. 1.0
    public var brightness: Double = 0.0     // -1.0 .. 1.0
    public var contrast: Double = 1.0       // 0.5 .. 1.5 (1.0 default)
    public var highlights: Double = 0.0     // -1.0 .. 1.0
    public var shadows: Double = 0.0        // -1.0 .. 1.0
    public var saturation: Double = 1.0     // 0.0 .. 2.0 (1.0 default)
    public var temperature: Double = 0.0    // -1.0 .. 1.0 (cool < 0, warm > 0)
    public var tint: Double = 0.0           // -1.0 .. 1.0 (green < 0, magenta > 0)
    public var sharpness: Double = 0.0      // 0.0 .. 2.0 (0.0 default)

    public init(from dict: [String: Any]? = nil) {
        guard let dict = dict else { return }
        if let v = dict["exposure"] as? Double { exposure = v }
        if let v = dict["brightness"] as? Double { brightness = v }
        if let v = dict["contrast"] as? Double { contrast = v }
        if let v = dict["highlights"] as? Double { highlights = v }
        if let v = dict["shadows"] as? Double { shadows = v }
        if let v = dict["saturation"] as? Double { saturation = v }
        if let v = dict["temperature"] as? Double { temperature = v }
        if let v = dict["tint"] as? Double { tint = v }
        if let v = dict["sharpness"] as? Double { sharpness = v }
    }
}

public struct BackgroundSettings {
    public var mode: String = "none" // "none", "portrait_blur", "strong_blur", "virtual_studio"
    public var blurIntensity: Double = 0.5 // 0.0 .. 1.0

    public init(from dict: [String: Any]? = nil) {
        guard let dict = dict else { return }
        if let v = dict["mode"] as? String { mode = v }
        if let v = dict["blurIntensity"] as? Double { blurIntensity = v }
    }
}
