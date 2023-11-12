import Foundation

public enum SwiftlyDotEnv {
	public private(set) static var isLoaded = false
	private static let loadLock = NSLock()

	public static subscript(key: String) -> String? {
		switch preferredEnvironment {
		case .appEnvFirst:
			ProcessInfo.processInfo.environment[key] ?? environment[key]
		case .dotEnvFileFirst:
			environment[key] ?? ProcessInfo.processInfo.environment[key]
		case .dotEnvFileOnly:
			environment[key]
		case .appEnvOnly:
			ProcessInfo.processInfo.environment[key]
		}
	}

	public private(set) static var environment: [String: String] = [:]

	public enum EnvPreference {
		case dotEnvFileFirst
		case appEnvFirst
		case dotEnvFileOnly
		case appEnvOnly
	}
	public static var preferredEnvironment: EnvPreference = .dotEnvFileFirst

	static public let defaultString = "default"
	public static func loadDotEnv(
		from searchDirectory: URL? = nil,
		envName: String? = nil,
		requiringKeys requiredKeys: Set<String> = [],
		_ processDataFormat: (Data) throws -> [String: String] = simpleEnvFileDecode
	) throws {
		loadLock.lock()
		defer { loadLock.unlock() }
		guard isLoaded == false else { throw SwiftlyDotEnvError.alreadyLoaded }
		let envFiles = try getEnvFiles(from: searchDirectory ?? .currentDirectory())

		let currentEnv = envName ?? ProcessInfo.processInfo.environment["DOTENV"] ?? defaultString

		guard
			let envFileURL = envFiles[currentEnv]
		else {
			throw SwiftlyDotEnvError.noEnvFile(forKey: currentEnv)
		}

		let envData = try Data(contentsOf: envFileURL)

		let envDict = try processDataFormat(envData)

		if requiredKeys.isEmpty == false {
			let keys = Set(envDict.keys)
			let missingKeys = requiredKeys.subtracting(keys)
			guard missingKeys.isEmpty else { throw SwiftlyDotEnvError.missingRequiredKeysInEnvFile(keys: missingKeys.sorted()) }
		}

		environment = envDict
		isLoaded = true
	}

	public enum SwiftlyDotEnvError: Error {
		case noEnvFile(forKey: String)
		case envFileNotUtf8Encoded
		case envFileImproperlyFormatted(example: String?)
		case alreadyLoaded
		case missingRequiredKeysInEnvFile(keys: [String])
	}

	private static func getEnvFiles(from directory: URL) throws -> [String: URL] {
		let fm = FileManager.default

		let sourceDirectory = directory
		let contents = try fm.contentsOfDirectory(at: sourceDirectory, includingPropertiesForKeys: nil)

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
