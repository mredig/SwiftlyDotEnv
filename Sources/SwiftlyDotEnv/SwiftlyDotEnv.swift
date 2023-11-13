import Foundation

public enum SwiftlyDotEnv {
	/// Indicates whether `loadDotEnv` was called and completed successfully.
	public private(set) static var isLoaded = false
	private static let loadLock = NSLock()

	/// Subscript access to the env, via the preference set by `preferredEnvironment`
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

	/// The deserialized data from your .env file
	public private(set) static var environment: [String: String] = [:]

	/// options for differing behavior when requesting env vars
	public enum EnvPreference {
		/// Prioritizes values provided in the .env file, falling back to any value located in the native env vars
		case dotEnvFileFirst
		/// Prioritizes values provided in the .env file, ignoring any values located in the native env vars
		case dotEnvFileOnly
		/// Prioritizes values provided in the native env vars, falling back to any value located in the .env file
		case appEnvFirst
		/// Prioritizes values provided in the native env vars, ignoring any values located in the .env file
		case appEnvOnly
	}
	/// Set this to indicate what env source you prefer/require between your .env file and the native env vars. Defaults to `.dotEnvFileFirst`
	public static var preferredEnvironment: EnvPreference = .dotEnvFileFirst

	
	static public let defaultString = "default"
	
	
	/// Loads the .env file into memory so you can use it. This must be called early in your program, before any usage 
	/// of `SwiftlyDotEnv["MahKeys"]`
	/// - Parameters:
	///   - searchDirectory: The directory to search for your .env file(s) in. Defaults to `.currentDirectory()`
	///   - envName: The name of the environment you want to load (typically prod/staging/dev or something similar, but 
	///   the only limit is your imagination and your computer's memory for a really long string). If no value is 
	///   provided, the value for `DOTENV` will be referred to from the native env vars, finally defaulting to just 
	///   looking for a file simply named `.env`,
	///   - requiredKeys: Provide any keys that *must* exist, or an error will be thrown.
	///   - processDataFormat: A closure in the format of `(Data) throws -> [String: String]`. You can use this to allow 
	///   for any file format to store your env vars, as long as you can deserialize it in this closure.
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

	/// The default implementation for `processDataFormat` in `loadDotEnv`. This decoding requires that every env var
	/// provided be one per line and be in the format of `KEY=Value`. Everything after the *first* `=` in the line is
	/// considered a literal string value (and I guess before it as well for the key). Obviously a very simple format,
	/// but you can extend it with your own magic.
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

	package static func resetForTests() {
		loadLock.lock()
		defer { loadLock.unlock() }

		environment = [:]
		isLoaded = false
		preferredEnvironment = .dotEnvFileFirst
	}
}
