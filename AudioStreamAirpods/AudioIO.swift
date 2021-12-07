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
    private var inputMixerNode: AVAudioMixerNode! // convert hardware sr
    private var micMixerNode: AVAudioMixerNode!
    private var tcpMixerNode: AVAudioMixerNode!
    
    private var deviceBufLength: Int = 32
    private var deviceBufWarning: Bool = false
    private var sr: Double = 16000
    private var bufferLength = Int(48000 * 0.01)
    private var socketLength = Int(16000 * 0.01)
    private var sinkBuffer1: ContiguousArray<Int16>
    private var sinkBuffer2: ContiguousArray<Int16>
    private var bufWritingPosition: Int = 0
    private var usingBuffer2: Bool = false
    private var socketBuffer: ContiguousArray<Int16>
    
    private var micSourceNodeBuffer: ContiguousArray<Int16>
    private var tcpSourcePreviousFrame: Int16 = 0
    private var tcpSourceOneThirdDiff: Int16 = 0
    private var tcpSourceResidual: Int = 0
    
    private var format48kCh1 = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
                                                  sampleRate: 48000, channels: 1, interleaved: true)
    private var format16kCh1 = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
                                                 sampleRate: 16000, channels: 1, interleaved: true)
    private var format16kCh2 = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
                                                 sampleRate: 16000, channels: 2, interleaved: true)
    private var format44kCh1 = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
                                                 sampleRate: 44100, channels: 1, interleaved: true)
