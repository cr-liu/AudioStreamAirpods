//
//  AudioRecorder.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/13.
//

import AVFoundation

class AudioIO: ObservableObject {
    enum AudioEngineState {
        case started, paused, stopped
    }
    
    private var engine: AVAudioEngine!
    private var mixerNode: AVAudioMixerNode!
    private var state: AudioEngineState = .stopped
    private var isInterrupted = false
    private var configChangePending = false
    
    weak var tcpServer: AudioTcpServer?
    
    init() {
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
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func setupEngine() {
        engine = AVAudioEngine()
        mixerNode = AVAudioMixerNode()
        
        // Set volume to 0 to avoid audio feedback while recording.
        //        mixerNode.volume = 0
        engine.attach(mixerNode)
        
        makeConnections()
        engine.prepare()
    }
    
    private func makeConnections() {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        engine.connect(inputNode, to: mixerNode, format: inputFormat)
        
        let mainMixerNode = engine.mainMixerNode
        let mixerFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: inputFormat.sampleRate, channels: 1, interleaved: false)
        engine.connect(mixerNode, to: mainMixerNode, format: mixerFormat)
    }
    
    func startRecording() throws {
        if state == .paused {
            try? resumeRecording()
        } else {
            let tapNode: AVAudioNode = mixerNode
            let format = tapNode.outputFormat(forBus: 0)
            
            tapNode.installTap(onBus: 0, bufferSize: 4096, format: format, block: {
                (buffer, time) in
                // Do something here
            })
            
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
        mixerNode.removeTap(onBus: 0)
        
        engine.stop()
        state = .stopped
    }
    
    func outputDeviceType() -> String {
        let routeDescription = AVAudioSession.sharedInstance().currentRoute
        if !routeDescription.outputs.filter({$0.portType == .bluetoothA2DP}).isEmpty {
            return "Bluetooth A2DP"
        } else {
            return "Internal Speaker"
        }
    }
    
    private func registerForNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] (notification) in
            guard let weakself = self else {
                return
            }
            weakself.stopRecording()
            weakself.state = .stopped
        }
        
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
                
                //                weakself.handleConfigurationChange()
                
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
    
    private func handleConfigurationChange() {
        if configChangePending {
            makeConnections()
        }
        configChangePending = false
    }
}
