//
//  MarkerDelegate.swift
//  EPNaverMapClustering
//
//  Created by Elon on 01/09/2019.
//

import Foundation
import NMapsMap

protocol MarkerDelegate {
    func add(_ marker: NMFMarker) -> Bool
    func remove(_ marker: NMFMarker) -> Bool
    func markers(in rect: NMGLatLngBounds) -> [NMFMarker]
}