//    private var formatConverter: AVAudioConverter!
    private var state: AudioEngineState = .stopped
    private var isInterrupted = false
    private var configChangePending = false
    
    weak var tcpServer: AudioTcpServer?
    weak var tcpClient: AudioTcpClient?
    weak var tcpSourceNodeBuffer: RingBuffer<Int16>?
    
    init() {
        sinkBuffer1 = ContiguousArray<Int16>(repeating: 0, count: bufferLength)
        sinkBuffer2 = ContiguousArray<Int16>(repeating: 0, count: bufferLength)
        socketBuffer = ContiguousArray<Int16>(repeating: 0, count: socketLength)
        micSourceNodeBuffer = ContiguousArray<Int16>(repeating: 0, count: deviceBufLength)

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
        try? session.setPreferredIOBufferDuration(Double(deviceBufLength) / sr)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func setupEngine() {
        engine = AVAudioEngine()
        
        inputMixerNode = AVAudioMixerNode()
        micMixerNode = AVAudioMixerNode()
        micMixerNode.volume = 0
        tcpMixerNode = AVAudioMixerNode()
        tcpMixerNode.volume = 0
        
        sinkNode = AVAudioSinkNode() { [weak self] (timestamp, frames, audioBufferList) -> OSStatus in
            guard let weakself = self else {
                return noErr
            }
            let ptr = audioBufferList.pointee.mBuffers.mData
            print(Int(frames))

            let micBufferPtr = weakself.micSourceNodeBuffer.withUnsafeMutableBytes { $0 }
            memcpy(micBufferPtr.baseAddress, ptr, Int(frames * 2))
            
            if weakself.bufWritingPosition == 0 {
                weakself.tcpServer?.prepareHeader()
            }
            let availableCapacity = weakself.bufferLength - weakself.bufWritingPosition - Int(frames)
            switch availableCapacity {
            case _ where availableCapacity > 0:
                if weakself.usingBuffer2 {
                    memcpy(&(weakself.sinkBuffer2[weakself.bufWritingPosition]), ptr, Int(frames * 2))
                } else {
                    memcpy(&(weakself.sinkBuffer1[weakself.bufWritingPosition]), ptr, Int(frames * 2))
                }
                weakself.bufWritingPosition += Int(frames)
                
            case _ where availableCapacity == 0:
                if weakself.usingBuffer2 {
                    memcpy(&(weakself.sinkBuffer2[weakself.bufWritingPosition]), ptr, Int(frames * 2))
//                    weakself.socketBuffer = weakself.sinkBuffer2
                    for index in 0..<weakself.socketLength {
                        weakself.socketBuffer[index] = Int16((Int32(weakself.sinkBuffer2[index * 3])
                                                            + Int32(weakself.sinkBuffer2[index * 3 + 1])
                                                            + Int32(weakself.sinkBuffer2[index * 3 + 2])) / 3)
                    }
                } else {
//                    memcpy(&(weakself.sinkBuffer1[weakself.bufWritingPosition]), ptr, Int(frames * 2))
//                    weakself.socketBuffer = weakself.sinkBuffer1
                    for index in 0..<weakself.socketLength {
                        weakself.socketBuffer[index] = Int16((Int32(weakself.sinkBuffer1[index * 3])
                                                            + Int32(weakself.sinkBuffer1[index * 3 + 1])
                                                            + Int32(weakself.sinkBuffer1[index * 3 + 2])) / 3)
                    }
                }
                weakself.bufWritingPosition = 0
                weakself.tcpServer?.send2Channels(weakself.socketBuffer)
                weakself.usingBuffer2.toggle()
                
            default:
                weakself.messages.append("This should never happen! Check device buffer length!")
                if weakself.usingBuffer2 {
                    memcpy(&(weakself.sinkBuffer2[weakself.bufWritingPosition]), ptr, (Int(frames) + availableCapacity) * 2)
                    memcpy(&(weakself.sinkBuffer1[0]), ptr! + Int(frames) + availableCapacity, -availableCapacity * 2)
                } else {
                    memcpy(&(weakself.sinkBuffer1[weakself.bufWritingPosition]), ptr, (Int(frames) + availableCapacity) * 2)
                    memcpy(&(weakself.sinkBuffer2[0]), ptr! + Int(frames) + availableCapacity, -availableCapacity * 2)
                }
                weakself.bufWritingPosition = -availableCapacity
                // prepare socket here
                weakself.usingBuffer2.toggle()
            }
            return noErr
        }
        
        micSourceNode = AVAudioSourceNode() { [weak self] (silence, timeStamp, frameCount, audioBufferList) -> OSStatus in
            guard let weakself = self else {
                return noErr
            }
            if frameCount != weakself.deviceBufLength {
                weakself.messages.append("Device buffer length is \(frameCount)!!!")
            }
            
            let ptr = audioBufferList.pointee.mBuffers.mData
            weakself.micSourceNodeBuffer.withUnsafeBytes { rawBufferPointer in
                memcpy(ptr, rawBufferPointer.baseAddress, Int(frameCount * 2))
                return
            }
            return noErr
        }
        
        tcpSourceNode = AVAudioSourceNode() { [weak self] (silence, timeStamp, frameCount, audioBufferList) -> OSStatus in
            guard let weakself = self else {
                return noErr
            }
            if frameCount != weakself.deviceBufLength {
                weakself.messages.append("Device buffer length is \(frameCount)!!!")
                return noErr
            }
            let ptr = audioBufferList.pointee.mBuffers.mData
            if weakself.tcpSourceNodeBuffer!.count < frameCount {
//                print(weakself.tcpSourceNodeBuffer!.count())
                weakself.firstShot = true
            }
            if (!weakself.firstShot || weakself.tcpSourceNodeBuffer!.count >= 480 * weakself.playerDelay) {
                let soundArray = weakself.tcpSourceNodeBuffer!.popFront(Int(frameCount))
                soundArray.withUnsafeBytes{ rawPointer in
                    memcpy(ptr, rawPointer.baseAddress, Int(frameCount * 2))
                    return
                }
                weakself.firstShot = false
            }
            return noErr
        }

//        formatConverter = AVAudioConverter(from: engine.inputNode.outputFormat(forBus: 0), to: format16kCh1!)
        
        engine.attach(sinkNode)
        engine.attach(inputMixerNode)
        engine.attach(micSourceNode)
        engine.attach(tcpSourceNode)
        engine.attach(micMixerNode)
        engine.attach(tcpMixerNode)
        
        makeConnections()
        engine.prepare()
    }
    
    private func makeConnections() {
//        engine.connect(engine.inputNode, to: downsampleMixerNode, format: format48kCh1)
        engine.connect(engine.inputNode, to: inputMixerNode, format: engine.inputNode.outputFormat(forBus: 0))
        engine.connect(inputMixerNode, to: sinkNode, format: format48kCh1)
        
        engine.connect(micSourceNode, to: micMixerNode, format: format16kCh1)
        engine.connect(tcpSourceNode, to: tcpMixerNode, format: format16kCh1)
        engine.connect(micMixerNode, to: engine.mainMixerNode, format: format16kCh1)
        engine.connect(tcpMixerNode, to: engine.mainMixerNode, format: format16kCh1)

        print(engine.inputNode.inputFormat(forBus: 0).sampleRate)
        print(engine.inputNode.outputFormat(forBus: 0).sampleRate)
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
            tcpSourceNodeBuffer?.removeAll()
        }
    }
    
    func resumeAudioSess() throws {
        try engine.start()
        state = .started
        tcpSourceNodeBuffer?.removeAll()
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
        micMixerNode.volume = flag ? 1 : 0
    }
    
    func playTcpSource(_ flag: Bool) {
        tcpMixerNode.volume = flag ? 1 : 0
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
