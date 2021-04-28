//
//  FrameExtractor.swift
//  Sample App
//
//  Created by Vay on 28.04.21.
//
//	This class was taken from the following medium post:
//	https://medium.com/ios-os-x-development/ios-camera-frames-extraction-d2c0f80ed05a
// This class has been left mostly undocumented, therefore if you wish to
// gain more insight on it, please take a look at the article above.
//

import AVFoundation
import UIKit

protocol FrameExtractorDelegate: class {
	func captured(image: UIImage)
}

class FrameExtractor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

	private let position = AVCaptureDevice.Position.front
	private let quality = AVCaptureSession.Preset.medium // Configure quality preset here.

	private var permissionGranted = false
	private let sessionQueue = DispatchQueue(label: "session queue")
	private let captureSession = AVCaptureSession()
	private let context = CIContext()

	weak var delegate: FrameExtractorDelegate?

	override init() {
		super.init()
		checkPermission()
		sessionQueue.async { [unowned self] in
			self.configureSession()
			self.captureSession.startRunning()
		}
	}

	func stopSession() {
		self.captureSession.stopRunning()
	}

	// MARK: AVSession configuration
	private func checkPermission() {
		switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
		case .authorized:
			permissionGranted = true
		case .notDetermined:
			requestPermission()
		default:
			permissionGranted = false
		}
	}
	
	private func requestPermission() {
		sessionQueue.suspend()
		AVCaptureDevice.requestAccess(for: AVMediaType.video) { [unowned self] granted in
			self.permissionGranted = granted
			self.sessionQueue.resume()
		}
	}
	
	private func configureSession() {
		guard permissionGranted else { return }
		captureSession.sessionPreset = quality
		guard let captureDevice = selectCaptureDevice() else { return }
		guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
		guard captureSession.canAddInput(captureDeviceInput) else { return }
		captureSession.addInput(captureDeviceInput)
		let videoOutput = AVCaptureVideoDataOutput()
		videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer"))
		guard captureSession.canAddOutput(videoOutput) else { return }
		captureSession.addOutput(videoOutput)
		guard let connection = videoOutput.connection(with: AVFoundation.AVMediaType.video) else { return }
		guard connection.isVideoOrientationSupported else { return }
		guard connection.isVideoMirroringSupported else { return }
		connection.videoOrientation = .portrait // Configure orientation here.
		connection.isVideoMirrored = position == .front
	}
	
	private func selectCaptureDevice() -> AVCaptureDevice? {
		return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInDualWideCamera, .builtInTelephotoCamera, .builtInTripleCamera, .builtInTrueDepthCamera, .builtInUltraWideCamera, .builtInWideAngleCamera], mediaType: .video, position: position).devices.filter() {
			($0 as AnyObject).hasMediaType(AVMediaType.video) &&
			($0 as AnyObject).position == position
		}.first
	}
	
	// MARK: Sample buffer to UIImage conversion
	private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
		guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
		let ciImage = CIImage(cvPixelBuffer: imageBuffer)
		guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
		return UIImage(cgImage: cgImage)
	}
	
	// MARK: AVCaptureVideoDataOutputSampleBufferDelegate
	func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		guard let uiImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
		DispatchQueue.main.async { [unowned self] in
			self.delegate?.captured(image: uiImage)
		}
	}
}
