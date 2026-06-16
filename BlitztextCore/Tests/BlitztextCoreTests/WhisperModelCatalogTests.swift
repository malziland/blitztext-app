import XCTest
import BlitztextCore

final class WhisperModelCatalogTests: XCTestCase {
    func testNormalizedModelNameTrims() {
        XCTAssertEqual(WhisperModelCatalog.normalizedModelName("  some-model \n"), "some-model")
    }

    func testNormalizedModelNameEmptyFallsBackToRecommended() {
        XCTAssertEqual(WhisperModelCatalog.normalizedModelName("   "), WhisperModelCatalog.recommendedFastModelName)
        XCTAssertEqual(WhisperModelCatalog.normalizedModelName(""), WhisperModelCatalog.recommendedFastModelName)
    }

    func testSupportedModelsContainsKnownThree() {
        XCTAssertEqual(WhisperModelCatalog.supportedModelNames.count, 3)
        XCTAssertTrue(WhisperModelCatalog.supportedModelNames.contains(WhisperModelCatalog.recommendedFastModelName))
        XCTAssertTrue(WhisperModelCatalog.supportedModelNames.contains(WhisperModelCatalog.fastModelName))
        XCTAssertTrue(WhisperModelCatalog.supportedModelNames.contains(WhisperModelCatalog.defaultModelName))
    }

    func testModelPageURLRoutesKnownModels() {
        XCTAssertEqual(WhisperModelCatalog.modelPageURL(for: WhisperModelCatalog.recommendedFastModelName), WhisperModelCatalog.recommendedFastModelPageURL)
        XCTAssertEqual(WhisperModelCatalog.modelPageURL(for: WhisperModelCatalog.fastModelName), WhisperModelCatalog.fastModelPageURL)
        XCTAssertEqual(WhisperModelCatalog.modelPageURL(for: WhisperModelCatalog.defaultModelName), WhisperModelCatalog.defaultModelPageURL)
    }

    func testModelPageURLBuildsRepoURLForUnknownModel() {
        let url = WhisperModelCatalog.modelPageURL(for: "custom_model_42")
        XCTAssertEqual(url.absoluteString, "https://huggingface.co/argmaxinc/whisperkit-coreml/tree/main/custom_model_42")
    }
}
