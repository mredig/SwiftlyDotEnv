import Foundation

extension FileManager {
	var currentWorkingDirectory: URL {
		URL(fileURLWithPath: currentDirectoryPath)
	}
}
