//
//  SKTiledScene.swift
//  SKTiled
//
//  Created by Michael Fessenden on 6/22/16.
//  Copyright (c) 2016 Michael Fessenden. All rights reserved.
//

import SpriteKit
import GameplayKit


/**
 ## Overview ##

 Delegate for managing `SKTilemap` nodes in an SpriteKit [`SKScene`][skscene-url] scene.
 This protocol and the `SKTiledScene` objects are included as a suggested way to use the
 `SKTilemap` class, but are not required.

 In this configuration, the tile map is a child of the root node and reference the custom
 `SKTiledSceneCamera` camera.

 [skscene-url]:https://developer.apple.com/reference/spritekit/skscene
 */
public protocol SKTiledSceneDelegate: class {
    /// Root container node. Tiled assets are parented to this node.
    var worldNode: SKNode! { get set }
    /// Custom scene camera.
    var cameraNode: SKTiledSceneCamera! { get set }
    /// Tile map node.
    var tilemap: SKTilemap! { get set }
    /// Load a tilemap from disk, with optional tilesets.
    func load(tmxFile: String, inDirectory: String?, withTilesets tilesets: [SKTileset],
              ignoreProperties: Bool, loggingLevel: LoggingLevel) -> SKTilemap?
}


/**

 ## Overview ##

 Custom scene type for managing `SKTilemap` nodes.

 Conforms to the `SKTiledSceneDelegate` & `SKTilemapDelegate` protocols.

 ### Properties: ###

 ```
 SKTiledScene.worldNode:    `SKNode!` root container node.
 SKTiledScene.tilemap:      `SKTilemap!` tile map object.
 SKTiledScene.cameraNode:   `SKTiledSceneCamera!` custom scene camera.
 ```
 */
open class SKTiledScene: SKScene, SKPhysicsContactDelegate, SKTiledSceneDelegate, SKTilemapDelegate, Loggable {

    /// Root container node.
    open var worldNode: SKNode!
    /// Tile map node.
    open var tilemap: SKTilemap!
    /// Custom scene camera.
    open var cameraNode: SKTiledSceneCamera!
    /// Logging verbosity level.
    open var loggingLevel: LoggingLevel = .info

    /// Reference to navigation graphs.
    open var graphs: [String : GKGridGraph<GKGridGraphNode>] = [:]

    // MARK: - Init
    /**
     Initialize without a tiled map.

     - parameter size:  `CGSize` scene size.
     - returns:         `SKTiledScene` scene.
     */
    required public override init(size: CGSize) {
        super.init(size: size)
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init()
    }

    deinit {
        removeAllActions()
        removeAllChildren()
    }

    override open func didChangeSize(_ oldSize: CGSize) {
        updateCamera()
    }

    override open func didMove(to view: SKView) {
        physicsWorld.gravity = CGVector.zero
        physicsWorld.contactDelegate = self

        // setup world node
        worldNode = SKNode()
        addChild(worldNode)

        // setup the camera
        cameraNode = SKTiledSceneCamera(view: view, world: worldNode)
        cameraNode.addDelegate(self)
        addChild(cameraNode)
        camera = cameraNode
    }

    // MARK: - Setup
    /**
     Load and setup a named TMX file, with optional tilesets.

     - parameter url:          `URL` Tiled file url.
     - parameter withTilesets: `[SKTileset]` pre-loaded tilesets.
     - parameter ignoreProperties: `Bool` don't parse custom properties.
     - parameter loggingLevel:     `LoggingLevel` logging verbosity.
     - parameter completion:  `(() -> ())?` optional completion handler.
     */
    open func setup(url: URL,
                    withTilesets: [SKTileset]=[],
                    ignoreProperties: Bool = false,
                    loggingLevel: LoggingLevel = .info,
                    _ completion: (() -> ())? = nil) {

        let dirname = url.deletingLastPathComponent()
        let filename = url.lastPathComponent
        let relativeURL = URL(fileURLWithPath: filename, relativeTo: dirname)

        self.setup(tmxFile: relativeURL.relativePath,
                        inDirectory: (relativeURL.baseURL == nil) ? nil : relativeURL.baseURL!.path,
                        withTilesets: withTilesets,
                        ignoreProperties: ignoreProperties,
                        loggingLevel: loggingLevel,
                        completion)
    }



