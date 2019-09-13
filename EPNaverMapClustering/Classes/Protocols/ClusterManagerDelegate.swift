//
//  ClusterManagerDelegate.swift
//  EPNaverMapClustering
//
//  Created by Elon on 02/09/2019.
//

import Foundation
import NMapsMap
import MapKit

public protocol ClusterManagerDelegate: class {
    /**
     The size of each cell on the grid (The larger the size, the better the performance) at a given zoom level.
     
     - Parameters:
     - zoomLevel: The zoom level of the visible map region.
     
     - Returns: The cell size at the given zoom level. If you return nil, the cell size will automatically adjust to the zoom level.
     */
    func cellSize(for zoomLevel: Double) -> Double?
    
    /**
     Whether to cluster the given marker.
     
     - Parameters:
     - marker: An marker object. The object must conform to the NMFMarker protocol.
     
     - Returns: `true` to clusterize the given marker.
     */
    func shouldClusterMarker(_ marker: NMFMarker) -> Bool
}

public extension ClusterManagerDelegate {
    func cellSize(for zoomLevel: Double) -> Double? {
        return nil
    }
    
    func shouldClusterMarker(_ marker: NMFMarker) -> Bool {
        return true
    }
}

open class ClusterManager {
    
    var mapView: NMFMapView
    
    lazy var tree = QuadTree(rect: mapView.contentBounds)
    
    /**
     The current zoom level of the visible map region.
     
     Min value is 0 (max zoom out), max is 20 (max zoom in).
     */
    open internal(set) var zoomLevel: Double = 0
    
    /**
     The maximum zoom level before disabling clustering.
     
     Min value is 0 (max zoom out), max is 20 (max zoom in). The default is 20.
     */
    open var maxZoomLevel: Double = 20
    
    /**
     The minimum number of markers for a cluster.
     
     The default is 2.
     */
    open var minCountForClustering: Int = 2
    
    /**
     Whether to remove invisible markers.
     
     The default is true.
     */
    open var shouldRemoveInvisibleMarkers: Bool = true
    
    /**
     Whether to arrange markers in a circle if they have the same coordinate.
     
     The default is true.
     */
    open var shouldDistributeMarkersOnSameCoordinate: Bool = true
    
    /**
     The distance in meters from contested location when the markers have the same coordinate.
     The default is 3.
     */
    open var distanceFromContestedLocation: Double = 3
    
    /**
     The position of the cluster marker.
     */
    public enum ClusterPosition {
        /**
         Placed in the center of the grid.
         */
        case center
        
        /**
         Placed on the coordinate of the marker closest to center of the grid.
         */
        case nearCenter
        
        /**
         Placed on the computed average of the coordinates of all markers in a cluster.
         */
        case average
        
        /**
         Placed on the coordinate of first marker in a cluster.
         */
        case first
    }
    
    /**
     The position of the cluster marker. The default is `.nearCenter`.
     */
    open var clusterPosition: ClusterPosition = .nearCenter
    
    /**
     The list of markers associated.
     
     The objects in this array must adopt the NMFMarker protocol. If no markers are associated with the cluster manager, the value of this property is an empty array.
     */
    open var markers: [NMFMarker] {
        return dispatchQueue.sync {
            tree.markers(in: mapView.contentBounds)
        }
    }
    
    /**
     The list of visible markers associated.
     */
    open var visibleMarkers = [NMFMarker]()
    
    /**
     The list of nested visible markers associated.
     */
    open var visibleNestedMarkers: [NMFMarker] {
        return dispatchQueue.sync {
            visibleMarkers.reduce([NMFMarker](), { $0 + (($1 as? ClusterMarker)?.markers ?? [$1]) })
        }
    }

    let operationQueue = OperationQueue.serial
    let dispatchQueue = DispatchQueue(label: "com.elonparks.concurrentQueue", attributes: .concurrent)
    
    public var projection: NMFProjection {
        return self.mapView.projection
    }
    
    open weak var delegate: ClusterManagerDelegate?
    
    public init(mapView: NMFMapView) {
        self.mapView = mapView
    }
    
    /**
     Adds an marker object to the cluster manager.
     
     - Parameters:
     - marker: An marker object. The object must conform to the NMFMarker protocol.
     */
    open func add(_ marker: NMFMarker) {
        operationQueue.cancelAllOperations()
        dispatchQueue.async(flags: .barrier) { [weak self] in
            self?.tree.add(marker)
        }
    }
    
    /**
     Adds an array of marker objects to the cluster manager.
     
     - Parameters:
     - markers: An array of marker objects. Each object in the array must conform to the NMFMarker protocol.
     */
    open func add(_ markers: [NMFMarker]) {
        operationQueue.cancelAllOperations()
        dispatchQueue.async(flags: .barrier) { [weak self] in
            for marker in markers {
                self?.tree.add(marker)
            }
        }
    }
    
