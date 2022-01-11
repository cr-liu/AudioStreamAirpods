//
//  ViewModel.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/17.
//

import Foundation
import CoreMotion
import AVFoundation

class SensorViewModel: ObservableObject {
    @Published var messages: [String] = []
    
    var maxDelay = 60
    @Published var playerDelay: Int = 1
    @Published var isPlayingEcho: Bool = false
    @Published var isPlaying : Bool = false
    @Published var isRecording: Bool = false
    @Published var speakerType: String = ""
    var audioIO: AudioIO
    
    @Published var headPitch: Float = 0
    @Published var headYaw: Float = 0
    @Published var headRoll: Float = 0
    @Published var imuAvailable: Bool = false
    @Published var isUpdatingHeadMotion = false
    private var headMotionManager: CMHeadphoneMotionManager
    // private let motionUpdateQueue = DispatchQueue.global(qos: .default)
    
//    @Published var iphonePitch: Float = 0
//    @Published var iphoneYaw: Float = 0
//    @Published var iphoneRoll: Float = 0
//    @Published var iphoneAccX: Float = 0
//    @Published var iphoneAccY: Float = 0
//    @Published var iphoneAccZ: Float = 0
//    private var isUpdatingMotion: Bool = false
//    private var motionManager = CMMotionManager()
    
    @Published var listenHost: String = "LocalHost"
    @Published var listenPort: Int = 12345
    @Published var serverStarted: Bool = false
    @Published var isAntitarget: Bool = false
    var tcpServer: AudioTcpServer
    var imuData4Server: ContiguousArray<Float32>
    //    var phoneRoll: Float32 = -10000
    //    var phonePitch: Float32 = -10000
    //    var phoneYaw: Float32 = -10000
    //    var phoneAccX: Float32 = -10000
    //    var phoneAccY: Float32 = -10000
    //    var phoneAccZ: Float32 = -10000
    //    var phoneCompass: Float32 = -10000
    //    var phoneGpsN: Float32 = -10000
    //    var phoneGpsE: Float32 = -10000
    //    var calib: Float32 = -10000
    //    var headRoll: Float32 = -10000
    //    var headPitch: Float32 = -10000
    //    var headYaw: Float32 = -10000
    //    var headAccX: Float32 = -10000
    //    var headAccY: Float32 = -10000
    //    var headAccZ: Float32 = -10000
    
    @Published var connectHost: String = "192.168.1.10"
    @Published var connectPort: Int = 12345
    @Published var isConnected: Bool = false
    @Published var isStereo: Bool = true
    var tcpClient: AudioTcpClient
    var tcpClientRingBuf: RingBuffer<Int16>
    
    init() {
        audioIO = AudioIO()
        
        imuData4Server = ContiguousArray<Float32>(repeating: -10000, count: 16)
        let imuPtr = imuData4Server.withUnsafeBytes{ $0 }.baseAddress!
        tcpServer = AudioTcpServer(withImu: imuPtr)
        audioIO.tcpServer = tcpServer
        
        tcpClient = AudioTcpClient()
        audioIO.tcpClient = tcpClient
        tcpClientRingBuf = RingBuffer<Int16>(repeating: 0, count: 320 * maxDelay)
        audioIO.tcpSourceRingBuf = tcpClientRingBuf
        tcpClient.setBuffer(tcpClientRingBuf)
        
        headMotionManager = CMHeadphoneMotionManager()
        
        registerForNotifications()
        if let ifAddress = getIPAddress() {
            listenHost = ifAddress
            tcpServer.host = ifAddress
        }
        collectMessage()
    }
    
    deinit {
        if serverStarted { stopTcpServer() }
        if isRecording { stopAudioSess() }
    }
    
