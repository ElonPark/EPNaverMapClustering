//
//  Marker.swift
//  EPNaverMapClustering
//
//  Created by Elon on 15/09/2019.
//

import Foundation
import MapKit
import NMapsMap

open class MapMarker: NMFMarker {
    // @available(swift, obsoleted: 6.0, message: "Please migrate to StyledClusterAnnotationView.")
    open var style: ClusterMapMarkerStyle?
    var coordinate: CLLocationCoordinate2D?
    
    public convenience init(coordinate: CLLocationCoordinate2D) {
        self.init()
        self.coordinate = coordinate
        self.position = NMGLatLng(lat: coordinate.latitude,
                                  lng: coordinate.longitude)
    }
}

open class ClusterMapMarker: MapMarker {
    open var markers = [NMFMarker]()
    
    open override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? ClusterMapMarker else { return false }
        
        if self === object {
            return true
        }
        
        if coordinate != object.coordinate {
            return false
        }
        
        if markers.count != object.markers.count {
            return false
        }
        
        return markers.map { $0.position } == object.markers.map { $0.position }
    }
}

/**
 The view associated with your cluster annotations.
 */
open class ClusterAnnotationView: MKAnnotationView {

    open lazy var countLabel: UILabel = {
        let label = UILabel()
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        label.backgroundColor = .clear
        label.font = .boldSystemFont(ofSize: 13)
        label.textColor = .white
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.baselineAdjustment = .alignCenters
        self.addSubview(label)
        return label
    }()
    
    open override var annotation: MKAnnotation? {
        didSet {
            configure()
        }
    }
    
    open func configure() {
        guard let annotation = annotation as? ClusterMapMarker else { return }
        let count = annotation.markers.count
        countLabel.text = "\(count)"
    }
}

/**
 The style of the cluster annotation view.
 */
public enum ClusterMapMarkerStyle {
    /**
     Displays the annotations as a circle.
     
     - `color`: The color of the annotation circle
     - `radius`: The radius of the annotation circle
     */
    case color(UIColor, radius: CGFloat)
    
    /**
     Displays the annotation as an image.
     */
    case image(UIImage?)
}

/**
 A cluster annotation view that supports styles.
 */
open class StyledClusterMapMarkerView: ClusterAnnotationView {
    
    /**
     The style of the cluster annotation view.
     */
    public var style: ClusterMapMarkerStyle
    
    /**
     Initializes and returns a new cluster annotation view.
     
     - Parameters:
     - annotation: The annotation object to associate with the new view.
     - reuseIdentifier: If you plan to reuse the annotation view for similar types of annotations, pass a string to identify it. Although you can pass nil if you do not intend to reuse the view, reusing annotation views is generally recommended.
     - style: The cluster annotation style to associate with the new view.
     
     - Returns: The initialized cluster annotation view.
     */
    public init(annotation: MKAnnotation?, reuseIdentifier: String?, style: ClusterMapMarkerStyle) {
        self.style = style
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configure()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func configure() {
        guard let annotation = annotation as? ClusterMapMarker else { return }
        
        switch style {
        case let .image(image):
            backgroundColor = .clear
            self.image = image
        case let .color(color, radius):
            let count = annotation.markers.count
            backgroundColor = color
            var diameter = radius * 2
            switch count {
            case _ where count < 8:
                diameter *= 0.6
            case _ where count < 16:
                diameter *= 0.8
            default: break
            }
            
            frame = CGRect(origin: frame.origin, size: CGSize(width: diameter, height: diameter))
            countLabel.text = "\(count)"
        }
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        if case .color = style {
            layer.masksToBounds = true
            layer.cornerRadius = image == nil ? bounds.width / 2 : 0
            countLabel.frame = bounds
        }
    }
    
}
