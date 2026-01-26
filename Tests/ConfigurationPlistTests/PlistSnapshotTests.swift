import Testing
import Configuration
@testable import ConfigurationPlist

@Suite struct PlistSnapshotTests {
    
    let testPlist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>http</key>
        <dict>
            <key>timeout</key>
            <integer>30</integer>
            <key>endpoint</key>
            <string>https://api.example.com</string>
        </dict>
        <key>features</key>
        <dict>
            <key>darkMode</key>
            <true/>
        </dict>
        <key>retryCount</key>
        <integer>3</integer>
    </dict>
    </plist>
    """
    
    @Test func parsesNestedValues() async throws {
        let data = testPlist.data(using: .utf8)!
        let snapshot = try data.withUnsafeBytes { buffer in
            try PlistSnapshot(data: RawSpan(_unsafeBytes: buffer), providerName: "test", parsingOptions: .default)
        }
        
        #expect(snapshot.description == "test[4 values]")
    }
    
    @Test func description() async throws {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict><key>name</key><string>test</string></dict></plist>
        """
        let data = plist.data(using: .utf8)!
        let snapshot = try data.withUnsafeBytes { buffer in
            try PlistSnapshot(data: RawSpan(_unsafeBytes: buffer), providerName: "config", parsingOptions: .default)
        }
        
        #expect(snapshot.description == "config[1 values]")
        #expect(snapshot.debugDescription.contains("name=test"))
    }
}
