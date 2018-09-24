//
//  ViewController.swift
//  test180922ar
//
//  Created by 有本淳吾 on 2018/09/22.
//  Copyright © 2018 有本淳吾. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

public var textNode : SCNNode?

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: VirtualObjectARView!
    lazy var virtualObjectInteraction = VirtualObjectInteraction(sceneView: sceneView)
    var screenCenter: CGPoint {
        let bounds = sceneView.bounds
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }

    /// A serial queue used to coordinate adding or removing nodes from the scene.
    let updateQueue = DispatchQueue(label: "com.example.apple-samplecode.arkitexample.serialSceneKitQueue")
    var plane: Plane?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
//        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    
    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        if plane == nil {
            plane = Plane(anchor: planeAnchor)
            virtualObjectInteraction.translate(plane!, basedOn: screenCenter, infinitePlane: false, allowAnimation: false)
            
            updateQueue.async {
                self.sceneView.scene.rootNode.addChildNode(self.plane!)
                self.sceneView.addOrUpdateAnchor(for: self.plane!)
            }
//            plane = Plane(anchor: planeAnchor)
//            node.addChildNode(plane!)
            
//            virtualObjectInteraction.translate(plane!, basedOn: screenCenter!, infinitePlane: false, allowAnimation: false)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
//        if plane!.anchor.identifier == anchor.identifier,
//            let planeAnchor = anchor as? ARPlaneAnchor {
//            plane!.update(anchor: planeAnchor)
//
//            DispatchQueue.main.async {
//                self.virtualObjectInteraction.updateObjectToCurrentTrackingPosition()
//            }
//        }
        
            if let planeAnchor = anchor as? ARPlaneAnchor {
                plane!.adjustOntoPlaneAnchor(planeAnchor, using: node)
            } else {
//                if let objectAtAnchor = plane {
//                    objectAtAnchor.simdPosition = anchor.transform.translation
//                    objectAtAnchor.anchor = anchor
//                }
            }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.virtualObjectInteraction.updateObjectToCurrentTrackingPosition()
        }
    }
}
