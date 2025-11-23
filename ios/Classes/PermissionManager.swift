import Foundation
import AVFoundation
import os.log

class PermissionManager {
  private let logger = Logger(subsystem: "com.whisper_kit", category: "PermissionManager")
  private let audioSession = AVAudioSession.sharedInstance()

  enum PermissionType {
    case microphone
    case documents

    var description: String {
      switch self {
      case .microphone:
        return "Microphone"
      case .documents:
        return "Documents"
      }
    }
  }

  enum PermissionStatus {
    case authorized
    case denied
    case notDetermined
    case restricted
    case limited

    var description: String {
      switch self {
      case .authorized:
        return "Authorized"
      case .denied:
        return "Denied"
      case .notDetermined:
        return "Not Determined"
      case .restricted:
        return "Restricted"
      case .limited:
        return "Limited"
      }
    }
  }

  // MARK: - Microphone Permissions

  func requestMicrophonePermission(completion: @escaping (PermissionStatus) -> Void) {
    logger.info("Requesting microphone permission")

    // Check current status first
    let currentStatus = getMicrophonePermissionStatus()
    if currentStatus != .notDetermined {
      completion(currentStatus)
      return
    }

    audioSession.requestRecordPermission { granted in
      DispatchQueue.main.async {
        let status: PermissionStatus = granted ? .authorized : .denied
        self.logger.info("Microphone permission result: \(status.description)")
        completion(status)
      }
    }
  }

  func getMicrophonePermissionStatus() -> PermissionStatus {
    let status = audioSession.recordPermission
    logger.debug("Microphone permission status: \(status.rawValue)")

    switch status {
    case .granted:
      return .authorized
    case .denied:
      return .denied
    case .undetermined:
      return .notDetermined
    @unknown default:
      return .notDetermined
    }
  }

  // MARK: - Documents/Storage Permissions

  func requestDocumentsPermission(completion: @escaping (Bool) -> Void) {
    logger.info("Requesting documents permission")

    DispatchQueue.global(qos: .userInitiated).async {
      let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

      if let path = documentsPath {
        // Test write access
        let testFile = path.appendingPathComponent(".permission_test")

        do {
          try "test".data(using: .utf8)?.write(to: testFile)
          try FileManager.default.removeItem(at: testFile)

          DispatchQueue.main.async {
            self.logger.info("Documents permission granted")
            completion(true)
          }
        } catch {
          DispatchQueue.main.async {
            self.logger.error("Documents permission denied: \(error.localizedDescription)")
            completion(false)
          }
        }
      } else {
        DispatchQueue.main.async {
          self.logger.error("Unable to access documents directory")
          completion(false)
        }
      }
    }
  }

  func getDocumentsPermissionStatus() -> PermissionStatus {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

    guard let path = documentsPath else {
      return .denied
    }

    // Test write access
    let testFile = path.appendingPathComponent(".permission_test")

    do {
      try "test".data(using: .utf8)?.write(to: testFile)
      try FileManager.default.removeItem(at: testFile)
      return .authorized
    } catch {
      return .denied
    }
  }

  // MARK: - Combined Permission Checks

  func checkAllRequiredPermissions() -> [PermissionType: PermissionStatus] {
    logger.info("Checking all required permissions")

    var permissions: [PermissionType: PermissionStatus] = [:]

    permissions[.microphone] = getMicrophonePermissionStatus()
    permissions[.documents] = getDocumentsPermissionStatus()

    logger.info("Permission statuses: \(permissions)")
    return permissions
  }

  func requestAllRequiredPermissions(completion: @escaping ([PermissionType: PermissionStatus]) -> Void) {
    logger.info("Requesting all required permissions")

    var permissions: [PermissionType: PermissionStatus] = [:]

    // Request microphone permission first
    requestMicrophonePermission { micStatus in
      permissions[.microphone] = micStatus

      // Then request documents permission
      self.requestDocumentsPermission { docsGranted in
        permissions[.documents] = docsGranted ? .authorized : .denied

        DispatchQueue.main.async {
          completion(permissions)
        }
      }
    }
  }

  // MARK: - Permission Utilities

  func openAppSettings() {
    logger.info("Opening app settings")

    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
      logger.error("Unable to create settings URL")
      return
    }

    if UIApplication.shared.canOpenURL(settingsURL) {
      UIApplication.shared.open(settingsURL) { success in
        self.logger.info("App settings opened: \(success)")
      }
    } else {
      logger.error("Cannot open app settings")
    }
  }

  func isPermissionGranted(for type: PermissionType) -> Bool {
    let status: PermissionStatus

    switch type {
    case .microphone:
      status = getMicrophonePermissionStatus()
    case .documents:
      status = getDocumentsPermissionStatus()
    }

    return status == .authorized
  }

  func shouldShowPermissionRationale(for type: PermissionType) -> Bool {
    let status: PermissionStatus

    switch type {
    case .microphone:
      status = getMicrophonePermissionStatus()
    case .documents:
      status = getDocumentsPermissionStatus()
    }

    return status == .denied
  }

  // MARK: - Permission Descriptions

  func getPermissionDescription(for type: PermissionType) -> String {
    switch type {
    case .microphone:
      return "Microphone access is required for speech-to-text transcription. Whisper Kit needs to record audio to convert speech to text."
    case .documents:
      return "Documents access is required to store Whisper models and audio files for offline processing."
    }
  }

  func getPermissionDeniedMessage(for type: PermissionType) -> String {
    switch type {
    case .microphone:
      return "Microphone permission was denied. You can enable it in Settings to use speech recognition features."
    case .documents:
      return "Documents permission was denied. You can enable it in Settings to store models and audio files."
    }
  }
}