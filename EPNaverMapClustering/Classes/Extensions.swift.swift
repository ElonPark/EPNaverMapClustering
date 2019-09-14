//
//  Extensions.swift.swift
//  EPNaverMapClustering
//
//  Created by Elon on 13/09/2019.
//

import Foundation
import MapKit
import NMapsMap

private let radiusOfEarth: Double = 6372797.6

extension CGRect {
    init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.init(x: minX, y: minY, width: abs(maxX - minX), height: abs(maxY - minY))
    }
}

extension Double {
    var zoomLevel: Double {
        let maxZoomLevel = log2(MKMapSize.world.width / 256) // 20
        let zoomLevel = floor(log2(self) + 0.5) // negative
        return max(0, maxZoomLevel + zoomLevel) // max - current
    }
}

let CLLocationCoordinate2DMax = CLLocationCoordinate2D(latitude: 90, longitude: 180)

extension CLLocationCoordinate2D: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
}

extension CLLocationCoordinate2D: Equatable {
    
    var location: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    func coordinate(onBearingInRadians bearing: Double, atDistanceInMeters distance: Double) -> CLLocationCoordinate2D {
        let distRadians = distance / radiusOfEarth // earth radius in meters
        
        let lat1 = latitude * .pi / 180
        let lon1 = longitude * .pi / 180
        
        let lat2 = asin(sin(lat1) * cos(distRadians) + cos(lat1) * sin(distRadians) * cos(bearing))
        let lon2 = lon1 + atan2(sin(bearing) * sin(distRadians) * cos(lat1), cos(distRadians) - sin(lat1) * sin(lat2))
        
        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }
    
    func distance(from coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        return location.distance(from: coordinate.location)
    }
    
    public static func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

extension Array where Element: NMFMarker {
    
    func subtracted(_ other: [Element]) -> [Element] {
        return filter { item in !other.contains { $0.isEqual(item) } }
    }
    
    mutating func subtract(_ other: [Element]) {
        self = self.subtracted(other)
    }
    
    mutating func add(_ other: [Element]) {
        self.append(contentsOf: other)
    }
    
    @discardableResult
    mutating func remove(_ item: Element) -> Element? {
        return firstIndex { $0.isEqual(item) }.map { remove(at: $0) }
    }
}

extension OperationQueue {
    static var serial: OperationQueue {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }
    
    func addBlockOperation(_ block: @escaping (BlockOperation) -> Void) {
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak operation] in
            guard let operation = operation else { return }
            block(operation)
        }
        self.addOperation(operation)
    }
}

