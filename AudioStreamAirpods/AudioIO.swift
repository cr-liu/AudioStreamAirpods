//
//  AudioRecorder.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/13.
//

import AVFoundation

class AudioIO {
    enum AudioEngineState {
        case started, paused, stopped
    }
    
    var messages: [String] = []
    var playerDelay: Int = 1
    private var firstShot: Bool = false
    private var engine: AVAudioEngine!
//    private var muteMicSource: Bool = true
//    private var muteTcpSource: Bool = true
    private var sinkNode: AVAudioSinkNode!
    private var micSourceNode: AVAudioSourceNode!
    private var tcpSourceNode: AVAudioSourceNode!
    private var micMuteMixer: AVAudioMixerNode!
    private var tcpMuteMixer: AVAudioMixerNode!
    private var srConverter: AVAudioConverter!
    
    private var deviceBufSize: Int = 64
    private var sinkNodeBufSize: Int = 0
    private var sr: Double = 48000
    private var socketSize = Int(16000 * 0.01)
    
    private var format16kCh1 = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
                                                 sampleRate: 16000, channels: 1, interleaved: true)
    private var format16kCh2 = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
                                                 sampleRate: 16000, channels: 2, interleaved: true)
//    private var format48kCh1 = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
//                                                  sampleRate: 48000, channels: 1, interleaved: true)
//    private var format44kCh1 = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
//                                                 sampleRate: 44100, channels: 1, interleaved: true)
    private var state: AudioEngineState = .stopped
    private var isInterrupted = false
    private var configChangePending = false
    
    private var repeatRingBuf: RingBuffer<Int16>
    private var tcpServerRingBuf: RingBuffer<Int16>
    weak var tcpSourceRingBuf: RingBuffer<Int16>?
    
    weak var tcpServer: AudioTcpServer?
    weak var tcpClient: AudioTcpClient?
    
    init() {
        repeatRingBuf = RingBuffer<Int16>(repeating: 0, count: deviceBufSize * 4)
        tcpServerRingBuf = RingBuffer<Int16>(repeating: 0, count: socketSize * 4)

        setupSession()
        setupEngine()
        registerForNotifications()
    }
    
    deinit {
        stopAudioSess()
    }
    
    private func setupSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.allowBluetoothA2DP])
        try? session.setPreferredSampleRate(sr)
        try? session.setPreferredIOBufferDuration(Double(deviceBufSize) / 48000)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func setupEngine() {
        engine = AVAudioEngine()
        
        srConverter = AVAudioConverter(from: engine.inputNode.outputFormat(forBus: 0), to: format16kCh1!)!
        micMuteMixer = AVAudioMixerNode()
        micMuteMixer.volume = 0
        tcpMuteMixer = AVAudioMixerNode()
        tcpMuteMixer.volume = 0
        
        sinkNode = AVAudioSinkNode() { [weak self] (timestamp, frames, audioBufferList) -> OSStatus in
            guard let weakself = self else {
                return noErr
            }
            if  weakself.sinkNodeBufSize == 0 {
                weakself.sinkNodeBufSize = Int(frames)
                weakself.messages.append("Device buffer: \(frames) frames")
                return noErr
            }
            
            var newBufAvailable = true
            let converterInputCallback: AVAudioConverterInputBlock = { inputPacketCount, outStatus in
                if newBufAvailable {
                    outStatus.pointee = .haveData
                    newBufAvailable = false
                    let converterInputBuf = AVAudioPCMBuffer(pcmFormat: weakself.engine.inputNode.outputFormat(forBus: 0),
                                                             bufferListNoCopy: audioBufferList)
                    return converterInputBuf
                } else {
                    outStatus.pointee = .noDataNow
                    return nil
                }
            }
            let converterOutputBuf = AVAudioPCMBuffer(pcmFormat: weakself.format16kCh1!, frameCapacity: frames)
            var error: NSError?
            let status = weakself.srConverter.convert(to: converterOutputBuf!, error: &error, withInputFrom: converterInputCallback)
            assert(status != .error)
            if converterOutputBuf != nil && converterOutputBuf!.frameLength > 0 {
                var downsampleArr = Array<Int16>(repeating: 0, count: Int(converterOutputBuf!.frameLength))
                downsampleArr.withUnsafeMutableBytes{ rawPtr in
                    memcpy(rawPtr.baseAddress, converterOutputBuf!.audioBufferList.pointee.mBuffers.mData,
                           Int(converterOutputBuf!.frameLength) * 2)
                    return
                }
                weakself.repeatRingBuf.pushBack(downsampleArr)
                weakself.tcpServerRingBuf.pushBack(downsampleArr)
            }
            
            if weakself.tcpServerRingBuf.count >= weakself.socketSize {
                DispatchQueue.global(qos: .userInitiated).async {
                    weakself.tcpServer?.prepareHeader()
                    let tmpSocketArr = weakself.tcpServerRingBuf.popFront(weakself.socketSize)
                    weakself.tcpServer?.send2Channels(tmpSocketArr)
                }
            }

            return noErr
        }
        
        micSourceNode = AVAudioSourceNode() { [weak self] (silence, timeStamp, frameCount, audioBufferList) -> OSStatus in
            guard let weakself = self else {
                return noErr
            }
            
            if weakself.repeatRingBuf.count >= frameCount {
                let tmpSoundArr = weakself.repeatRingBuf.popFront(Int(frameCount))
                let ptr = audioBufferList.pointee.mBuffers.mData
                tmpSoundArr.withUnsafeBytes{ rawPtr in
                    memcpy(ptr, rawPtr.baseAddress, Int(frameCount * 2))
                    return
                }
            }
            return noErr
        }
        
        tcpSourceNode = AVAudioSourceNode(format: format16kCh2!) { [weak self] (silence, timeStamp, frameCount, audioBufferList) -> OSStatus in
            guard let weakself = self else {
                return noErr
            }

            let ptr = audioBufferList.pointee.mBuffers.mData
            if weakself.tcpSourceRingBuf!.count < frameCount * 2 {
                weakself.firstShot = true
            }
            if (!weakself.firstShot || weakself.tcpSourceRingBuf!.count >= 160 * 2 * weakself.playerDelay) {
                let soundArray = weakself.tcpSourceRingBuf!.popFront(Int(frameCount) * 2)
                soundArray.withUnsafeBytes{ rawPointer in
                    memcpy(ptr, rawPointer.baseAddress, soundArray.count * MemoryLayout<Int16>.size)
                    return
                }
                weakself.firstShot = false
                
                // try to balance the clock diff
                if (weakself.tcpSourceRingBuf!.count > 160 * 2 * weakself.playerDelay - Int(frameCount) * 2) {
                    print(weakself.tcpSourceRingBuf!.count)
                    let _ = weakself.tcpSourceRingBuf!.popFront(2)
                }

            } else {
                silence.pointee = true
            }
            return noErr
        }
        
        engine.attach(sinkNode)
        engine.attach(micSourceNode)
        engine.attach(tcpSourceNode)
        engine.attach(micMuteMixer)
        engine.attach(tcpMuteMixer)
        
        makeConnections()
        engine.prepare()
    }
    
    private func makeConnections() {
        engine.connect(engine.inputNode, to: sinkNode, format: engine.inputNode.outputFormat(forBus: 0))
        engine.connect(micSourceNode, to: micMuteMixer, format: format16kCh1)
        engine.connect(tcpSourceNode, to: tcpMuteMixer, format: format16kCh2)
        engine.connect(micMuteMixer, to: engine.mainMixerNode, format: format16kCh2)
        engine.connect(tcpMuteMixer, to: engine.mainMixerNode, format: format16kCh2)

        self.messages.append("Audio input sr: \(Int(engine.inputNode.outputFormat(forBus: 0).sampleRate))")
        self.messages.append("Audio output sr: \(Int(engine.outputNode.inputFormat(forBus: 0).sampleRate))")
    }
    
    func startAudioSess() throws {
        if state == .started {
            return
        }
        if state == .paused {
            try? resumeAudioSess()
        } else {
            try engine.start()
            state = .started
            tcpSourceRingBuf?.removeAll()
        }
    }
    
    func resumeAudioSess() throws {
        try engine.start()
        state = .started
        tcpSourceRingBuf?.removeAll()
        firstShot = true
    }
    
    func pauseAudioSess() {
        engine.pause()
        state = .paused
    }
    
    func stopAudioSess() {
        // Remove existing taps on nodes
//        downsampleMixerNode.removeTap(onBus: 0)
        
        engine.stop()
        state = .stopped
    }
    
    func isStopped() -> Bool {
        return state == .stopped
    }
    
    func outputDeviceType() -> String {
        let routeDescription = AVAudioSession.sharedInstance().currentRoute
        if !routeDescription.outputs.filter({$0.portType == .bluetoothA2DP}).isEmpty {
            return "Bluetooth A2DP"
        } else if !routeDescription.outputs.filter({$0.portType == .headphones}).isEmpty {
            return "Wired Headphones"
        } else {
            return "Internal Speaker"
        }
    }
    
    func playEcho(_ flag: Bool) {
        micMuteMixer.volume = flag ? 1 : 0
    }
    
    func playTcpSource(_ flag: Bool) {
        tcpSourceRingBuf?.removeAll()
        tcpMuteMixer.volume = flag ? 1 : 0
    }
    
    private func registerForNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] (notification) in
            guard let weakself = self else {
                return
            }
            let userInfo = notification.userInfo
            let interruptionTypeValue: UInt = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
            let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeValue)!
            
            switch interruptionType {
            case .began:
                weakself.isInterrupted = true
                
                if weakself.state == .started {
                    weakself.pauseAudioSess()
                }
            case .ended:
                weakself.isInterrupted = false
                
                // Activate session again
                try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                
                weakself.handleConfigurationChange()
                
                if weakself.state == .paused {
                    try? weakself.resumeAudioSess()
                }
            @unknown default:
                break
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name.AVAudioEngineConfigurationChange,
            object: nil,
            queue: nil
        ) { [weak self] (notification) in
            guard let weakself = self else {
                return
            }
            
            weakself.configChangePending = true
            
            if (!weakself.isInterrupted) {
                weakself.handleConfigurationChange()
            } else {
                print("deferring changes")
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: nil
        ) { [weak self] (notification) in
            guard let weakself = self else {
                return
            }
            
            weakself.setupSession()
            weakself.setupEngine()
        }
    }
    
    func handleConfigurationChange() {
        if configChangePending {
            makeConnections()
        }
        configChangePending = false
    }
}
