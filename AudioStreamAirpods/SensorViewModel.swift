//
//  ViewModel.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/17.
//

import Foundation
import CoreMotion

class SensorViewModel: ObservableObject {
    @Published var pitch: Float = 0
    @Published var yaw: Float = 0
    @Published var roll: Float = 0
    @Published var imuAvailable: Bool = false
    @Published var messages: [String] = []


    private lazy var motionManager = CMHeadphoneMotionManager()
    private var isUpdating = false
    
    func isIMUAvaible() -> Bool {
        return motionManager.isDeviceMotionAvailable
    }

    func checkIMU() {
        imuAvailable = motionManager.isDeviceMotionAvailable
    }
    
    func startMotionUpdate() {
        checkIMU()
        guard imuAvailable, !isUpdating else {
            return
        }
        
//        let queue = OperationQueue()
//        queue.name = "airpods.headmotion"
//        queue.qualityOfService = .userInteractive
//        queue.maxConcurrentOperationCount = 1

        addMessage("Start Motion Update")
        isUpdating = true
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            if let error = error {
                self?.addMessage("\(error)")
            }

            if let motion = motion {
                self?.updateMotionData(motion)
            }
        }
    }
    
    func stopMotionUpdate() {
        guard motionManager.isDeviceMotionAvailable,
              isUpdating else {
            return
        }
        addMessage("Stop Motion Update")
        isUpdating = false
        motionManager.stopDeviceMotionUpdates()
    }
    
    func updateMotionData(_ motion: CMDeviceMotion) {
        let attitude = motion.attitude
        (self.pitch, self.yaw, self.roll) = (-Float(attitude.pitch), Float(attitude.yaw), Float(-attitude.roll))
    }
    
    func addMessage(_ msg: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        self.messages.append(msg + " -- " + dateFormatter.string(from: Date()))
    }
    
    @Published var repeatMic: Bool = false
    @Published var isPlaying : Bool = false
    @Published var isRecording: Bool = false
    @Published var isAntitarget: Bool = false
    @Published var speakerType: String = ""
    private lazy var audioIO = AudioIO()

    func startAudioSess() {
        guard let _ = try? audioIO.startRecording() else {
            addMessage("Failed start audio session!")
            return
        }
        speakerType = audioIO.outputDeviceType()
        addMessage("Audio session started.")
    }
    
    func pauseAudioSess() {
        audioIO.pauseRecording()
        addMessage("Audio session paused.")
    }
    
    func stopAudioSess() {
        audioIO.stopRecording()
        addMessage("Audio session stopped.")
    }
    
    @Published var connectHost: String = "192.168.1.10"
    @Published var connectPort: Int = 12345
    @Published var isConnected: Bool = false
    @Published var listenHost: String = "LocalAudioHost"
    @Published var listenPort: Int = 12345
    @Published var serverStarted: Bool = false
}
