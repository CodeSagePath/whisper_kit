import XCTest
import Flutter
@testable import whisper_kit

final class WhisperKitTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testGetPlatformVersion() throws {
        let plugin = WhisperKitPlugin()
        let call = FlutterMethodCall(methodName: "getPlatformVersion", arguments: nil)

        let expectation = XCTestExpectation(description: "Result callback called")

        plugin.handle(call) { result in
            XCTAssertEqual(result as? String, "iOS " + UIDevice.current.systemVersion)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testPermissionCheck() throws {
        let plugin = WhisperKitPlugin()
        let call = FlutterMethodCall(methodName: "checkMicrophonePermission", arguments: nil)

        let expectation = XCTestExpectation(description: "Permission check completed")

        plugin.handle(call) { result in
            XCTAssertNotNil(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testModelManagerInitialization() throws {
        let modelManager = ModelManager()
        let modelsDirectory = modelManager.getModelsDirectory()

        XCTAssertTrue(modelsDirectory.path.contains("whisper_models"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: modelsDirectory.path))
    }

    func testAvailableModels() throws {
        let modelManager = ModelManager()
        let availableModels = modelManager.getAvailableModels()

        XCTAssertFalse(availableModels.isEmpty)
        XCTAssertTrue(availableModels.contains { $0.name == "tiny" })
        XCTAssertTrue(availableModels.contains { $0.name == "base" })
        XCTAssertTrue(availableModels.contains { $0.name == "small" })
    }

    func testDownloadedModels() throws {
        let modelManager = ModelManager()
        let downloadedModels = modelManager.getDownloadedModels()

        // Initially no models should be downloaded
        XCTAssertNotNil(downloadedModels)
        XCTAssertTrue(downloadedModels.allSatisfy { model in
            modelManager.validateModel(modelName: model.name)
        })
    }

    func testModelValidation() throws {
        let modelManager = ModelManager()

        // Test validation for non-existent model
        XCTAssertFalse(modelManager.validateModel(modelName: "nonexistent"))

        // Test validation for known model (will likely fail if not downloaded)
        let isValid = modelManager.validateModel(modelName: "tiny")
        // isValid will be false if model is not downloaded, true if downloaded and valid
        XCTAssertTrue(isValid == modelManager.isModelDownloaded(modelName: "tiny"))
    }

    func testStorageInfo() throws {
        let modelManager = ModelManager()
        let totalSize = modelManager.getTotalModelsSize()
        let availableSpace = modelManager.getAvailableDiskSpace()

        XCTAssertGreaterThanOrEqual(totalSize, 0)
        XCTAssertGreaterThanOrEqual(availableSpace, 0)
    }

    func testCanDownloadModel() throws {
        let modelManager = ModelManager()
        let (canDownload, reason) = modelManager.canDownloadModel(modelName: "tiny")

        // We can't guarantee that download is possible (depends on disk space),
        // but we can check that the function returns a reasonable result
        if !canDownload {
            XCTAssertNotNil(reason)
            XCTAssertFalse(reason!.isEmpty)
        }
    }
}