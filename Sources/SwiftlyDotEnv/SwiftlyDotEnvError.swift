import Foundation

public enum SwiftlyDotEnvError: Error {
	case noEnvFile(forKey: String)
	case envFileNotUtf8Encoded
	case envFileImproperlyFormatted(example: String?)
	case alreadyLoaded
	case missingRequiredKeysInEnvFile(keys: [String])
}
