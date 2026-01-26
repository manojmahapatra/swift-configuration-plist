# swift-configuration-plist

A [Property List (plist)](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html) provider for [apple/swift-configuration](https://github.com/apple/swift-configuration).

## Usage

```swift
import Configuration
import ConfigurationPlist

let provider = try await FileProvider<PlistSnapshot>(filePath: "Config.plist")
let config = ConfigReader(provider: provider)

let timeout = config.int(forKey: "http.timeout", default: 30)
```

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/manojmahapatra/swift-configuration-plist", from: "0.1.0"),
]
```

Then add `ConfigurationPlist` to your target dependencies.

## Supported Types

- String
- Int
- Double
- Bool
- Data (as bytes)
- Arrays of String, Int, Double, Bool
- Nested dictionaries (flattened with dot notation)

## Example Plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>http</key>
    <dict>
        <key>timeout</key>
        <integer>30</integer>
    </dict>
    <key>features</key>
    <dict>
        <key>darkMode</key>
        <true/>
    </dict>
</dict>
</plist>
```

Access as `http.timeout` and `features.darkMode`.

## License

Apache 2.0
