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
    private var engine: AVAudioEngine!
    private var muteMixerNode: AVAudioMixerNode!
    private var sinkNode: AVAudioSinkNode!
    private var micSourceNode: AVAudioSourceNode!
    
    private var deviceBufLength: Int = 32
    private var deviceBufWarning: Bool = false
    private var sr: Double = 48000
    private var bufferLength = Int(48000 * 0.01)
    private var socketLength = Int(16000 * 0.01)
    private var sinkBuffer1: ContiguousArray<Int16>
    private var sinkBuffer2: ContiguousArray<Int16>
    private var bufWritingPosition: Int = 0
    private var usingBuffer2: Bool = false
    private var socketBuffer: ContiguousArray<Int16>
//    private var sourceNodeBuffer: Data
    private var micSourceNodeBuffer: ContiguousArray<Int16>
    private var format48kCh1 = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
                                                  sampleRate: 48000, channels: 1, interleaved: true)
    private var format16kCh1 = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
                                                 sampleRate: 16000, channels: 1, interleaved: true)
    private var format44kCh1 = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
                                                 sampleRate: 44100, channels: 1, interleaved: true)
    private var formatConverter: AVAudioConverter!
    private var state: AudioEngineState = .stopped
    private var isInterrupted = false
    private var configChangePending = false
    
    weak var tcpServer: AudioTcpServer?
    
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
        stopRecording()
    }
    
    private func setupSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.allowBluetoothA2DP])
        
        try? session.setPreferredIOBufferDuration(Double(deviceBufLength) / sr)
        try? session.setPreferredSampleRate(sr)

        try? session.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func setupEngine() {
        engine = AVAudioEngine()

        muteMixerNode = AVAudioMixerNode()
        muteMixerNode.volume = 0
        sinkNode = AVAudioSinkNode() { [weak self] (timestamp, frames, audioBufferList) -> OSStatus in
            guard let weakself = self else {
                return noErr
            }
            let ptr = audioBufferList.pointee.mBuffers.mData
            let micSourceBufferPtr = weakself.micSourceNodeBuffer.withUnsafeMutableBytes { $0 }
            memcpy(micSourceBufferPtr.baseAddress, ptr, Int(frames * 2))
            
            if weakself.bufWritingPosition == 0 {
                weakself.tcpServer?.prepareHeader()
            }
            let copyLength = weakself.bufferLength - weakself.bufWritingPosition - Int(frames)
            switch copyLength {
            case _ where copyLength > 0:
                if weakself.usingBuffer2 {
                    memcpy(&(weakself.sinkBuffer2[weakself.bufWritingPosition]), ptr, Int(frames * 2))
                } else {
                    memcpy(&(weakself.sinkBuffer1[weakself.bufWritingPosition]), ptr, Int(frames * 2))
                }
                weakself.bufWritingPosition += Int(frames)
                
            case _ where copyLength == 0:
                if weakself.usingBuffer2 {
                    memcpy(&(weakself.sinkBuffer2[weakself.bufWritingPosition]), ptr, Int(frames * 2))
                    for index in 0..<weakself.socketLength {
                        weakself.socketBuffer[index] = Int16((Int32(weakself.sinkBuffer2[index * 3])
                                                            + Int32(weakself.sinkBuffer2[index * 3 + 1])
                                                            + Int32(weakself.sinkBuffer2[index * 3 + 2])) / 3)
                    }
                } else {
                    memcpy(&(weakself.sinkBuffer1[weakself.bufWritingPosition]), ptr, Int(frames * 2))
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
                    memcpy(&(weakself.sinkBuffer2[weakself.bufWritingPosition]), ptr, (Int(frames) + copyLength) * 2)
                    memcpy(&(weakself.sinkBuffer1[0]), ptr! + Int(frames) + copyLength, -copyLength * 2)
                } else {
                    memcpy(&(weakself.sinkBuffer1[weakself.bufWritingPosition]), ptr, (Int(frames) + copyLength) * 2)
                    memcpy(&(weakself.sinkBuffer2[0]), ptr! + Int(frames) + copyLength, -copyLength * 2)
                }
                weakself.bufWritingPosition = -copyLength
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
            weakself.micSourceNodeBuffer.withUnsafeMutableBufferPointer { rawBufferPointer in
                memcpy(ptr, rawBufferPointer.baseAddress, Int(frameCount * 2))
                return
            }
//            weakself.sourceNodeBuffer.withUnsafeMutableBytes { rawBufferPointer in
//                memcpy(ptr, rawBufferPointer, Int(frameCount * 2))
//            }
//            let srcBuf = self.sourceNodeBuffer.int16ChannelData!
//            memcpy(ptr, UnsafeMutableRawPointer(mutating: self.sourceNodeBuffer.int16ChannelData), Int(frameCount * 2))
            return noErr
        }
        formatConverter = AVAudioConverter(from: engine.inputNode.outputFormat(forBus: 0), to: format16kCh1!)
        
        // Set volume to 0 to avoid audio feedback while recording.
        //        mixerNode.volume = 0
        engine.attach(muteMixerNode)
        engine.attach(sinkNode)
        engine.attach(micSourceNode)
        
        makeConnections()
        engine.prepare()
    }
    
    private func makeConnections() {
//        engine.connect(engine.inputNode, to: downsampleMixerNode, format: format48kCh1)
        engine.connect(engine.inputNode, to: sinkNode, format: format48kCh1)
//        engine.inputNode.installTap(onBus: 0, bufferSize: 2400, format: nil) {
//            buffer, time in
//            print(buffer.frameLength)
//        }
        engine.connect(micSourceNode, to: muteMixerNode, format: format48kCh1)
//        muteMixerNode.installTap(onBus: 0, bufferSize: 2400, format: nil) {
//            buffer, time in
//            print(buffer.format.description)
//            print(self.engine.mainMixerNode.outputFormat(forBus: 0).description)
//        }
        engine.connect(muteMixerNode, to: engine.mainMixerNode, format: format48kCh1)
    }
    
    func startRecording() throws {
        if state == .paused {
            try? resumeRecording()
        } else {
//            let tapNode: AVAudioNode = downsampleMixerNode
//            let format = tapNode.outputFormat(forBus: 0)
//
//            tapNode.installTap(onBus: 0, bufferSize: 4096, format: format, block: {
//                (buffer, time) in
//                // Do something here
//            })
            
            try engine.start()
            state = .started
        }
    }
    
    func resumeRecording() throws {
        try engine.start()
        state = .started
    }
    
    func pauseRecording() {
        engine.pause()
        state = .paused
    }
    
    func stopRecording() {
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
        if flag {
            muteMixerNode.volume = 1
        } else {
            muteMixerNode.volume = 0
        }
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
                    weakself.pauseRecording()
                }
            case .ended:
                weakself.isInterrupted = false
                
                // Activate session again
                try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                
                weakself.handleConfigurationChange()
                
                if weakself.state == .paused {
                    try? weakself.resumeRecording()
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
