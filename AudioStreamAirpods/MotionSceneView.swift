//
//  HeadMotionScene.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/14.
//

import SwiftUI
import SceneKit

struct MotionSceneView: View {
    @EnvironmentObject var sensorVM: SensorViewModel
    
    var body: some View {
//        SceneView(scene: sensorVM.scene, options: [.autoenablesDefaultLighting, .allowsCameraControl])
        SceneKitView()
            .onAppear(perform: {
                sensorVM.startMotionUpdate()
            })
            .onDisappear(perform: {
                sensorVM.stopMotionUpdate()
            })
    }
}

struct MotionScene_Previews: PreviewProvider {
    static var previews: some View {
        MotionSceneView()
            .environmentObject(SensorViewModel())
            .environmentObject(RobotScene())
    }
}

struct SceneKitView: UIViewRepresentable {
    @EnvironmentObject var sensorVM: SensorViewModel
    @EnvironmentObject var robot: RobotScene
    
    typealias UIViewType = SCNView

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        
        // Add camera node
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 30, z: 25)
//        headmotionVM.scene?.rootNode.addChildNode(cameraNode)
        robot.scene?.rootNode.addChildNode(cameraNode)

        // Adding light to scene
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 45, z: 35)
        lightNode.light?.intensity = 3000
//        headmotionVM.scene?.rootNode.addChildNode(lightNode)
        robot.scene?.rootNode.addChildNode(lightNode)

        // Creating and adding ambien light to scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = UIColor.darkGray
//        headmotionVM.scene?.rootNode.addChildNode(ambientLightNode)
        robot.scene?.rootNode.addChildNode(ambientLightNode)

        // Allow user to manipulate camera
        scnView.allowsCameraControl = true

        // Show FPS logs and timming
        // scnView.showsStatistics = true

        // Set background color
        scnView.backgroundColor = UIColor.clear

        // Allow user translate image
        scnView.cameraControlConfiguration.allowsTranslation = false

        // Set scene settings
//        scnView.scene = headmotionVM.scene
        scnView.scene = robot.scene
        
        return scnView
    }
    func updateUIView(_ uiView: SCNView, context: Context) {
        robot.head?.eulerAngles = SCNVector3(sensorVM.pitch, sensorVM.yaw, sensorVM.roll)
    }
}


