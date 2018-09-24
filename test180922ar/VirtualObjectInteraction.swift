/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Coordinates movement and gesture interactions with virtual objects.
 */

import UIKit
import ARKit

/// - Tag: VirtualObjectInteraction
class VirtualObjectInteraction: NSObject, UIGestureRecognizerDelegate {
    
    /// Developer setting to translate assuming the detected plane extends infinitely.
    let translateAssumingInfinitePlane = true
    
    /// The scene view to hit test against when moving virtual content.
    let sceneView: VirtualObjectARView
    
    private var trackedObject: Plane? {
        didSet {
            guard trackedObject != nil else { return }
        }
    }
    
    /// The tracked screen position used to update the `trackedObject`'s position in `updateObjectToCurrentTrackingPosition()`.
    private var currentTrackingPosition: CGPoint?
    
    init(sceneView: VirtualObjectARView) {
        self.sceneView = sceneView
        super.init()
        
        let panGesture = ThresholdPanGesture(target: self, action: #selector(didPan(_:)))
        panGesture.delegate = self
        
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(didRotate(_:)))
        rotationGesture.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        
        // Add gestures to the `sceneView`.
        sceneView.addGestureRecognizer(panGesture)
        sceneView.addGestureRecognizer(rotationGesture)
        sceneView.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Gesture Actions
    
    @objc
    func didPan(_ gesture: ThresholdPanGesture) {
        switch gesture.state {
        case .began:
            // Check for interaction with a new object.
            print("didPan began")
            if let object = objectInteracting(with: gesture, in: sceneView) {
                trackedObject = object
            }
            
        case .changed where gesture.isThresholdExceeded:
            print("didPan changed where is ThresholdExceeded")
            guard let object = trackedObject else { return }
            let translation = gesture.translation(in: sceneView)
            
            let currentPosition = currentTrackingPosition ?? CGPoint(sceneView.projectPoint(object.position))
            
            // The `currentTrackingPosition` is used to update the `selectedObject` in `updateObjectToCurrentTrackingPosition()`.
            currentTrackingPosition = CGPoint(x: currentPosition.x + translation.x, y: currentPosition.y + translation.y)
            print("x \(translation.x) y \(translation.y)")
            gesture.setTranslation(.zero, in: sceneView)
            
        case .changed:
            print("didPan changed")
            // Ignore changes to the pan gesture until the threshold for displacment has been exceeded.
            break
            
        case .ended:
            print("didPan ended")
            // Update the object's anchor when the gesture ended.
            guard let existingTrackedObject = trackedObject else { break }
            sceneView.addOrUpdateAnchor(for: existingTrackedObject)
            fallthrough
            
        default:
            print("didPan default")
            // Clear the current position tracking.
            currentTrackingPosition = nil
            trackedObject = nil
        }
    }
    
    /**
     If a drag gesture is in progress, update the tracked object's position by
     converting the 2D touch location on screen (`currentTrackingPosition`) to
     3D world space.
     This method is called per frame (via `SCNSceneRendererDelegate` callbacks),
     allowing drag gestures to move virtual objects regardless of whether one
     drags a finger across the screen or moves the device through space.
     - Tag: updateObjectToCurrentTrackingPosition
     */
    @objc
    func updateObjectToCurrentTrackingPosition() {
        if currentTrackingPosition != nil {
            print("updateObjectToCurrentTrackingPosition \(currentTrackingPosition)")
        }
        guard let object = trackedObject, let position = currentTrackingPosition else { return }
        translate(object, basedOn: position, infinitePlane: translateAssumingInfinitePlane, allowAnimation: true)
    }
    
    /// - Tag: didRotate
    @objc
    func didRotate(_ gesture: UIRotationGestureRecognizer) {
        print("didRotate 1")
        guard gesture.state == .changed else { return }
        print("didRotate 2")

        /*
         - Note:
         For looking down on the object (99% of all use cases), we need to subtract the angle.
         To make rotation also work correctly when looking from below the object one would have to
         flip the sign of the angle depending on whether the object is above or below the camera...
         */
        trackedObject?.objectRotation -= Float(gesture.rotation)
        
        gesture.rotation = 0
    }
    
    @objc
    func didTap(_ gesture: UITapGestureRecognizer) {
        print("didTap")
        let touchLocation = gesture.location(in: sceneView)

        if let tappedObject = sceneView.virtualObject(at: touchLocation) {
            // Select a new object.
            trackedObject = tappedObject
        } else if let object = trackedObject {
            // Teleport the object to whereever the user touched the screen.
            translate(object, basedOn: touchLocation, infinitePlane: false, allowAnimation: false)
            sceneView.addOrUpdateAnchor(for: object)
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        print("gestureRecognizer")
        // Allow objects to be translated and rotated at the same time.
        return true
    }

    

    
    /// A helper method to return the first object that is found under the provided `gesture`s touch locations.
    /// - Tag: TouchTesting
    private func objectInteracting(with gesture: UIGestureRecognizer, in view: VirtualObjectARView) -> Plane? {
        print("objectInteracting")
        for index in 0..<gesture.numberOfTouches {
            let touchLocation = gesture.location(ofTouch: index, in: view)
            
            // Look for an object directly under the `touchLocation`.
            if let object = sceneView.virtualObject(at: touchLocation) {
                return object
            }
        }
        
        // As a last resort look for an object under the center of the touches.
        return sceneView.virtualObject(at: gesture.center(in: view))
    }
    
    // MARK: - Update object position
    
    /// - Tag: DragVirtualObject
    func translate(_ object: Plane, basedOn screenPos: CGPoint, infinitePlane: Bool, allowAnimation: Bool) {
        print("translate")
        guard let cameraTransform = self.sceneView.session.currentFrame?.camera.transform,
                let result = self.sceneView.smartHitTest(screenPos,
                                                infinitePlane: infinitePlane,
                                                objectPosition: object.simdWorldPosition,
                                                allowedAlignments: [ARPlaneAnchor.Alignment.horizontal]) else { return }
        
        let planeAlignment: ARPlaneAnchor.Alignment
        if let planeAnchor = result.anchor as? ARPlaneAnchor {
            planeAlignment = planeAnchor.alignment
        } else if result.type == .estimatedHorizontalPlane {
            planeAlignment = .horizontal
        } else if result.type == .estimatedVerticalPlane {
            planeAlignment = .vertical
        } else {
            return
        }
        
        /*
         Plane hit test results are generally smooth. If we did *not* hit a plane,
         smooth the movement to prevent large jumps.
         */
        let transform = result.worldTransform
        let isOnPlane = result.anchor is ARPlaneAnchor
        object.setTransform(transform,
                            relativeTo: cameraTransform,
                            smoothMovement: !isOnPlane,
                            alignment: planeAlignment,
                            allowAnimation: allowAnimation)
    }
}

/// Extends `UIGestureRecognizer` to provide the center point resulting from multiple touches.
extension UIGestureRecognizer {
    func center(in view: UIView) -> CGPoint {
        print("center")
        let first = CGRect(origin: location(ofTouch: 0, in: view), size: .zero)
        
        let touchBounds = (1..<numberOfTouches).reduce(first) { touchBounds, index in
            return touchBounds.union(CGRect(origin: location(ofTouch: index, in: view), size: .zero))
        }
        
        return CGPoint(x: touchBounds.midX, y: touchBounds.midY)
    }
}
