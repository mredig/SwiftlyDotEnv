import Foundation

public struct DefaultKey: RawRepresentable {
	public let rawValue: String

	public init?(rawValue: String) {
		self.rawValue = rawValue
	}
}
