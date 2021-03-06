//
//  RobotScene.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/21.
//

import Foundation
import SceneKit

class RobotScene: ObservableObject {
    var scene: SCNScene?
    var head: SCNNode?
    
    init() {
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
}
