import Flutter
import AVFoundation
import Photos
import UIKit

public class RawCameraPlugin: NSObject, FlutterPlugin {
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var currentDevice: AVCaptureDevice?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "raw_camera_service", binaryMessenger: registrar.messenger())
        let instance = RawCameraPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isRawCaptureSupported":
            isRawCaptureSupported(result: result)
        case "getAvailableRawFormats":
            getAvailableRawFormats(result: result)
        case "captureRawImage":
            captureRawImage(call: call, result: result)
        case "configureCameraSettings":
            configureCameraSettings(call: call, result: result)
        case "startCameraPreview":
            startCameraPreview(result: result)
        case "stopCameraPreview":
            stopCameraPreview(result: result)
        case "getCameraCapabilities":
            getCameraCapabilities(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func isRawCaptureSupported(result: @escaping FlutterResult) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            result(false)
            return
        }
        
        // Check if device supports RAW capture
        let photoOutput = AVCapturePhotoOutput()
        let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first
        result(rawFormat != nil)
    }
    
    private func getAvailableRawFormats(result: @escaping FlutterResult) {
        let photoOutput = AVCapturePhotoOutput()
        var formats: [String] = []
        
        if !photoOutput.availableRawPhotoPixelFormatTypes.isEmpty {
            formats.append("dng")
            formats.append("raw")
        }
        
        result(formats)
    }
    
    private func captureRawImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        let format = args["format"] as? String ?? "dng"
        let includeJpegPreview = args["includeJpegPreview"] as? Bool ?? true
        
        setupCameraSession { [weak self] success in
            if success {
                self?.performRawCapture(format: format, includeJpegPreview: includeJpegPreview, result: result)
            } else {
                result(FlutterError(code: "CAMERA_SETUP_FAILED", message: "Failed to setup camera", details: nil))
            }
        }
    }
    
    private func setupCameraSession(completion: @escaping (Bool) -> Void) {
        guard captureSession == nil else {
            completion(true)
            return
        }
        
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            completion(false)
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        self.captureSession = session
        self.photoOutput = photoOutput
        self.currentDevice = device
        
        completion(true)
    }
    
    private func performRawCapture(format: String, includeJpegPreview: Bool, result: @escaping FlutterResult) {
        guard let photoOutput = self.photoOutput,
              let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first else {
            result(FlutterError(code: "RAW_NOT_SUPPORTED", message: "RAW capture not supported", details: nil))
            return
        }
        
        var settings: AVCapturePhotoSettings
        
        if includeJpegPreview {
            settings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat,
                                            processedFormat: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        } else {
            settings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
        }
        
        // Configure settings for maximum quality
        settings.isHighResolutionPhotoEnabled = true
        settings.flashMode = .off // RAW typically doesn't use flash
        
        let delegate = PhotoCaptureDelegate(result: result, format: format)
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }
    
    private func configureCameraSettings(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let device = currentDevice,
              let args = call.arguments as? [String: Any] else {
            result(false)
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            // Configure ISO
            if let isoMode = args["isoMode"] as? String {
                if isoMode == "manual", let manualIso = args["manualIso"] as? Float {
                    device.setExposureModeCustom(duration: device.exposureDuration, iso: manualIso, completionHandler: nil)
                } else {
                    device.exposureMode = .autoExpose
                }
            }
            
            // Configure focus
            if let focusMode = args["focusMode"] as? String {
                if focusMode == "manual", let focusDistance = args["manualFocusDistance"] as? Float {
                    device.setFocusModeLocked(lensPosition: focusDistance, completionHandler: nil)
                } else {
                    device.focusMode = .autoFocus
                }
            }
            
            // Configure exposure
            if let exposureMode = args["exposureMode"] as? String {
                if exposureMode == "manual", let duration = args["exposureDuration"] as? Double {
                    let cmTime = CMTime(seconds: duration, preferredTimescale: 1000000000)
                    device.setExposureModeCustom(duration: cmTime, iso: device.iso, completionHandler: nil)
                } else {
                    device.exposureMode = .autoExpose
                }
            }
            
            // Configure image stabilization
            if let enableStabilization = args["enableImageStabilization"] as? Bool {
                if let connection = photoOutput?.connection(with: .video) {
                    if connection.isVideoStabilizationSupported {
                        connection.preferredVideoStabilizationMode = enableStabilization ? .auto : .off
                    }
                }
            }
            
            device.unlockForConfiguration()
            result(true)
        } catch {
            device.unlockForConfiguration()
            result(false)
        }
    }
    
    private func startCameraPreview(result: @escaping FlutterResult) {
        setupCameraSession { [weak self] success in
            if success {
                self?.captureSession?.startRunning()
                result(true)
            } else {
                result(false)
            }
        }
    }
    
    private func stopCameraPreview(result: @escaping FlutterResult) {
        captureSession?.stopRunning()
        result(true)
    }
    
    private func getCameraCapabilities(result: @escaping FlutterResult) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            result([:])
            return
        }
        
        let photoOutput = AVCapturePhotoOutput()
        
        let capabilities: [String: Any] = [
            "supportsRaw": !photoOutput.availableRawPhotoPixelFormatTypes.isEmpty,
            "maxResolution": [
                "width": device.activeFormat.highResolutionStillImageDimensions.width,
                "height": device.activeFormat.highResolutionStillImageDimensions.height
            ],
            "availableRawFormats": photoOutput.availableRawPhotoPixelFormatTypes,
            "supportsFlash": device.hasFlash,
            "supportsTorch": device.hasTorch,
            "minISO": device.activeFormat.minISO,
            "maxISO": device.activeFormat.maxISO,
            "minExposureDuration": CMTimeGetSeconds(device.activeFormat.minExposureDuration),
            "maxExposureDuration": CMTimeGetSeconds(device.activeFormat.maxExposureDuration)
        ]
        
        result(capabilities)
    }
}

// MARK: - Photo Capture Delegate
private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let result: FlutterResult
    private let format: String
    
    init(result: @escaping FlutterResult, format: String) {
        self.result = result
        self.format = format
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            result(FlutterError(code: "CAPTURE_FAILED", message: error.localizedDescription, details: nil))
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            result(FlutterError(code: "NO_IMAGE_DATA", message: "Failed to get image data", details: nil))
            return
        }
        
        // Save to Photos app and get file path
        saveImageToPhotos(imageData: imageData) { [weak self] filePath in
            if let filePath = filePath {
                self?.result(filePath)
            } else {
                self?.result(FlutterError(code: "SAVE_FAILED", message: "Failed to save image", details: nil))
            }
        }
    }
    
    private func saveImageToPhotos(imageData: Data, completion: @escaping (String?) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: imageData, options: nil)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        // For now, return a placeholder path - in a real implementation,
                        // you'd want to get the actual file path from the Photos library
                        completion("photo_library://raw_image_\(Date().timeIntervalSince1970)")
                    } else {
                        completion(nil)
                    }
                }
            }
        }
    }
}
