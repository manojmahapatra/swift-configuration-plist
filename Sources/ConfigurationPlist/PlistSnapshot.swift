import Configuration
import Foundation

/// A snapshot of configuration values parsed from Property List (plist) data.
///
/// Use with `FileProvider` or `ReloadingFileProvider`:
///
/// ```swift
/// let provider = try await FileProvider<PlistSnapshot>(filePath: "Config.plist")
/// let config = ConfigReader(provider: provider)
/// ```
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
public struct PlistSnapshot: Sendable {

    public struct ParsingOptions: FileParsingOptions {
        public static let `default` = ParsingOptions()
    }

    private let values: [String: PlistValue]
    public let providerName: String

    enum PlistValue: CustomStringConvertible, Sendable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case data(Data)
        case stringArray([String])
        case intArray([Int])
        case doubleArray([Double])
        case boolArray([Bool])

        var description: String {
            switch self {
            case .string(let s): s
            case .int(let i): "\(i)"
            case .double(let d): "\(d)"
            case .bool(let b): "\(b)"
            case .data(let d): d.base64EncodedString()
            case .stringArray(let a): a.joined(separator: ",")
            case .intArray(let a): a.map { "\($0)" }.joined(separator: ",")
            case .doubleArray(let a): a.map { "\($0)" }.joined(separator: ",")
            case .boolArray(let a): a.map { "\($0)" }.joined(separator: ",")
            }
        }
    }

    public enum PlistError: Error {
        case topLevelNotDictionary
        case unsupportedType(String, String)
        case typeMismatch(String, ConfigType)
    }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
extension PlistSnapshot: FileConfigSnapshot {
    public init(data: RawSpan, providerName: String, parsingOptions: ParsingOptions) throws {
        let plist = try data.withUnsafeBytes { buffer in
            try PropertyListSerialization.propertyList(from: Data(buffer), format: nil)
        }
        guard let dict = plist as? [String: Any] else {
            throw PlistError.topLevelNotDictionary
        }
        self.values = try Self.parseValues(dict, keyPath: [])
        self.providerName = providerName
    }

    private static func parseValues(_ dict: [String: Any], keyPath: [String]) throws -> [String: PlistValue] {
        var result: [String: PlistValue] = [:]
        for (key, value) in dict {
            let fullKey = (keyPath + [key]).joined(separator: ".")
            switch value {
            case let nested as [String: Any]:
                let nestedValues = try parseValues(nested, keyPath: keyPath + [key])
                result.merge(nestedValues) { _, new in new }
            case let s as String:
                result[fullKey] = .string(s)
            case let i as Int:
                result[fullKey] = .int(i)
            case let d as Double:
                result[fullKey] = .double(d)
            case let b as Bool:
                result[fullKey] = .bool(b)
            case let data as Data:
                result[fullKey] = .data(data)
            case let arr as [String]:
                result[fullKey] = .stringArray(arr)
            case let arr as [Int]:
                result[fullKey] = .intArray(arr)
            case let arr as [Double]:
                result[fullKey] = .doubleArray(arr)
            case let arr as [Bool]:
                result[fullKey] = .boolArray(arr)
            default:
                throw PlistError.unsupportedType(fullKey, String(describing: type(of: value)))
            }
        }
        return result
    }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
extension PlistSnapshot: ConfigSnapshot {
    public func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        let encodedKey = key.components.joined(separator: ".")
        guard let plistValue = values[encodedKey] else {
            return LookupResult(encodedKey: encodedKey, value: nil)
        }
        let content: ConfigContent = switch (type, plistValue) {
        case (.string, .string(let s)): .string(s)
        case (.int, .int(let i)): .int(i)
        case (.int, .bool(let b)): .int(b ? 1 : 0)
        case (.double, .double(let d)): .double(d)
        case (.double, .int(let i)): .double(Double(i))
        case (.bool, .bool(let b)): .bool(b)
        case (.bool, .int(let i)): .bool(i != 0)
        case (.bytes, .data(let d)): .bytes([UInt8](d))
        case (.bytes, .string(let s)): .bytes([UInt8](s.utf8))
        case (.stringArray, .stringArray(let a)): .stringArray(a)
        case (.intArray, .intArray(let a)): .intArray(a)
        case (.doubleArray, .doubleArray(let a)): .doubleArray(a)
        case (.boolArray, .boolArray(let a)): .boolArray(a)
        default:
            throw PlistError.typeMismatch(encodedKey, type)
        }
        return LookupResult(encodedKey: encodedKey, value: ConfigValue(content, isSecret: false))
    }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
extension PlistSnapshot: CustomStringConvertible {
    public var description: String {
        "\(providerName)[\(values.count) values]"
    }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
extension PlistSnapshot: CustomDebugStringConvertible {
    public var debugDescription: String {
        let sorted = values.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        return "\(providerName)[\(values.count) values: \(sorted)]"
    }
}
