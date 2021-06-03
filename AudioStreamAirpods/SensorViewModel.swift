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
    init() {
        registerForNotifications()
        if let ifAddress = getIPAddress() {
            listenHost = ifAddress
            tcpServer.host = ifAddress
        }
        audioIO.tcpServer = tcpServer
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
    
    @Published var messages: [String] = []
    
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
    
    @Published var isPlayingEcho: Bool = false
    @Published var isPlaying : Bool = false
    @Published var isRecording: Bool = false
    @Published var speakerType: String = ""
    var audioIO = AudioIO()

    func startAudioSess() {
        guard let _ = try? audioIO.startRecording() else {
            addMessage("Failed start audio session!")
            return
        }
        isRecording = true
        addMessage("Audio session started.")
    }
    
    func pauseAudioSess() {
        audioIO.pauseRecording()
        isRecording = false
        addMessage("Audio session paused.")
    }
    
    func stopAudioSess() {
        if audioIO.isStopped() {
            return
        }
        audioIO.stopRecording()
        isRecording = false
        addMessage("Audio session stopped.")
    }
    
    func playEcho() {
        isPlayingEcho.toggle()
        audioIO.playEcho(isPlayingEcho)
    }
    
    @Published var headPitch: Float = 0
    @Published var headYaw: Float = 0
    @Published var headRoll: Float = 0
    @Published var imuAvailable: Bool = false
    @Published var isUpdatingHeadMotion = false
    private var headMotionManager = CMHeadphoneMotionManager()
    private let motionUpdateQueue = DispatchQueue.global(qos: .default)

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
        headMotionManager.startDeviceMotionUpdates(to: motionUpdateQueue) { [weak self] (motion, error) in
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
        DispatchQueue.main.async {
            (self.headPitch, self.headYaw, self.headRoll) = (-Float(attitude.pitch), Float(attitude.yaw), Float(-attitude.roll))
        }
    }
    
    @Published var iphonePitch: Float = 0
    @Published var iphoneYaw: Float = 0
    @Published var iphoneRoll: Float = 0
    @Published var iphoneAccX: Float = 0
    @Published var iphoneAccY: Float = 0
    @Published var iphoneAccZ: Float = 0
    private var isUpdatingMotion: Bool = false
    private var motionManager = CMMotionManager()
    
    

    @Published var listenHost: String = "LocalHost"
    @Published var listenPort: Int = 12345
    @Published var serverStarted: Bool = false
    @Published var isAntitarget: Bool = false
    var tcpServer = AudioTcpServer()
    
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
    
    @Published var connectHost: String = "192.168.1.10"
    @Published var connectPort: Int = 12345
    @Published var isConnected: Bool = false
    var tcpClient = AudioTcpClient()
    
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
    }
    
    func closeConnection() {
        tcpClient.stop()
        isConnected = false
    }
    

}

