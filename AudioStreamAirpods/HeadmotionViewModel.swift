//
//  ViewModel.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/17.
//

import Foundation
import CoreMotion
import SwiftUI
import SceneKit

class HeadmotionViewModel: ObservableObject {
    @Published var pitch: Float = 0
    @Published var yaw: Float = 0
    @Published var roll: Float = 0
    @Published var imuAvailable: Bool = false
    
    private lazy var motionManager = CMHeadphoneMotionManager()
    private var isUpdating = false
    
    var scene: SCNScene?
    var head: SCNNode?
    
    init() {
        print("init robot scene...")
        guard let url = Bundle.main.url(forResource: "toy_robot_vintage", withExtension: "usdz") else { fatalError() }
        self.scene = try? SCNScene(url: url, options: [.checkConsistency: true])
        
        let robot = scene?.rootNode.childNode(withName: "vintage_robot_animRig_model_Hips_NUL", recursively: true)
        let body = robot?.childNode(withName: "vintage_robot_animRig_model_Body_NUL", recursively: true)
        let bodyPlayer = body?.animationPlayer(forKey: "transform")
        bodyPlayer!.stop()
        
        let leftLeg = robot?.childNode(withName: "vintage_robot_animRig_model_LeftUpLeg_NUL", recursively: true)
        let leftLegPlayer = leftLeg?.animationPlayer(forKey: "transform")
        leftLegPlayer?.stop()
        
        let rightLeg = robot?.childNode(withName: "vintage_robot_animRig_model_RightUpLeg_NUL", recursively: true)
        let rightLegPlayer = rightLeg?.animationPlayer(forKey: "transform")
        rightLegPlayer?.stop()
        
        let leftFoot = robot?.childNode(withName: "vintage_robot_animRig_model_LeftFoot_NUL", recursively: true)
        let leftFootPlayer = leftFoot?.animationPlayer(forKey: "transform")
        leftFootPlayer?.stop()
        
        let rightFoot = robot?.childNode(withName: "vintage_robot_animRig_model_RightFoot_NUL", recursively: true)
        let rightFootPlayer = rightFoot?.animationPlayer(forKey: "transform")
        rightFootPlayer?.stop()
        
        let neck = robot?.childNode(withName: "vintage_robot_animRig_model_Neck_NUL", recursively: true)
        let neckPlayer = neck?.animationPlayer(forKey: "transform")
        neckPlayer?.stop()
        
        self.head = robot?.childNode(withName: "vintage_robot_animRig_model_Head_NUL", recursively: true)
        let headPlayer = head?.animationPlayer(forKey: "transform")
        headPlayer?.stop()
    }
    
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
        
        print("Start Motion Update")
        isUpdating = true
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            if let error = error {
                print("\(error)")
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
        print("Stop Motion Update")
        isUpdating = false
        motionManager.stopDeviceMotionUpdates()
    }
    
    func updateMotionData(_ motion: CMDeviceMotion) {
        let attitude = motion.attitude
        (self.pitch, self.yaw, self.roll) = (-Float(attitude.pitch), -Float(attitude.yaw), Float(-attitude.roll))
        head?.eulerAngles = SCNVector3(self.pitch, self.yaw, self.roll)
    }
}
