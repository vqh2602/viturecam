import CoreMediaIO
import CoreVideo
import Foundation
import IOKit.audio

// A source for conferencing apps and a sink for the processed frames from Runner.
// CoreMediaIO transports the buffers across the sandbox boundary.
final class CameraProvider: NSObject, CMIOExtensionProviderSource {
    private(set) var provider: CMIOExtensionProvider!
    private var camera: CameraDevice!
    override init() {
        super.init()
        let queue = DispatchQueue(label: "com.beautycamera.extension")
        provider = CMIOExtensionProvider(source: self, clientQueue: queue)
        camera = CameraDevice(queue: queue)
        try! provider.addDevice(camera.device)
    }
    func connect(to client: CMIOExtensionClient) throws {}
    func disconnect(from client: CMIOExtensionClient) { camera.disconnect(client) }
    var availableProperties: Set<CMIOExtensionProperty> { [.providerManufacturer] }
    func providerProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionProviderProperties {
        let result = CMIOExtensionProviderProperties(dictionary: [:])
        result.manufacturer = "Beauty Camera"
        return result
    }
    func setProviderProperties(_ properties: CMIOExtensionProviderProperties) throws {}
}

final class CameraDevice: NSObject, CMIOExtensionDeviceSource {
    private(set) var device: CMIOExtensionDevice!
    private var output: CameraStream!
    private var input: CameraStream!
    private let queue: DispatchQueue
    private var timer: DispatchSourceTimer?
    private var readers = 0
    private var writer: CMIOExtensionClient?
    private var consuming = false
    private var generation = 0
    private var latest: CVPixelBuffer?
    private var lastFrameTime: Double = 0
    private var black: CVPixelBuffer!
    private var format: CMVideoFormatDescription!

    init(queue: DispatchQueue) {
        self.queue = queue
        super.init()
        device = CMIOExtensionDevice(localizedName: "Beauty Camera",
            deviceID: UUID(uuidString: "3F021C86-4FE3-4E30-A577-6A595B308DA5")!, legacyDeviceID: nil, source: self)
        CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: kCVPixelFormatType_32BGRA,
            width: 1280, height: 720, extensions: nil, formatDescriptionOut: &format)
        CVPixelBufferCreate(kCFAllocatorDefault, 1280, 720, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &black)
        CVPixelBufferLockBaseAddress(black, [])
        let bytes = CVPixelBufferGetBaseAddress(black)!.assumingMemoryBound(to: UInt8.self)
        let count = CVPixelBufferGetBytesPerRow(black) * 720
        memset(bytes, 0, count)
        for i in stride(from: 3, to: count, by: 4) { bytes[i] = 255 }
        CVPixelBufferUnlockBaseAddress(black, [])
        let streamFormat = CMIOExtensionStreamFormat(formatDescription: format,
            maxFrameDuration: CMTime(value: 1, timescale: 30),
            minFrameDuration: CMTime(value: 1, timescale: 30), validFrameDurations: nil)
        output = CameraStream(owner: self, direction: .source, format: streamFormat,
            id: "707E02F0-402B-45A6-9D82-678EA849504D")
        input = CameraStream(owner: self, direction: .sink, format: streamFormat,
            id: "4A2E5395-C0D9-407B-925F-0D809CF78D05")
        try! device.addStream(output.stream)
        try! device.addStream(input.stream)
    }

    var availableProperties: Set<CMIOExtensionProperty> { [.deviceTransportType, .deviceModel] }
    func deviceProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionDeviceProperties {
        let result = CMIOExtensionDeviceProperties(dictionary: [:])
        result.transportType = kIOAudioDeviceTransportTypeVirtual
        result.model = "Beauty Camera Virtual Camera"
        return result
    }
    func setDeviceProperties(_ properties: CMIOExtensionDeviceProperties) throws {}

    func authorizeWriter(_ client: CMIOExtensionClient) -> Bool {
        guard writer == nil || writer?.clientID == client.clientID else { return false }
        writer = client
        return true
    }
    func start(_ direction: CMIOExtensionStream.Direction) {
        if direction == .source { readers += 1 }
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 1.0 / 30.0)
        timer.setEventHandler { [weak self] in self?.tick() }
        self.timer = timer
        timer.resume()
    }
    func stop(_ direction: CMIOExtensionStream.Direction) {
        if direction == .source { readers = max(0, readers - 1) }
        else {
            writer = nil
            latest = nil
            generation += 1
            consuming = false
        }
        if readers == 0 && writer == nil { timer?.cancel(); timer = nil }
    }
    func disconnect(_ client: CMIOExtensionClient) {
        if writer?.clientID == client.clientID { stop(.sink) }
    }
    private func tick() {
        let now = CMClockGetTime(CMClockGetHostTimeClock())
        if let writer = writer, !consuming {
            consuming = true
            let currentGeneration = generation
            input.stream.consumeSampleBuffer(from: writer) { [weak self] buffer, sequence, _, _, error in
                guard let self = self else { return }
                self.queue.async {
                    guard currentGeneration == self.generation else { return }
                    self.consuming = false
                    guard error == nil, let buffer = buffer,
                          let pixels = CMSampleBufferGetImageBuffer(buffer),
                          CVPixelBufferGetWidth(pixels) == 1280, CVPixelBufferGetHeight(pixels) == 720,
                          CVPixelBufferGetPixelFormatType(pixels) == kCVPixelFormatType_32BGRA else { return }
                    self.latest = pixels
                    self.lastFrameTime = CMClockGetTime(CMClockGetHostTimeClock()).seconds
                    self.input.stream.notifyScheduledOutputChanged(CMIOExtensionScheduledOutput(
                        sequenceNumber: sequence, hostTimeInNanoseconds: UInt64(self.lastFrameTime * 1_000_000_000)))
                }
            }
        }
        guard readers > 0 else { return }
        // Never keep displaying a person's last frame after the producer stops or crashes.
        let pixels = now.seconds - lastFrameTime < 0.5 ? (latest ?? black!) : black!
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: now, decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        if CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixels,
            dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: format,
            sampleTiming: &timing, sampleBufferOut: &sample) == noErr, let sample = sample {
            output.stream.send(sample, discontinuity: [], hostTimeInNanoseconds: UInt64(now.seconds * 1_000_000_000))
        }
    }
}

