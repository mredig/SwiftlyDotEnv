import Foundation
import SwiftlyDotEnv


@main
struct Test {
	static func main() async throws {
		try SwiftlyDotEnv.loadDotEnv()

		print("ran: \(SwiftlyDotEnv["USER"])")
	}
}