    func registerForNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] (notification) in
            guard let weakself = self else {
                return
            }
            weakself.stopAudioSess()
            weakself.checkIMU()
        }
    }
    

    // Message
    func addMessage(_ msg: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        self.messages.append(msg + " -- " + dateFormatter.string(from: Date()))
    }
    
    func collectMessage() {
        if !audioIO.messages.isEmpty {
            for msg in audioIO.messages {
                addMessage(msg)
            }
            audioIO.messages = []
        }
        if !tcpServer.messages.isEmpty {
            for msg in tcpServer.messages {
                addMessage(msg)
            }
            tcpServer.messages = []
        }
        if !tcpServer.h16D320Ch1Handler.messages.isEmpty {
            for msg in tcpServer.h16D320Ch1Handler.messages {
                addMessage(msg)
            }
            tcpServer.h16D320Ch1Handler.messages = []
        }
        if !tcpServer.h80D10ms16kHandler.messages.isEmpty {
            for msg in tcpServer.h80D10ms16kHandler.messages {
                addMessage(msg)
            }
            tcpServer.h80D10ms16kHandler.messages = []
        }
        if listenHost == "LocalHost" {
            if let ifAddress = getIPAddress() {
                listenHost = ifAddress
                tcpServer.host = ifAddress
            }
        }
        if !tcpClient.messages.isEmpty {
            for msg in tcpClient.messages {
                addMessage(msg)
            }
            tcpClient.messages = []
            isConnected = tcpClient.isConnected
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: collectMessage)
//        print("test...")
    }
    
    
    // Audio input/output
    func startAudioSess() {
        if isRecording {
            return
        }
        guard let _ = try? audioIO.startAudioSess() else {
            addMessage("Failed start audio session!")
            return
        }
        isRecording = true
        addMessage("Audio session started.")
    }
    
    func pauseAudioSess() {
        audioIO.pauseAudioSess()
        isRecording = false
        addMessage("Audio session paused.")
    }
    
    func stopAudioSess() {
        if audioIO.isStopped() {
            return
        }
        audioIO.stopAudioSess()
        isRecording = false
        addMessage("Audio session stopped.")
    }
    
    func playTcpSource() {
        isPlaying.toggle()
        audioIO.playTcpSource(isPlaying)
    }
    
    func playEcho() {
        isPlayingEcho.toggle()
        audioIO.playEcho(isPlayingEcho)
    }
    
    func playerDelayChanged(to newDelay: Int) {
        if (newDelay < 1 || newDelay > maxDelay) {
            audioIO.playerDelay = 1
        } else {
            audioIO.playerDelay = newDelay
        }
    }
    

    // Headset IMU
    func checkIMU() {
        speakerType = audioIO.outputDeviceType()
        imuAvailable = headMotionManager.isDeviceMotionAvailable && speakerType == "Bluetooth A2DP"
    }
    
    func startHeadMotionUpdate() {
        checkIMU()
        guard imuAvailable, !isUpdatingHeadMotion else {
            return
        }

        addMessage("Start Motion Update")
        isUpdatingHeadMotion = true
        headMotionManager.startDeviceMotionUpdates(to: OperationQueue.current!) { [weak self] (motion, error) in
            guard let weakself = self else {
                return
            }
            if let error = error {
                DispatchQueue.main.async {
                    weakself.addMessage("\(error)")
                }
            }

            if let motion = motion {
                weakself.updateMotionData(motion)
            }
        }
    }
    
    func stopMotionUpdate() {
        guard headMotionManager.isDeviceMotionAvailable,
              isUpdatingHeadMotion else {
            return
        }
        addMessage("Stop Motion Update")
        isUpdatingHeadMotion = false
        headMotionManager.stopDeviceMotionUpdates()
    }
    
    func updateMotionData(_ motion: CMDeviceMotion) {
        let attitude = motion.attitude
        let acceleration = motion.userAcceleration
        DispatchQueue.main.async {
            (self.headPitch, self.headYaw, self.headRoll)
            = (-Float(attitude.pitch), Float(attitude.yaw), Float(-attitude.roll))
            (self.imuData4Server[10], self.imuData4Server[11], self.imuData4Server[12])
            = (Float32(attitude.roll), Float32(attitude.pitch), Float32(attitude.yaw))
            (self.imuData4Server[13], self.imuData4Server[14], self.imuData4Server[15])
            = (Float32(acceleration.x), Float32(acceleration.y), Float32(acceleration.z))
        }
    }
    

    // Phone IMU
    


    // TCP server
    func getIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { return nil }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {

                    // wifi = ["en0"]
                    // wired = ["en2", "en3", "en4"]
                    // cellular = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]

                    let name: String = String(cString: (interface.ifa_name))
                    if  name == "en0" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t((interface.ifa_addr.pointee.sa_len)),
                                    &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
    
    func listenPortChanged(to port: Int) {
        tcpServer.port = port
        if serverStarted {
            stopTcpServer()
        }
    }
    
    func startTcpServer() {
        tcpServer.asyncRun()
        serverStarted = true
        addMessage("TCP server started and listen on port: \(tcpServer.port).")
    }
    
    func stopTcpServer() {
        tcpServer.shutdown()
        serverStarted = false
        addMessage("TCP server closed.")
    }
    
    func makeAntitarget() {
        isAntitarget.toggle()
        tcpServer.h16D320Ch1Handler.isAntitarget = isAntitarget
    }
    

    // TCP client
    func connectHostChanged(to host: String) {
        tcpClient.host = host
        if isConnected {
            tcpClient.stop()
        }
    }
    
    func connectPortChanged(to port: Int) {
        tcpClient.port = port
    }
    
    func startConnection() {
        tcpClient.AsyncStart()
        addMessage("Try connect to \(connectHost):\(connectPort)")
        startAudioSess()
    }
    
    func closeConnection() {
        tcpClient.stop()
        isConnected = false
    }
    
    func channelNumberChanged() {
        isStereo.toggle()
        tcpClient.h80D10ms16kHandler.audioChannels = isStereo ? 2 : 1
        addMessage(isStereo ? "Expecting 2ch sound" : "Expecting 1ch sound")
    }
}