    /**
     Removes an marker object from the cluster manager.
     
     - Parameters:
     - marker: An marker object. The object must conform to the NMFMarker protocol.
     */
    open func remove(_ marker: NMFMarker) {
        operationQueue.cancelAllOperations()
        dispatchQueue.async(flags: .barrier) { [weak self] in
            self?.tree.remove(marker)
        }
    }
    
    /**
     Removes an array of marker objects from the cluster manager.
     
     - Parameters:
     - markers: An array of marker objects. Each object in the array must conform to the NMFMarker protocol.
     */
    open func remove(_ markers: [NMFMarker]) {
        operationQueue.cancelAllOperations()
        dispatchQueue.async(flags: .barrier) { [weak self] in
            for marker in markers {
                self?.tree.remove(marker)
            }
        }
    }
    
    /**
     Removes all the marker objects from the cluster manager.
     */
    open func removeAll() {
        operationQueue.cancelAllOperations()
        dispatchQueue.async(flags: .barrier) { [weak self] in
            self?.tree = QuadTree(rect: .world)
        }
    }
    
    /**
     Reload the markers on the map view.
     
     - Parameters:
     - mapView: The map view object to reload.
     - visibleMapRect: The area currently displayed by the map view.
     */
    @available(swift, obsoleted: 5.0, message: "Use reload(mapView:)")
    open func reload(_ mapView: NMFMapView, visibleMapRect: CGRect) {
        reload(mapView: mapView)
    }
    
    /**
     Reload the markers on the map view.
     
     - Parameters:
     - mapView: The map view object to reload.
     - completion: A closure to be executed when the reload finishes. The closure has no return value and takes a single Boolean argument that indicates whether or not the reload actually finished before the completion handler was called.
     */
    open func reload(mapView: NMFMapView, completion: @escaping (Bool) -> Void = { finished in }) {
        let mapBounds = mapView.bounds
        let visibleMapRect = mapView.projection.viewBounds(from: mapView.contentBounds)
        let visibleMapRectWidth = visibleMapRect.size.width
        let zoomScale = Double(mapBounds.width) / Double(visibleMapRectWidth)
        
        operationQueue.cancelAllOperations()
        operationQueue.addBlockOperation { [weak self, weak mapView] operation in
            guard let self = self, let mapView = mapView else { return completion(false) }
            autoreleasepool {
                let (toAdd, toRemove) = self.clusteredMarkers(
                    zoomScale: zoomScale,
                    visibleMapRect: mapView.contentBounds,
                    operation: operation
                )
                
                DispatchQueue.main.async { [weak self, weak mapView] in
                    guard let self = self, let mapView = mapView else { return completion(false) }
                    self.display(mapView: mapView, toAdd: toAdd, toRemove: toRemove)
                    completion(true)
                }
            }
        }
    }
    
    open func clusteredMarkers(zoomScale: Double, visibleMapRect: NMGLatLngBounds, operation: Operation? = nil) -> (toAdd: [NMFMarker], toRemove: [NMFMarker]) {
        var isCancelled: Bool { return operation?.isCancelled ?? false }
        
        guard !isCancelled else { return (toAdd: [], toRemove: []) }
        
        let mapRects = self.mapRects(
            zoomScale: zoomScale,
            visibleMapRect: projection.viewBounds(from: visibleMapRect)
        )
        
        guard !isCancelled else { return (toAdd: [], toRemove: []) }
        
        // handle markers on the same coordinate
        if shouldDistributeMarkersOnSameCoordinate {
            distributeMarkers(tree: tree, mapRect: visibleMapRect)
        }
        
        let allMarkers = dispatchQueue.sync {
            clusteredMarkers(tree: tree, mapRects: mapRects, zoomLevel: zoomLevel)
        }
        
        guard !isCancelled else { return (toAdd: [], toRemove: []) }
        
        let before = visibleMarkers
        let after = allMarkers
        
        var toRemove = before.subtracted(after)
        let toAdd = after.subtracted(before)
        
        if !shouldRemoveInvisibleMarkers {
            let toKeep = toRemove.filter { !visibleMapRect.contains($0.position) }
            toRemove.subtract(toKeep)
        }
        
        dispatchQueue.async(flags: .barrier) { [weak self] in
            self?.visibleMarkers.subtract(toRemove)
            self?.visibleMarkers.add(toAdd)
        }
        
        return (toAdd: toAdd, toRemove: toRemove)
    }
    
