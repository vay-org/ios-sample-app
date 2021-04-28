//
//  VisualizerView.swift
//  Sample App
//
//  Created by Vay Sports on 28.04.21.
//

import Foundation
import UIKit
import VayUnifiedProtocol

class VisualizerView : UIView {
	let coordinates:[(Int, Int)] = [(0,1),(4,0),(5,0),(1,6),(6,8),(8,10),(18,13),
									(13,15),(15,17),(14,16),(18,12),(1,18),(9,11),(7,9),(1,7),(3,5),(2,4),(12,14)]
	var points: [VaySports_Vup_Point] = []
	var imgWidth: Double!
	var scaleX: CGFloat!
	var scaleY: CGFloat!
	let threshold: Double = 0.6
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		self.backgroundColor = UIColor.init(white: 0.0, alpha: 0.0)
	}
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
	
	override func draw(_ rect: CGRect) {
		if !points.isEmpty {
			if let context = UIGraphicsGetCurrentContext() {
				for connector in coordinates {
					if (points[connector.0].score > threshold) && (points[connector.1].score > threshold) {
						let x1 = imgWidth - (points[connector.0].x * Double(scaleX))
						let y1 = points[connector.0].y * Double(scaleY)
						let x2 = imgWidth - (points[connector.1].x * Double(scaleX))
						let y2 = points[connector.1].y * Double(scaleY)
						context.setStrokeColor(UIColor.white.cgColor)
						context.setLineWidth(2)
						context.beginPath()
						context.move(to: CGPoint(x: x1, y: y1))
						context.addLine(to: CGPoint(x: x2, y: y2))
						context.strokePath()
					}
				}
			}
			points = []
		}
	}
	
	func setPoints(pointsArray:[VaySports_Vup_Point], xScale:CGFloat, yScale:CGFloat, imgWidth:CGFloat) {
		self.points = pointsArray
		self.scaleX = xScale
		self.scaleY = yScale
		self.imgWidth = Double(imgWidth)
	}
}
