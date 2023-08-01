import Foundation
import OSLog

private let log = Logger(subsystem: "com.swiftly.env", category: "default")

public enum SwiftlyDotEnv {
	public static subscript(key: String) -> String? {
		environment[key] ?? ProcessInfo.processInfo.environment[key]
	}

	public private(set) static var environment: [String: String] = [:]

	static private let defaultString = "default"
	public static func loadDotEnv(_ processDataFormat: (Data) throws -> [String: String] = simpleEnvFileDecode) throws {
		let envFiles = try getEnvFiles()

		let currentEnv = ProcessInfo.processInfo.environment["DOTENV"]

		guard
			let envFileURL = currentEnv.flatMap({ envFiles[$0] }) ?? envFiles[defaultString]
		else {
			throw SwiftlyDotEnvError.noEnvFile(forKey: currentEnv ?? defaultString)
		}

		let envData = try Data(contentsOf: envFileURL)

		let envDict = try processDataFormat(envData)

		environment = envDict
	}

	public enum SwiftlyDotEnvError: Error {
		case noEnvFile(forKey: String)
		case envFileNotUtf8Encoded
		case envFileImproperlyFormatted(example: String?)
	}

	private static func getEnvFiles() throws -> [String: URL] {
		let fm = FileManager.default

		let contents = try fm.contentsOfDirectory(at: .currentDirectory(), includingPropertiesForKeys: nil)

		return contents
			.filter { $0.lastPathComponent.hasPrefix(".env") }
			.reduce(into: [String: URL]()) { dict, url in
				let filename = url.lastPathComponent
				guard filename != ".env" else {
					dict["default"] = url
					return
				}

				let envName = filename
					.replacing(/^\.env\.?/, with: { _ in "" })

				dict[envName] = url
			}
	}

	public static func simpleEnvFileDecode(inData: Data) throws -> [String: String] {
		guard
			let lines = String(data: inData, encoding: .utf8)?
				.split(separator: "\n")
				.map(String.init)
		else { throw SwiftlyDotEnvError.envFileNotUtf8Encoded }

		let dict: [String: String] = [:]
		return try lines.reduce(into: dict, {
			let broken = $1.split(separator: "=", maxSplits: 1).map(String.init)
			guard broken.count == 2 else {
				throw SwiftlyDotEnvError.envFileImproperlyFormatted(example: $1)
			}

			$0[broken[0]] = broken[1]
		})
	}
}
