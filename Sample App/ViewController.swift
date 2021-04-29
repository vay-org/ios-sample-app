//
//  ViewController.swift
//  Sample App
//
//  Created by Vay on 27.04.21.
//

import VayUnifiedProtocol
import UIKit
import AVFoundation

/** The view controller periodically receives images from the frame extractor, which it displayes within the preview image view. Once a server connection has been established 'isConnected' is set to true.
	Images are only sent if 'isConnected' and 'receivedResponse' are both true. Once the image has
	been sent 'receivedResponse' is set to false until a response is received.
	Since the images received are from the front cam, they are mirrored horizontally. In order to get
	correct feedback for left/right arm/leg etc., the images must be flipped to their original state.
	Note that the received keypoints must be flipped accordingly, before they are visualized on the
	mirrored preview.
	Since the received images are too large to be sent, they must be scaled down and an appropriate
	ratio calculated in order to scale the keypoints back up for visualization.
	Before being sent, the images need to be converted to a UInt8 array format. */
class ViewController: UIViewController, FrameExtractorDelegate {
	
	var frameExtractor: FrameExtractor!
	var client: VayClient!
	var scaleX: CGFloat = 1
	var scaleY: CGFloat = 1
	private let metaSessionQueue = DispatchQueue(label: "metadata queue")
	var isConnected: Bool = false
	var receivedResponse: Bool  = true // Initially true to allow the first send.
	var correctReps: Int32 = 0
	var metricInfoPerRep: Array<VaySports_Vup_MetricMessage> = []
	var ExerciseKey: Int64 = 1 // Key 1 = Squat
	var currentImageData: [UInt8]!
	
	@IBOutlet weak var overlay: VisualizerView!
	@IBOutlet weak var preview: UIImageView!
	@IBOutlet weak var repsCount: UILabel!
	@IBOutlet weak var exerciseText: UILabel!
	@IBOutlet weak var feedbackText: UILabel!
	
	// Camera frames are received here periodically.
	func captured(image: UIImage) {
		preview.image = image // Set image for preview.
		let flippedImage: UIImage = image.flipHorizontally()!
		// Since images from the front cam are mirrored automatically,
		// we need to flip them back to the 'natural' state, in order to
		// get correct feedback for left/right sided corrections.
		let scaledImage: UIImage = flippedImage.scaleToHeight(image: image, newHeight: 384)
		// Down scale image while preserving aspect ratio.
		let frameSize = preview.frame.size
		let scaledSize = scaledImage.size
		self.scaleX = frameSize.width / scaledSize.width
		self.scaleY = frameSize.height / scaledSize.height
		// Calculate scaling factor for visualization of keypoints.
		currentImageData = self.convertUIImage(image: scaledImage)
		// Only send frames if the client is connected and once a response has been received (from the previous send).
		if isConnected && receivedResponse {
			do {
				try client.sendImage(image: currentImageData)
				// Images sent to the server must be upright, compressed as
				// JPEG or PNG, converted to byte array and should not
				// exceed 10kb.
			} catch {
				print("Image data too large!")
			}
			self.receivedResponse = false
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		UIApplication.shared.isIdleTimerDisabled = true
		// Disables screen standby when idle.
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
	
	// Converts UIImage to byte array with JPEG compression.
	func convertUIImage(image: UIImage) -> [UInt8] {
		guard let data = image.jpegData(compressionQuality: 0.1) else { return [] }
		return Array(data)
	}
	
	// Creates the Vay client and defines each listener before connecting.
	// The listeners handle server responses.
	func makeClientAndListeners() {
		let url: URL = URL(string: "Insert server url here")!
		let uid:String = "iosSampleApp"
		// Choose a name unique to your organisation or application.
		let key:Int64 = ExerciseKey
		// Defines which exercise gets analyzed for this session.
		let taskType:KeyType = KeyType.exercise
		// Should always be set to type exercise.
		do {
			client = try VayClient(uri: url)
			// Note that this does not connect to the client yet.
		} catch {
			print("Creating client failed!")
		}
		
		// Called when the initial connection to the server is successfull.
		client.onReady = {client, _ in
			do {
				try client.sendMetadata(uid: uid, keyType: taskType, key: key)
				// Configures the exercise session. Must done before any
				// image is sent. If you wish to change the exercise, re-
				// sending a metadata request suffices.
			}
			catch {
				print("Sending metadata failed!")
			}
		}
		
		// Called when a server error occures.
		client.onError = { _, error in
			print(error.message!.localizedDescription)
		}
		
		// Error responses usually indicate that something is wrong with the
		// request sent to the server. Consult the docs, for further
		// explanation on the different error types.
		client.onErrorResponse = { _, errorResponse in
			print(errorResponse.message!.errorType)
		}
		
		// Signals that the exercise session has been set up successfully,
		// meaning images can be sent for analysis.
		client.onMetadataResponse = { client, response in
			self.isConnected = true // Triggers first image send.
		}
		
		// For smoother visualization of the skeleton, keypoints are
		// extrapolated by the server and these points are received here.
		// Use this listener exclusively for visualization.
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
		
		// Analysis results from the previously sent image are received
		// here, signifying that a new image can be sent. Keypoints can be
		// used for visualization and any non-repetition related evaluations
		// can be performed here.
		client.onImageResponse = { client, message in
			if !message.message!.hasPoints {
				print("No Points received in imageMessage!")
			} else {
				self.exerciseText.text = message.message?.currentMovement
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
			
			// Gets triggered for every completed repetition, regardless of
			// whether mistakes were made during the rep. Use this listener
			// to count reps and evaluate feedback for mistakes.
			client.onRepetition = { client, repInfo in
				self.readMistakes(repInfo: repInfo)
			}
			
			// Called whenever the client is closed.
			client.onClose = { reason, code in
				self.isConnected = false
				print("Client closed! Reason: \(reason)   Code: \(code)")
			}
		}
		client.connect()
		// Sets up the connection to the server. Should only be called after
		// listeners have been set up.
	}
	
	// Counts correct reps, picks a correction for faulty reps and updates
	// the corresponding labels.
	func readMistakes (repInfo: VupRepetitionEventData) {
		metricInfoPerRep = repInfo.metricInfo
		// A list of violated metrics, for this rep. If empty the rep was
		// performed correctly.
		if !metricInfoPerRep.isEmpty {
			feedbackText.text = metricInfoPerRep[0].correction
			// Display one of possibly multiple corrections.
			feedbackText.backgroundColor = UIColor.red
		} else {
			feedbackText.text = "Great job!"
			feedbackText.backgroundColor = UIColor.green
			correctReps += 1 // Here only correct reps are counted.
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
