//
//  ClusterManagerDelegate.swift
//  EPNaverMapClustering
//
//  Created by Elon on 02/09/2019.
//

import Foundation
import NMapsMap

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
