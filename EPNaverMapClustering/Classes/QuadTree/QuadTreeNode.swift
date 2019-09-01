//
//  QuadTreeNode.swift
//  EPNaverMapClustering
//
//  Created by Elon on 01/09/2019.
//

import Foundation
import NMapsMap

class QuadTreeNode {
    
    enum NodeType {
        case leaf
        case `internal`(children: Children)
    }
    
    var annotations = [NMFMarker]()
    let rect: NMGLatLngBounds
    var type: NodeType = .leaf
    
    static let maxPointCapacity = 8
    
    init(rect: NMGLatLngBounds) {
        self.rect = rect
    }
    
}

extension QuadTreeNode {

    struct Children: Sequence {
        let northWest: QuadTreeNode
        let northEast: QuadTreeNode
        let southWest: QuadTreeNode
        let southEast: QuadTreeNode
        
        init(parentNode: QuadTreeNode) {
            let mapRect = parentNode.rect
            
            
//            NMGLatLngBounds(southWest: <#T##NMGLatLng#>, northEast: <#T##NMGLatLng#>)
//
//            mapRect.northEast
//            mapRect.southWest.lat
//            mapRect.center.lng
//
//            northWest = QuadTreeNode(rect: MKMapRect(minX: mapRect.minX,
//                                                     minY: mapRect.minY,
//
//                                                     maxX: mapRect.midX,
//                                                     maxY: mapRect.midY)
//            )
//            northEast = QuadTreeNode(rect: MKMapRect(minX: mapRect.midX,
//                                                     minY: mapRect.minY,
//
//                                                     maxX: mapRect.maxX,
//                                                     maxY: mapRect.midY)
//            )
//            southWest = QuadTreeNode(rect: MKMapRect(minX: mapRect.minX,
//                                                     minY: mapRect.midY,
//
//                                                     maxX: mapRect.midX,
//                                                     maxY: mapRect.maxY)
//            )
//            southEast = QuadTreeNode(rect: MKMapRect(minX: mapRect.midX,
//                                                     minY: mapRect.midY,
//
//                                                     maxX: mapRect.maxX,
//                                                     maxY: mapRect.maxY)
//            )
        }
        
        struct ChildrenIterator: IteratorProtocol {
            private var index = 0
            private let children: Children
            
            init(children: Children) {
                self.children = children
            }
            
            mutating func next() -> QuadTreeNode? {
                defer { index += 1 }
                switch index {
                case 0: return children.northWest
                case 1: return children.northEast
                case 2: return children.southWest
                case 3: return children.southEast
                default: return nil
                }
            }
        }
        
        public func makeIterator() -> ChildrenIterator {
            return ChildrenIterator(children: self)
        }
    }
}

extension QuadTreeNode: MarkerDelegate {
    
    @discardableResult
    func add(_ marker: NMFMarker) -> Bool {
        guard rect.hasPoint(marker.position) else { return false }
        
        switch type {
        case .leaf:
            annotations.append(marker)
            // if the max capacity was reached, become an internal node
            if annotations.count == QuadTreeNode.maxPointCapacity {
                subdivide()
            }
        case .internal(let children):
            // pass the point to one of the children
            for child in children where child.add(marker) {
                return true
            }
            
            assertionFailure("rect.contains evaluted to true, but none of the children added the annotation")
        }
        return true
    }
    
    @discardableResult
    func remove(_ marker: NMFMarker) -> Bool {
        guard rect.hasPoint(marker.position) else { return false }
        
        _ = annotations.map { $0.position }
            .firstIndex(of: marker.position)
            .map { annotations.remove(at: $0) }
        
        switch type {
        case .leaf: break
        case .internal(let children):
            // pass the point to one of the children
            for child in children where child.remove(marker) {
                return true
            }
            
            assertionFailure("rect.contains evaluted to true, but none of the children removed the annotation")
        }
        return true
    }
    
    private func subdivide() {
        switch type {
        case .leaf:
            type = .internal(children: Children(parentNode: self))
        case .internal:
            preconditionFailure("Calling subdivide on an internal node")
        }
    }
    
    func markers(in rect: NMGLatLngBounds) -> [NMFMarker] {
        guard rect.isIntersect(rect) else { return [] }
    
        var result = annotations.filter { rect.hasPoint($0.position) }
        
        switch type {
        case .leaf: break
        case .internal(let children):
            for childNode in children {
                result.append(contentsOf: childNode.markers(in: rect))
            }
        }
        
        return result
    }
    
}
