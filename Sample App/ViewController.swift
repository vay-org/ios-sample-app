//
//  ViewController.swift
//  Sample App
//
//

import UIKit
import AVFoundation
import SwiftClient

/**
	This class serves as a minimalistic implementation example on how to use our Swift-Client.
	On initialization, an exercise session is configured. The frameExtractor class feeds images from the camera.
	These are preprocessed and enqueued for sending. Event callbacks are defined within this class and it is
	passed as listener to the analyser. For further documentation go to https://docs.vay.ai
 */
class ViewController: UIViewController, FrameExtractorDelegate, VayListener {
	
	var frameExtractor: FrameExtractor?
	var analyser: VayAnalyser?
	var scaleX: CGFloat = 1
	var scaleY: CGFloat = 1
	private let sessionSetupQueue = DispatchQueue(label: "session setup queue")
	var correctRepetitions: Int32 = 0
	var state: VaySessionState = VaySessionState.noHuman
	
	@IBOutlet weak var overlay: VisualizerView!
	@IBOutlet weak var preview: UIImageView!
	@IBOutlet weak var repetitionCount: UILabel!
	@IBOutlet weak var stateText: UILabel!
	@IBOutlet weak var feedbackText: UILabel!
	
	// Camera frames are received here periodically.
	func captured(image: UIImage) {
		preview.image = image // Pass image to preview.
		// Since images from the front camera are mirrored automatically,
		// we need to flip them back to the 'natural' state, in order to
		// get correct feedback for left/right sided corrections.
		guard let flippedImage: UIImage = image.flipHorizontally() else {
			print("Image flipping failed!")
			return
		}
		// Down scale the image while preserving its aspect ratio.
		let scaledImage: UIImage = flippedImage.scaleToHeight(image: image, newHeight: 384)
		// Calculate scaling factor for visualization of keypoints.
		let frameSize = preview.frame.size
		let scaledSize = scaledImage.size
		self.scaleX = frameSize.width / scaledSize.width
		self.scaleY = frameSize.height / scaledSize.height
		guard let imageData = scaledImage.jpegData(compressionQuality: 0.1) else {
			print("JPEG conversion failed!")
			return
		}
		guard let analyser = analyser else {
			print("Analyser is nil!")
			return
		}
		// Enqueue image data for sending.
		analyser.enqueue(input: AnalyserFactory.createInput(for: imageData))
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		// Disables screen standby when idle.
		UIApplication.shared.isIdleTimerDisabled = true
		frameExtractor = FrameExtractor()
		guard let frameExtractor = frameExtractor else {
			print("Frame extractor initialization failed!")
			return
		}
		frameExtractor.delegate = self
		// Initialize session setup.
		sessionSetupQueue.async {
			self.makeClientAndListeners()
		}
		// UI related setup.
		DispatchQueue.main.async {
			self.feedbackText.layer.borderWidth = 2.0
			self.feedbackText.layer.cornerRadius = 4
			self.feedbackText.layer.borderColor = UIColor.white.cgColor
			self.stateText.layer.borderWidth = 3.0
			self.stateText.layer.cornerRadius = 6
			self.stateText.layer.borderColor = UIColor.white.cgColor
		}
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		UIApplication.shared.isIdleTimerDisabled = false
		if let analyser = analyser {
			analyser.stop()
		}
		if let frameExtractor = frameExtractor {
			frameExtractor.stopSession()
		}
	}
	
	// Creates the session's analyser.
	func makeClientAndListeners() {
		// Our url that will be provided. Fetch this from your backend!
		let url = "rpcs://<hostname>:<port>"
		// The api key for authentication. Fetch from your backend!
		let apiKey = "API-KEY"
		// The key of the exercise to analyse (1 = Squat).
		let exerciseKey = 1
		// Here 'self' is passed as listener with the event callbacks defined below.
		analyser = AnalyserFactory.createStreamingAnalyser(url: url,
			apiKey: apiKey, exerciseKey: exerciseKey, listener: self)
	}
	
	// Event callbacks:
	