    func clusteredMarkers(tree: QuadTree, mapRects: [NMGLatLngBounds], zoomLevel: Double) -> [NMFMarker] {
        var allMarkers = [NMFMarker]()
        for mapRect in mapRects {
            var markers = [NMFMarker]()
            
            // add markers
            for node in tree.markers(in: mapRect) {
                if delegate?.shouldClusterMarker(node) ?? true {
                    markers.append(node)
                } else {
                    allMarkers.append(node)
                }
            }
            
            // handle clustering
            let count = markers.count
            if count >= minCountForClustering, zoomLevel <= maxZoomLevel {
                let cluster = ClusterMarker()
                cluster.coordinate = coordinate(markers: markers, position: clusterPosition, mapRect: mapRect)
                cluster.markers = markers
                cluster.style = (markers.first as? Marker)?.style
                allMarkers += [cluster]
            } else {
                allMarkers += markers
            }
        }
        return allMarkers
    }
    
    func distributeMarkers(tree: QuadTree, mapRect: NMGLatLngBounds) {
        let markers = dispatchQueue.sync {
            tree.markers(in: mapRect)
        }
        
        let hash = Dictionary(grouping: markers) { $0.position }
        dispatchQueue.async(flags: .barrier) {
            for value in hash.values where value.count > 1 {
                for (index, marker) in value.enumerated() {
                    tree.remove(marker)
                    let radiansBetweenMarkers = (.pi * 2) / Double(value.count)
                    let bearing = radiansBetweenMarkers * Double(index)
                    (marker as? MKPointMarker)?.coordinate = marker.coordinate.coordinate(
                        onBearingInRadians: bearing,
                        atDistanceInMeters: self.distanceFromContestedLocation
                    )
                    tree.add(marker)
                }
            }
        }
    }
    
    func coordinate(markers: [NMFMarker], position: ClusterPosition, mapRect: CGRect) -> NMGLatLng {
        switch position {
        case .center:
            return projection.latlng(from: CGPoint(x: mapRect.midX, y: mapRect.midY))
        case .nearCenter:
            let position = projection.latlng(from: CGPoint(x: mapRect.midX, y: mapRect.midY))
            let marker = markers.min { position.distance(to: $0.position) < position.distance(to: $1.position) }
            return marker!.position
            
        case .average:
            let coordinates = markers.map {
                CLLocationCoordinate2D(latitude: $0.position.lat, longitude: $0.position.lng)
            }
            let totals = coordinates.reduce((latitude: 0.0, longitude: 0.0)) {
                ($0.latitude + $1.latitude, $0.longitude + $1.longitude)
            }
            let latitude = totals.latitude / Double(coordinates.count)
            let longitude = totals.longitude / Double(coordinates.count)
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            return NMGLatLng(from: coordinate)
            
        case .first:
            return markers.first!.position
        }
    }
    
    func mapRects(zoomScale: Double, visibleMapRect: CGRect) -> [NMGLatLngBounds] {
        guard !zoomScale.isInfinite, !zoomScale.isNaN else { return [] }
        
        zoomLevel = zoomScale.zoomLevel
        let scaleFactor = CGFloat(zoomScale / cellSize(for: zoomLevel))
        
        let minX = Int(floor(visibleMapRect.minX * scaleFactor))
        let maxX = Int(floor(visibleMapRect.maxX * scaleFactor))
        let minY = Int(floor(visibleMapRect.minY * scaleFactor))
        let maxY = Int(floor(visibleMapRect.maxY * scaleFactor))
        
        let maxPoint = NMGPoint(x: CLLocationCoordinate2DMax.latitude,
                                y: CLLocationCoordinate2DMax.longitude)
        
        var mapRects = [NMGLatLngBounds]()
        for x in minX...maxX {
            for y in minY...maxY {
                var mapRect = CGRect(
                    x: CGFloat(x) / scaleFactor,
                    y: CGFloat(y) / scaleFactor,
                    width: 1 / scaleFactor,
                    height: 1 / scaleFactor
                )
                
                if mapRect.origin.x > CGFloat(maxPoint.x) {
                    mapRect.origin.x -= CGFloat(maxPoint.x)
                }
                
                let latlngBounds = projection.latlngBounds(fromViewBounds: mapRect)
                mapRects.append(latlngBounds)
            }
        }
        
        return mapRects
    }
    
    open func display(mapView: NMFMapView, toAdd: [NMFMarker], toRemove: [NMFMarker]) {
        assert(Thread.isMainThread, "This function must be called from the main thread.")
        toRemove.forEach { $0.mapView = nil }
        toAdd.forEach { $0.mapView = mapView }
    }
    
    func cellSize(for zoomLevel: Double) -> Double {
        if let cellSize = delegate?.cellSize(for: zoomLevel) {
            return cellSize
        }
        switch zoomLevel {
        case 13...15:
            return 64
        case 16...18:
            return 32
        case 19...:
            return 16
        default:
            return 88
        }
    }
    
}