    /**
     Load and setup a named TMX file, with optional tilesets. Allows for an optional completion handler.

     - parameter tmxFile:          `String` TMX file name.
     - parameter inDirectory:      `String?` search path for assets.
     - parameter withTilesets:     `[SKTileset]` optional pre-loaded tilesets.
     - parameter ignoreProperties: `Bool` don't parse custom properties.
     - parameter loggingLevel:     `LoggingLevel` logging verbosity.
     - parameter completion:  `(() -> ())?` optional completion handler.
     */
    open func setup(tmxFile: String,
                    inDirectory: String? = nil,
                    withTilesets tilesets: [SKTileset]=[],
                    ignoreProperties: Bool = false,
                    loggingLevel: LoggingLevel = .info,
                    _ completion: (() -> ())? = nil) {

        guard let worldNode = worldNode else { return }

        self.loggingLevel = loggingLevel
        self.tilemap = nil

        if let tilemap = load(tmxFile: tmxFile,
                              inDirectory: inDirectory,
                              withTilesets: tilesets,
                              ignoreProperties: ignoreProperties,
                              loggingLevel: loggingLevel) {

            backgroundColor = tilemap.backgroundColor ?? SKColor.clear

            // add the tilemap to the world container node.
            worldNode.addChild(tilemap)
            self.tilemap = tilemap
            cameraNode.addDelegate(self.tilemap)

            // apply gravity from the tile map
            physicsWorld.gravity = tilemap.gravity

            // camera properties inherited from tilemap
            cameraNode.allowMovement = tilemap.allowMovement
            cameraNode.allowZoom = tilemap.allowZoom

            // initial zoom level
            if (tilemap.autoResize == true) {
                if let view = view {
                    cameraNode.fitToView(newSize: view.bounds.size)   /// was size
                }
            } else {
                cameraNode.setCameraZoom(tilemap.worldScale)
            }

            // run completion handler
            completion?()
        }
    }

    // MARK: - Delegate Callbacks

    open func didBeginParsing(_ tilemap: SKTilemap) {
        // Called when tilemap is instantiated.
        log("parsing started: \"\(tilemap.mapName)\"", level: .gcd)
    }

    open func didAddTileset(_ tileset: SKTileset) {
        // Called when a tileset has been added.
        log("`tileset added: \"\(tileset.name)\"`", level: .gcd)
    }

    open func didAddLayer(_ layer: SKTiledLayerObject) {
        // Called when a layer has been added.
        log("layer added: \"\(layer.layerName)\"", level: .gcd)
    }

    open func didReadMap(_ tilemap: SKTilemap) {
        // Called before layers are rendered.
        log("finished reading: \"\(tilemap.mapName)\"", level: .gcd)
    }

    open func didRenderMap(_ tilemap: SKTilemap) {
        // Called after layers are rendered. Perform any post-processing here.
        log("rendering finished: \"\(tilemap.mapName)\"", level: .gcd)
    }

     open func didAddNavigationGraph(_ graph: GKGridGraph<GKGridGraphNode>) {
        // Called when a graph is added to the scene.
        let nodeCount = (graph.nodes != nil) ? graph.nodes!.count : 0
        log("graph added: \(nodeCount) nodes", level: .gcd)
    }

    open func objectForTileType(named: String?) -> SKTile.Type {
        return SKTile.self
    }

    open func objectForVectorType(named: String?) -> SKTileObject.Type {
        return SKTileObject.self
    }

    // MARK: - Updating
    override open func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        // update the tilemap
        //tilemap?.update(currentTime)
    }

    /**
     Update the camera bounds.
     */
    open func updateCamera() {
        guard let view = view else { return }
        print("[SKTiledScene]: updating camera bounds")
        let viewSize = view.bounds.size
        if let cameraNode = cameraNode {
            cameraNode.bounds = CGRect(x: -(viewSize.width / 2), y: -(viewSize.height / 2),
                                       width: viewSize.width, height: viewSize.height)
        }
    }
}


// setup methods
extension SKTiledSceneDelegate where Self: SKScene {