final class CameraStream: NSObject, CMIOExtensionStreamSource {
    private(set) var stream: CMIOExtensionStream!
    private unowned let owner: CameraDevice
    private let direction: CMIOExtensionStream.Direction
    let formats: [CMIOExtensionStreamFormat]
    var activeFormatIndex = 0
    init(owner: CameraDevice, direction: CMIOExtensionStream.Direction, format: CMIOExtensionStreamFormat, id: String) {
        self.owner = owner
        self.direction = direction
        self.formats = [format]
        super.init()
        stream = CMIOExtensionStream(localizedName: direction == .source ? "Beauty Camera Video" : "Beauty Camera Input",
            streamID: UUID(uuidString: id)!, direction: direction, clockType: .hostTime, source: self)
    }
    var availableProperties: Set<CMIOExtensionProperty> {
        var result: Set<CMIOExtensionProperty> = [.streamActiveFormatIndex, .streamFrameDuration]
        if direction == .sink { result.formUnion([.streamSinkBufferQueueSize, .streamSinkBuffersRequiredForStartup]) }
        return result
    }
    func streamProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionStreamProperties {
        let result = CMIOExtensionStreamProperties(dictionary: [:])
        result.activeFormatIndex = 0
        result.frameDuration = CMTime(value: 1, timescale: 30)
        if direction == .sink { result.sinkBufferQueueSize = 3; result.sinkBuffersRequiredForStartup = 1 }
        return result
    }
    func setStreamProperties(_ properties: CMIOExtensionStreamProperties) throws {
        if let index = properties.activeFormatIndex, index != 0 {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kCMIOHardwareUnsupportedOperationError))
        }
    }
    func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool {
        direction == .source || owner.authorizeWriter(client)
    }
    func startStream() throws { owner.start(direction) }
    func stopStream() throws { owner.stop(direction) }
}
