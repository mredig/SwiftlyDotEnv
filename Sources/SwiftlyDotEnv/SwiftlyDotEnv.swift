import Foundation

extension SwiftlyDotEnv where Key == DefaultKey {
	/// Indicates whether `loadDotEnv` was called and completed successfully.
	public private(set) static var isLoaded = false
	private static let loadLock = NSLock()

	public static let defaultShared = SwiftlyDotEnv<DefaultKey>()

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

	/// The deserialized data from your .env file
	public private(set) static var environment: [String: String] = [:]

	/// Subscript access to the env, via the preference set by `preferredEnvironment`
	private subscript(key: String) -> String? {
		switch Self.preferredEnvironment {
		case .appEnvFirst:
			ProcessInfo.processInfo.environment[key] ?? Self.environment[key]
		case .dotEnvFileFirst:
			Self.environment[key] ?? ProcessInfo.processInfo.environment[key]
		case .dotEnvFileOnly:
			Self.environment[key]
		case .appEnvOnly:
			ProcessInfo.processInfo.environment[key]
		}
	}

	public static subscript(key: String) -> String? where Key.RawValue == String {
		SwiftlyDotEnv<DefaultKey>.defaultShared[key]
	}

	public enum SwiftlyDotEnvError: Error {
		case noEnvFile(forKey: String)
		case envFileNotUtf8Encoded
		case envFileImproperlyFormatted(example: String?)
		case alreadyLoaded
		case missingRequiredKeysInEnvFile(keys: [String])
	}

	private typealias DotEnvError = SwiftlyDotEnv<DefaultKey>.SwiftlyDotEnvError

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
		SwiftlyDotEnv<DefaultKey>.loadLock.lock()
		defer { SwiftlyDotEnv<DefaultKey>.loadLock.unlock() }
		guard SwiftlyDotEnv<DefaultKey>.isLoaded == false else { throw DotEnvError.alreadyLoaded }
		let envFiles = try getEnvFiles(from: searchDirectory ?? FileManager.default.currentWorkingDirectory)

		let currentEnv = envName ?? ProcessInfo.processInfo.environment["DOTENV"] ?? SwiftlyDotEnv<DefaultKey>.defaultString

		guard
			let envFileURL = envFiles[currentEnv]
		else {
			throw DotEnvError.noEnvFile(forKey: currentEnv)
		}

		let envData = try Data(contentsOf: envFileURL)

		let envDict = try processDataFormat(envData)

		if requiredKeys.isEmpty == false {
			var keys = Set(envDict.keys)
			keys = keys.union(ProcessInfo.processInfo.environment.keys)
			let missingKeys = requiredKeys.subtracting(keys)
			guard missingKeys.isEmpty else { throw DotEnvError.missingRequiredKeysInEnvFile(keys: missingKeys.sorted()) }
		}

		SwiftlyDotEnv<DefaultKey>.environment = envDict
		SwiftlyDotEnv<DefaultKey>.isLoaded = true
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

				let envName: String
				if #available(macOS 13.0, iOS 16.0, tvOS 16.0, *) {
					envName = filename
						.replacing(/^\.env\.?/, with: { _ in "" })
				} else {
					envName = filename
						.replacingOccurrences(of: ##"^\.env\.?"##, with: "", options: .regularExpression)
				}

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
		else { throw DotEnvError.envFileNotUtf8Encoded }

		let dict: [String: String] = [:]
		return try lines.reduce(into: dict, {
			let broken = $1.split(separator: "=", maxSplits: 1).map(String.init)
			guard broken.count == 2 else {
				throw DotEnvError.envFileImproperlyFormatted(example: $1)
			}

			$0[broken[0]] = broken[1]
		})
	}

	package static func resetForTests() {
		SwiftlyDotEnv<DefaultKey>.loadLock.lock()
		defer { SwiftlyDotEnv<DefaultKey>.loadLock.unlock() }

		SwiftlyDotEnv<DefaultKey>.environment = [:]
		SwiftlyDotEnv<DefaultKey>.isLoaded = false
		SwiftlyDotEnv<DefaultKey>.preferredEnvironment = .dotEnvFileFirst
	}
}


/// Loads and provides access to .env files in key/value format. You can provide files of basically any format
/// with `(Data) throws -> [String: String]` in the `loadDotEnv` static method. Whileit works out the box with
/// `String` Keys, you are encouraged to create a type safe, `RawRepresentable` type with the string values
/// encapsulated within to make retrieval more type safe and gain some assistance from auto complete.
///
/// All instances and generics utilize the same underlying environment, but you are able to retrieve the same data in
/// as many different ways as you want. Suggested usage is demonstrated in the `testTypedKeysInstance` test.
public struct SwiftlyDotEnv<Key: RawRepresentable> where Key.RawValue == String {
	public init() {}

	public static subscript(key: Key) -> String? where Key.RawValue == String {
		SwiftlyDotEnv<DefaultKey>.defaultShared[key.rawValue]
	}

	public subscript(key: Key) -> String? where Key.RawValue == String {
		SwiftlyDotEnv<DefaultKey>.defaultShared[key.rawValue]
	}
}
