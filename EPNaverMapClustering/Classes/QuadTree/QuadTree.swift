//
//  QuadTree.swift
//  EPNaverMapClustering
//
//  Created by Elon on 01/09/2019.
//

import Foundation
import NMapsMap

public class QuadTree: MarkerDelegate {
    
    let root: QuadTreeNode
    
    public init(rect: NMGLatLngBounds) {
        self.root = QuadTreeNode(rect: rect)
    }
    
    @discardableResult
    public func add(_ annotation: NMFMarker) -> Bool {
        return root.add(annotation)
    }
    
    @discardableResult
    public func remove(_ annotation: NMFMarker) -> Bool {
        return root.remove(annotation)
    }
    
    public func markers(in rect: NMGLatLngBounds) -> [NMFMarker] {
        return root.markers(in: rect)
    }
}
