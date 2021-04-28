//
//  ViewController.swift
//  Sample App
//
//  Created by Vay on 27.04.21.
//

import VayUnifiedProtocol
import UIKit
import AVFoundation

class ViewController: UIViewController, FrameExtractorDelegate {
	
	var frameExtractor: FrameExtractor!
	var client: VayClient!
	var scaleX: CGFloat = 1
	var scaleY: CGFloat = 1
	private let metaSessionQueue = DispatchQueue(label: "metadata queue")
	var isConnected: Bool = false
	var receivedResponse: Bool  = true // Initially true to allow the first send.
	var readyForRequest: Bool = true
	var correctReps: Int32 = 0
	var metricInfoPerRep: Array<VaySports_Vup_MetricMessage> = []
	var ExerciseKey: Int64 = 1
	var currentImageData: [UInt8]!
	
	@IBOutlet weak var overlay: VisualizerView!
	@IBOutlet weak var preview: UIImageView!
	@IBOutlet weak var repsCount: UILabel!
	@IBOutlet weak var positioningText: UILabel!
	@IBOutlet weak var feedbackText: UILabel!
	
	// Camera frames are received here periodically.
	func captured(image: UIImage) {
		preview.image = image // Generate preview.
		let flippedImage: UIImage = image.flipHorizontally()!
		let scaledImage: UIImage = flippedImage.scaleToHeight(image: image, newHeight: 384) // Scale down image.
		// Calculate scaling factor for visualization.
		let frameSize = preview.frame.size
		let scaledSize = scaledImage.size
		self.scaleX = frameSize.width / scaledSize.width
		self.scaleY = frameSize.height / scaledSize.height
		currentImageData = self.convertUIImage(image: scaledImage)
		// Only send frames if the client is connected and once a response has been received (from the previous send).
		if isConnected && receivedResponse {
			do {
				try client.sendImage(image: currentImageData)
			} catch {
				print("Image data too large!")
			}
			self.receivedResponse = false
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		UIApplication.shared.isIdleTimerDisabled = true
		frameExtractor = FrameExtractor()
		frameExtractor.delegate = self
		metaSessionQueue.async {
			self.makeClientAndListeners()
		}
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		client.close()
		frameExtractor.stopSession()
		UIApplication.shared.isIdleTimerDisabled = false
	}
	
	func convertUIImage(image: UIImage) -> [UInt8] {
		guard let data = image.jpegData(compressionQuality: 0.1) else { return [] }
		return Array(data)
	}
	
	func makeClientAndListeners() {
		let url: URL = URL(string: "Insert server url here")!
		let uid:String = "iosSampleApp"
		let key:Int64 = ExerciseKey
		let taskType:KeyType = KeyType.exercise
		do {
			client = try VayClient(uri: url)
		} catch {
			print("Creating client failed!")
		}
		client.onReady = {client, _ in
			do {
				try client.sendMetadata(uid: uid, keyType: taskType, key: key)
			}
			catch {
				print("Sending metadata failed!")
			}
		}
		client.onError = { _, error in
			print(error.message!.localizedDescription)
		}
		client.onErrorResponse = { _, errorResponse in
			print(errorResponse.message!.errorType)
		}
		client.onMetadataResponse = { client, response in
			self.isConnected = true
		}
		client.onImageInterpolatedResponse = { client, message in
			let responsePoints:VaySports_Vup_HumanPoints = message.message!.points
			let pointsArray:[VaySports_Vup_Point] = [
				responsePoints.nose,
				responsePoints.neck,
				responsePoints.leftEar,
				responsePoints.rightEar,
				responsePoints.leftEye,
				responsePoints.rightEye,
				responsePoints.leftShoulder,
				responsePoints.rightShoulder,
				responsePoints.leftElbow,
				responsePoints.rightElbow,
				responsePoints.leftWrist,
				responsePoints.rightWrist,
				responsePoints.leftHip,
				responsePoints.rightHip,
				responsePoints.leftKnee,
				responsePoints.rightKnee,
				responsePoints.leftAnkle,
				responsePoints.rightAnkle,
				responsePoints.midHip
			]
			self.overlay.setPoints(pointsArray: pointsArray, xScale: self.scaleX, yScale: self.scaleY, imgWidth: self.preview.frame.size.width)
			self.overlay.setNeedsDisplay() // Redraws the visualizing layer.
		}
		client.onImageResponse = { client, message in
			if !message.message!.hasPoints {
				print("No Points received in imageMessage!")
			} else {
				self.positioningText.text = message.message?.currentMovement
				self.receivedResponse = true
				let responsePoints:VaySports_Vup_HumanPoints = message.message!.points
				let pointsArray:[VaySports_Vup_Point] = [
					responsePoints.nose,
					responsePoints.neck,
					responsePoints.leftEar,
					responsePoints.rightEar,
					responsePoints.leftEye,
					responsePoints.rightEye,
					responsePoints.leftShoulder,
					responsePoints.rightShoulder,
					responsePoints.leftElbow,
					responsePoints.rightElbow,
					responsePoints.leftWrist,
					responsePoints.rightWrist,
					responsePoints.leftHip,
					responsePoints.rightHip,
					responsePoints.leftKnee,
					responsePoints.rightKnee,
					responsePoints.leftAnkle,
					responsePoints.rightAnkle,
					responsePoints.midHip
				]
				self.overlay.setPoints(pointsArray: pointsArray, xScale: self.scaleX, yScale: self.scaleY, imgWidth: self.preview.frame.size.width)
				self.overlay.setNeedsDisplay() // Redraws the visualizing layer.
			}
			client.onRepetition = { client, repInfo in
				self.readMistakes(repInfo: repInfo)
			}
			client.onClose = { reason, code in
				print("Client closed! Reason: \(reason)   Code: \(code)")
			}
		}
		client.connect()
	}
	
	func readMistakes (repInfo: VupRepetitionEventData) {
		metricInfoPerRep = repInfo.metricInfo
		if !metricInfoPerRep.isEmpty {
			feedbackText.text = metricInfoPerRep[0].correction
			feedbackText.backgroundColor = UIColor.red
		} else {
			feedbackText.text = "Great job!"
			feedbackText.backgroundColor = UIColor.green
			correctReps += 1
			repsCount.text = "\(correctReps)"
		}
	}
	
}

extension UIImage {
	// Scale the image to a new height and its corresponding width (preserves aspect ratio).
	func scaleToHeight(image: UIImage, newHeight: CGFloat) -> UIImage {
		let ratio = newHeight / image.size.height
		let newWidth = image.size.width * ratio
		UIGraphicsBeginImageContextWithOptions(CGSize(width: newWidth, height: newHeight), true, 1)
		draw(in: CGRect(origin: .zero, size: CGSize(width: newWidth, height: newHeight)))
		let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
		UIGraphicsEndImageContext()
		return newImage
	}
	
	// Mirror image along the x-axis
	func flipHorizontally() -> UIImage? {
			UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
			let context = UIGraphicsGetCurrentContext()!
			
			context.translateBy(x: self.size.width/2, y: self.size.height/2)
			context.scaleBy(x: -1.0, y: 1.0)
			context.translateBy(x: -self.size.width/2, y: -self.size.height/2)
			
			self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
			
			let newImage = UIGraphicsGetImageFromCurrentImageContext()
			UIGraphicsEndImageContext()
			
			return newImage
		}
}
