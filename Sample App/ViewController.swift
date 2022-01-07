//
//  ViewController.swift
//  Sample App
//
//  Created by Vay on 27.04.21.
//

import UIKit
import AVFoundation
import SwiftClient

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
class ViewController: UIViewController, FrameExtractorDelegate, VayListener {
	
	var frameExtractor: FrameExtractor!
	var analyser: VayAnalyser!
	var scaleX: CGFloat = 1
	var scaleY: CGFloat = 1
	private let metaSessionQueue = DispatchQueue(label: "metadata queue")
	var isConnected: Bool = false
	var receivedResponse: Bool  = true // Initially true to allow the first send.
	var correctReps: Int32 = 0
	
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
		guard let imageData = scaledImage.jpegData(compressionQuality: 0.1) else {
			print("JPEG conversion failed!")
			return
		}
		analyser.enqueue(input: AnalyserFactory.createInput(for: imageData))
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
		analyser.stop()
		frameExtractor.stopSession()
		UIApplication.shared.isIdleTimerDisabled = false
	}
	
	// Creates the Vay client and defines each listener before connecting.
	// The listeners handle server responses.
	func makeClientAndListeners() {
		// url that will be provided. Fetch this from your backend!
		let url = "rpcs://<hostname>:<port>"
		// api key for authentication. Fetch from your backend!
		let apiKey = "API-KEY"
		// Choose a name unique to your organisation or application.
		let exerciseKey = 1 // key of the exercise to analyse
		analyser = AnalyserFactory.createStreamingAnalyser(url: url,
			apiKey: apiKey, exerciseKey: exerciseKey,
			listener: self)
	}

	// If you want to visualize the keypoints, do it from here
	// Use this listener exclusively for visualization.
	func onPose(_ event: VayPoseEvent) {
		// Get the points for each body point type
		let points = event.pose
		let pointsArray = [
			points[VayBodyPointType.nose]!,
			points[VayBodyPointType.neck]!,
			points[VayBodyPointType.leftEar]!,
			points[VayBodyPointType.rightEar]!,
			points[VayBodyPointType.leftEye]!,
			points[VayBodyPointType.rightEye]!,
			points[VayBodyPointType.leftShoulder]!,
			points[VayBodyPointType.rightShoulder]!,
			points[VayBodyPointType.leftElbow]!,
			points[VayBodyPointType.rightElbow]!,
			points[VayBodyPointType.leftWrist]!,
			points[VayBodyPointType.rightWrist]!,
			points[VayBodyPointType.leftHip]!,
			points[VayBodyPointType.rightHip]!,
			points[VayBodyPointType.leftKnee]!,
			points[VayBodyPointType.rightKnee]!,
			points[VayBodyPointType.leftAnkle]!,
			points[VayBodyPointType.rightAnkle]!,
			points[VayBodyPointType.midHip]!
		]
		self.overlay.setPoints(pointsArray: pointsArray, xScale: self.scaleX, yScale: self.scaleY, imgWidth: self.preview.frame.size.width)
		self.overlay.setNeedsDisplay() // Redraws the visualizing layer.
	}

	// Metric values can be analysed here.
	func onMetricValues(_ event: VayMetricValuesEvent) {
		// Get the metric values
		_ = event.metricValues
	}

	// Feedbacks are received here.
	func onFeedback(_ event: VayFeedbackEvent) {
		// Get a list of feedbacks
		_ = event.feedbacks
	}

	// Any logic that evaluates repetitions can go here
	func onRepetition(_ event: VayRepetitionEvent) {
		// Get the duration of the repetition
		_ = event.repetition.duration
		// Get all feedbacks that occurred during this repetition
		let feedbacks = event.repetition.feedbacks
		//If empty the rep was performed correct.
		if feedbacks.isEmpty {
			feedbackText.text = "Great job!"
			feedbackText.backgroundColor = UIColor.green
			correctReps += 1 // Here only correct reps are counted.
			repsCount.text = "\(correctReps)"
		} else {
			feedbackText.text = feedbacks[0].messages[0]
			// Display one of possibly multiple corrections.
			feedbackText.backgroundColor = UIColor.red
		}
	}

	// Analyse the occurred error here
	func onError(_ event: VayErrorEvent) {
		// Get the error
		let error = event.error
		// Display the error reason
		print("Error reason: \(error)")
	}

	// When the session is configured and ready, the exercise including all
	// metrics is received
	func onReady(_ event: VayReadyEvent) {
		// Get the exercise name
		_ = event.exercise.name
		// Get the exercise key
		_ = event.exercise.key
		// Get the metrics
		_ = event.exercise.metrics
	}

	// Information that the analyser has been stopped
	func onStop() {
		print("Analyser stopped!")
	}

	// When the session state changes e.g. from POSITIONING to EXERCISING the
	// new state can be stored here
	func onSessionStateChanged(_ event: VaySessionStateChangedEvent) {
		// Get the session state
		_ = event.sessionState
	}

	// Here the state of the ENVIRONMENT and the LATENCY can be analysed
	func onSessionQualityChanged(_ event: VaySessionQualityChangedEvent) {
		// Get the session quality
		_ = event.sessionQuality
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
