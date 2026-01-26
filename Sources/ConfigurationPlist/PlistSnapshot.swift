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
        /// A decoder for converting string values to byte arrays.
        public var bytesDecoder: any ConfigBytesFromStringDecoder
        
        /// A specifier for determining which configuration values should be treated as secrets.
        public var secretsSpecifier: SecretsSpecifier<String, any Sendable>
        
        public init(
            bytesDecoder: some ConfigBytesFromStringDecoder = .base64,
            secretsSpecifier: SecretsSpecifier<String, any Sendable> = .none
        ) {
            self.bytesDecoder = bytesDecoder
            self.secretsSpecifier = secretsSpecifier
        }
        
        public static let `default` = ParsingOptions()
    }

    private let values: [String: ValueWrapper]
    private let bytesDecoder: any ConfigBytesFromStringDecoder
    public let providerName: String

    struct ValueWrapper: CustomStringConvertible, Sendable {
        var value: PlistValue
        var isSecret: Bool
        
        var description: String {
            isSecret ? "<REDACTED>" : "\(value)"
        }
    }

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
        self.values = try Self.parseValues(dict, keyPath: [], secretsSpecifier: parsingOptions.secretsSpecifier)
        self.bytesDecoder = parsingOptions.bytesDecoder
        self.providerName = providerName
    }

    private static func parseValues(
        _ dict: [String: Any],
        keyPath: [String],
        secretsSpecifier: SecretsSpecifier<String, any Sendable>
    ) throws -> [String: ValueWrapper] {
        var result: [String: ValueWrapper] = [:]
        for (key, value) in dict {
            let fullKey = (keyPath + [key]).joined(separator: ".")
            switch value {
            case let nested as [String: Any]:
                let nestedValues = try parseValues(nested, keyPath: keyPath + [key], secretsSpecifier: secretsSpecifier)
                result.merge(nestedValues) { _, new in new }
            case let s as String:
                let isSecret = secretsSpecifier.isSecret(key: fullKey, value: s)
                result[fullKey] = ValueWrapper(value: .string(s), isSecret: isSecret)
            case let i as Int:
                let isSecret = secretsSpecifier.isSecret(key: fullKey, value: i)
                result[fullKey] = ValueWrapper(value: .int(i), isSecret: isSecret)
            case let d as Double:
                let isSecret = secretsSpecifier.isSecret(key: fullKey, value: d)
                result[fullKey] = ValueWrapper(value: .double(d), isSecret: isSecret)
            case let b as Bool:
                let isSecret = secretsSpecifier.isSecret(key: fullKey, value: b)
                result[fullKey] = ValueWrapper(value: .bool(b), isSecret: isSecret)
            case let data as Data:
                let isSecret = secretsSpecifier.isSecret(key: fullKey, value: data)
                result[fullKey] = ValueWrapper(value: .data(data), isSecret: isSecret)
            case let arr as [String]:
                let isSecret = secretsSpecifier.isSecret(key: fullKey, value: arr)
                result[fullKey] = ValueWrapper(value: .stringArray(arr), isSecret: isSecret)
            case let arr as [Int]:
                let isSecret = secretsSpecifier.isSecret(key: fullKey, value: arr)
                result[fullKey] = ValueWrapper(value: .intArray(arr), isSecret: isSecret)
            case let arr as [Double]:
                let isSecret = secretsSpecifier.isSecret(key: fullKey, value: arr)
                result[fullKey] = ValueWrapper(value: .doubleArray(arr), isSecret: isSecret)
            case let arr as [Bool]:
                let isSecret = secretsSpecifier.isSecret(key: fullKey, value: arr)
                result[fullKey] = ValueWrapper(value: .boolArray(arr), isSecret: isSecret)
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
        guard let wrapper = values[encodedKey] else {
            return LookupResult(encodedKey: encodedKey, value: nil)
        }
        let plistValue = wrapper.value
        let content: ConfigContent = switch (type, plistValue) {
        case (.string, .string(let s)): .string(s)
        case (.int, .int(let i)): .int(i)
        case (.int, .bool(let b)): .int(b ? 1 : 0)
        case (.double, .double(let d)): .double(d)
        case (.double, .int(let i)): .double(Double(i))
        case (.bool, .bool(let b)): .bool(b)
        case (.bool, .int(let i)): .bool(i != 0)
        case (.bytes, .data(let d)): .bytes([UInt8](d))
        case (.bytes, .string(let s)):
            if let decoded = bytesDecoder.decode(s) {
                .bytes(decoded)
            } else {
                throw PlistError.typeMismatch(encodedKey, type)
            }
        case (.stringArray, .stringArray(let a)): .stringArray(a)
        case (.intArray, .intArray(let a)): .intArray(a)
        case (.doubleArray, .doubleArray(let a)): .doubleArray(a)
        case (.boolArray, .boolArray(let a)): .boolArray(a)
        default:
            throw PlistError.typeMismatch(encodedKey, type)
        }
        return LookupResult(encodedKey: encodedKey, value: ConfigValue(content, isSecret: wrapper.isSecret))
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
