//
//  HeadMotionScene.swift
//  AudioStreamAirpods
//
//  Created by liu on 2021/05/14.
//

import SwiftUI
import SceneKit

struct HeadMotionScene: View {
    @EnvironmentObject var headmotionVM: HeadmotionViewModel
    
    var body: some View {
//        SceneView(scene: headmotionVM.scene, options: [.autoenablesDefaultLighting, .allowsCameraControl])
        SceneKitView()
            .onAppear(perform: {
                headmotionVM.startMotionUpdate()
            })
    }
}

struct HeadMotionScene_Previews: PreviewProvider {
    static var previews: some View {
        HeadMotionScene()
            .environmentObject(HeadmotionViewModel())
    }
}

struct SceneKitView: UIViewRepresentable {
    @EnvironmentObject var headmotionVM: HeadmotionViewModel

    typealias UIViewType = SCNView

    func makeUIView(context: Context) -> SCNView {
        print("setup scene...")
        
        let scnView = SCNView()
        
        // Add camera node
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 30, z: 25)
        headmotionVM.scene?.rootNode.addChildNode(cameraNode)

        // Adding light to scene
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 45, z: 35)
        lightNode.light?.intensity = 3000
        headmotionVM.scene?.rootNode.addChildNode(lightNode)

        // Creating and adding ambien light to scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = UIColor.darkGray
        headmotionVM.scene?.rootNode.addChildNode(ambientLightNode)

        // Allow user to manipulate camera
        scnView.allowsCameraControl = true

        // Show FPS logs and timming
        // scnView.showsStatistics = true

        // Set background color
        scnView.backgroundColor = UIColor.clear

        // Allow user translate image
        scnView.cameraControlConfiguration.allowsTranslation = false

        // Set scene settings
        scnView.scene = headmotionVM.scene
        
        return scnView
    }
    func updateUIView(_ uiView: SCNView, context: Context) {
    }
}
