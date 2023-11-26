import XCTest
@testable import SwiftlyDotEnv

final class SwiftlyDotEnvTests: XCTestCase {
	override func tearDown() {
		super.tearDown()
		SwiftlyDotEnv.resetForTests()
	}

	func testDefaultLoading() throws {
		XCTAssertFalse(SwiftlyDotEnv.isLoaded)
		try SwiftlyDotEnv.loadDotEnv()
		XCTAssertTrue(SwiftlyDotEnv.isLoaded)

		print(SwiftlyDotEnv.environment)
		XCTAssertEqual("default env loaded", SwiftlyDotEnv["testValue"])
	}

	func testLoadEnvWithSpace() throws {
		try SwiftlyDotEnv.loadDotEnv(envName: " dev")

		XCTAssertEqual("fart", SwiftlyDotEnv["PASS"])
		XCTAssertEqual("dev env loaded", SwiftlyDotEnv["testValue"])
	}

	func testLoadDebugEnv() throws {
		try SwiftlyDotEnv.loadDotEnv(envName: "debug")

		XCTAssertEqual("debug env loaded", SwiftlyDotEnv["testValue"])
	}

	func testLoadProdEnv() throws {
		try SwiftlyDotEnv.loadDotEnv(envName: "prod")

		XCTAssertEqual("prod env loaded", SwiftlyDotEnv["testValue"])
	}

	@available(macOS 13.0, iOS 16.0, tvOS 16.0, *)
	func testNonDefaultDirectory() throws {
		let path = URL.currentDirectory()
			.appending(components: "Alternate", "Dir ectory", "path")
		try SwiftlyDotEnv.loadDotEnv(from: path, envName: "other")

		XCTAssertEqual("alt path env loaded", SwiftlyDotEnv["testValue"])
	}

	func testRequiredKeysSuccess() throws {
		try SwiftlyDotEnv.loadDotEnv(
			envName: "prod",
			requiringKeys: [
				"PASS",
				"testValue",
				"IS_NOT_IN_FILE", // shouldn't exist in the file, but SHOULD exist in system env
			])

		XCTAssertEqual("prod env loaded", SwiftlyDotEnv["testValue"])
	}

	func testRequiredKeysFail() throws {
		let throwingBlock = {
			try SwiftlyDotEnv.loadDotEnv(
				envName: "prod",
				requiringKeys: [
					"PASS",
					"testValue",
					"faKEy"
				])
		}

		XCTAssertThrowsError(try throwingBlock())
	}

	@available(macOS 13.0, iOS 16.0, tvOS 16.0, *)
	func testLoadJSON() throws {
		let path = URL.currentDirectory()
			.appending(components: "Alternate", "Dir ectory", "path")
		try SwiftlyDotEnv.loadDotEnv(
			from: path,
			envName: "json") { data in
				guard
					let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
				else { throw SimpleTestError(message: "Not json format") }

				return json.reduce(into: [String: String]()) { 
					$0[$1.key] = ($1.value as? String) ?? "\($1.value)"
				}
			}

		XCTAssertEqual("json env loaded", SwiftlyDotEnv["testValue"])
		XCTAssertEqual("1", SwiftlyDotEnv["jsonLoadedBool"])
		XCTAssertEqual("true", SwiftlyDotEnv["jsonLoadedStr"])
	}

	func testTypedKeys() throws {
		try SwiftlyDotEnv.loadDotEnv(envName: "prod")

		XCTAssertEqual("prod env loaded", SwiftlyDotEnv[TestKeys.testValue])
	}
}

struct TestKeys: RawRepresentable {
	static let testValue = Self(rawValue: "testValue")

	let rawValue: String

	init(rawValue: String) {
		self.rawValue = rawValue
	}
}

struct SimpleTestError: Error {
	let message: String
}