	/*
	When the session state changes, the VaySessionStateChangedEvent is received
	with the new VaySessionState. The VaySessionState can be in one of the
	following states:
		noHuman - No human can be recognized in the provided image.
		positioning - The starting position has not been reached by the user.
		exercising - The starting position is fulfilled by the user.
	 */
	func onSessionStateChanged(_ event: VaySessionStateChangedEvent) {
		let previousState = state
		// Get the session state
		state = event.sessionState
		// UI changes according to state.
		DispatchQueue.main.async {
			self.stateText.text = String(describing: self.state).capitalized
			switch (self.state) {
			case VaySessionState.noHuman:
				self.stateText.layer.borderColor = UIColor.orange.cgColor
					break
			case VaySessionState.positioning:
				self.stateText.layer.borderColor = UIColor.yellow.cgColor
				break
			case VaySessionState.exercising:
				self.stateText.layer.borderColor = UIColor.green.cgColor
			}
		}
		// Display a success message when exercising state has been reached.
		if (previousState == VaySessionState.positioning &&
			state == VaySessionState.exercising) {
			DispatchQueue.main.async {
				self.feedbackText.text = "Positioning successful!"
				self.feedbackText.layer.borderColor = UIColor.green.cgColor
			}
		}
		if (previousState == VaySessionState.exercising &&
			state == VaySessionState.positioning) {
			DispatchQueue.main.async {
				self.feedbackText.layer.borderColor = UIColor.white.cgColor
			}
		}
	}
	
	/*
	 The VayPoseEvent is called when the human pose estimation analysed an image
	 and returns the results. The event includes a VayPose, that contains the
	 VayPoint for each VayBodyPointType. If you want to visualize the keypoints,
	 do it from here.
	*/
	func onPose(_ event: VayPoseEvent) {
		// Get the points for each body point type.
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
		DispatchQueue.main.async {
			self.overlay.setPoints(pointsArray: pointsArray, xScale: self.scaleX, yScale: self.scaleY, imgWidth: self.preview.frame.size.width)
			self.overlay.setNeedsDisplay() // Redraws the visualizing layer.
		}
	}

	/*
	Real time feedback is received here. While not in exercising state, the
	feedback received here can be used as positioning guidance, as seen below.
	During exercising, immediate feedback related to the exercise is received here.
	*/
	func onFeedback(_ event: VayFeedbackEvent) {
		let feedback = event.feedbacks
		if (state != VaySessionState.exercising && !feedback.isEmpty) {
			// Here the first of possibly multiple corrections is selected.
			let positioningGuidance = feedback[0].messages[0]
			DispatchQueue.main.async {
				self.feedbackText.text = positioningGuidance
			}
		}
	}

	/*
	 After every recognized repetition, a VayRepetitionEvent providing the
	 TimeInterval of the repetition and a list of all VayFeedback that were
	 received during the duration.
	*/
	func onRepetition(_ event: VayRepetitionEvent) {
		// Get all feedback that occurred during this repetition.
		let feedbacks = event.repetition.feedbacks
		if feedbacks.isEmpty {
			// If no feedback is received, the repetition was performed correctly.
			// Here only correct repetitions are counted.
			correctRepetitions += 1
			DispatchQueue.main.async {
				self.repetitionCount.text = "\(self.correctRepetitions)"
				self.feedbackText.text = "Great job!"
				self.feedbackText.layer.borderColor = UIColor.green.cgColor
			}
		} else {
			// Here the first of possibly multiple corrections is displayed.
			DispatchQueue.main.async {
				self.feedbackText.text = feedbacks[0].messages[0]
				self.feedbackText.layer.borderColor = UIColor.red.cgColor
			}
		}
	}

	/*
	 Should an error occur, the error event will contain information about it.
	 Possible error types are:
		serverError
		invalidInput
		connectionError
		timeout
		other
	*/
	func onError(_ event: VayErrorEvent) {
		let error = event.error
		// Log the error type.
		print("Error reason: \(error)")
	}
	
	/*
	 Called when the analyser is stopped.
	*/
	func onStop() {
		print("Analyser stopped!")
	}

	/*
	 This event is called when the analyser has successfully established a
	 connection with the server and the exercise has been successfully configured.
	*/
	func onReady(_ event: VayReadyEvent) {
	}

	/*
	 This event is called when metric values are received from the movement
	 analysis. The event includes a list of VayMetricValues. A VayMetricValue is
	 described by a value that belongs to a VayMetric and its confidence score.
	*/
	func onMetricValues(_ event: VayMetricValuesEvent) {
	}

	/*
	 The session quality quantifies the latency and the environment. If one of
	 these subjects changes, the VaySessionQualityChangedEvent is called where
	 the new ratings for both subjects are provided. Possible qualities are:
		bad - The quality is too bad to analyse images, no analysis is conducted.
		poor - The quality is poor but still good enough to perform the movement
			analysis, the accuracy might be affected.
		good - The quality is optimal.
	*/
	func onSessionQualityChanged(_ event: VaySessionQualityChangedEvent) {
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
	
	// Mirror image along the x-axis.
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