    /**
     Load a named TMX file, with optional tilesets.

     - parameter inDirectory:      `String?` search path for assets.
     - parameter withTilesets:     `[SKTileset]` optional pre-loaded tilesets.
     - parameter ignoreProperties: `Bool` don't parse custom properties.
     - parameter verbosity:        `LoggingLevel` logging verbosity.
     - returns: `SKTilemap?` tile map node.
     */
    public func load(tmxFile: String,
                     inDirectory: String? = nil,
                     withTilesets tilesets: [SKTileset]=[],
                     ignoreProperties: Bool = false,
                     loggingLevel: LoggingLevel = .info) -> SKTilemap? {


        if let tilemap = SKTilemap.load(tmxFile: tmxFile,
                                        inDirectory: inDirectory,
                                        delegate: self as? SKTilemapDelegate,
                                        withTilesets: tilesets,
                                        ignoreProperties: ignoreProperties,
                                        loggingLevel: loggingLevel) {

            if let cameraNode = cameraNode {
                // camera properties inherited from tilemap
                cameraNode.allowMovement = tilemap.allowMovement
                cameraNode.allowZoom = tilemap.allowZoom
                cameraNode.setCameraZoom(tilemap.worldScale)
                cameraNode.maxZoom = tilemap.maxZoom
            }

            return tilemap
        }
        return nil
    }
}


#if os(macOS)
extension SKTiledScene {

    override open func mouseDown(with event: NSEvent) {}
    
    override open func mouseMoved(with event: NSEvent) {
        guard let cameraNode = cameraNode else { return }
        cameraNode.mouseMoved(with: event)
    }
    override open func mouseUp(with event: NSEvent) {}
    override open func mouseEntered(with event: NSEvent) {}
    override open func mouseExited(with event: NSEvent) {}
    
    override open func scrollWheel(with event: NSEvent) {
        guard let cameraNode = cameraNode else { return }
        cameraNode.scrollWheel(with: event)
    }
}
#endif


// default methods
extension SKTiledScene: SKTiledSceneCameraDelegate {

    // MARK: - Delegate Methods
    /**
     Called when the camera positon changes.

     - parameter newPositon: `CGPoint` updated camera position.
     */
    public func cameraPositionChanged(newPosition: CGPoint) {
        // TODO: remove this notification callback in master
        NotificationCenter.default.post(name: Notification.Name(rawValue: "updateDebugLabels"),
                                        object: nil,
                                        userInfo: ["cameraInfo": cameraNode?.description ?? "nil"])
    }

    /**
     Called when the camera zoom changes.

     - parameter newZoom: `CGFloat` camera zoom amount.
     */
    public func cameraZoomChanged(newZoom: CGFloat) {
        // TODO: remove this notification callback in master
        NotificationCenter.default.post(name: Notification.Name(rawValue: "updateDebugLabels"),
                                        object: nil,
                                        userInfo: ["cameraInfo": cameraNode?.description ?? "nil"])
    }

    /**
     Called when the camera bounds updated.

     - parameter bounds:  `CGRect` camera view bounds.
     - parameter positon: `CGPoint` camera position.
     - parameter zoom:    `CGFloat` camera zoom amount.
     */
    public func cameraBoundsChanged(bounds: CGRect, position: CGPoint, zoom: CGFloat) {
        // override in subclass
        log("camera bounds updated: \(bounds.roundTo()), pos: \(position.roundTo()), zoom: \(zoom.roundTo())",
            level: .debug)

    }

    #if os(iOS) || os(tvOS)
    /**
     Called when the scene is double tapped. (iOS only)

     - parameter location: `CGPoint` touch location.
     */
    // CLEANUP: move to demo scene.
    public func sceneDoubleTapped(location: CGPoint) {
        log("scene was double tapped.", level: .debug)
        self.isPaused = !self.isPaused
    }

    /**
     Called when the scene is swiped. (iOS only)
     */
    public func sceneSwiped() {}
    #else

    /**
     Called when the scene is double-clicked. (macOS only)

     - parameter event: `NSEvent` mouse click event.
     */
    public func sceneDoubleClicked(event: NSEvent) {
        let location = event.location(in: self)
        log("mouse double-clicked.", level: .debug)
        addTemporaryShape(at: location, duration: 1.5, radius: 4)
    }

    /**
     Called when the mouse moves in the scene. (macOS only)

     - parameter event: `NSEvent` mouse event.
     */
    public func mousePositionChanged(event: NSEvent) {
        let location = event.location(in: self)
    }
    #endif
}



