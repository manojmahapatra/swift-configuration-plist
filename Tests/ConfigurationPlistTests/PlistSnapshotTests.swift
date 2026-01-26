import Testing
import Configuration
@testable import ConfigurationPlist

@Suite struct PlistSnapshotTests {
    
    // MARK: - Basic Types
    
    @Test func parsesString() async throws {
        let snapshot = try makePlist("<key>name</key><string>hello</string>")
        #expect(snapshot.debugDescription.contains("name=hello"))
    }
    
    @Test func parsesInt() async throws {
        let snapshot = try makePlist("<key>count</key><integer>42</integer>")
        #expect(snapshot.debugDescription.contains("count=42"))
    }
    
    @Test func parsesDouble() async throws {
        let snapshot = try makePlist("<key>price</key><real>3.14</real>")
        #expect(snapshot.debugDescription.contains("price=3.14"))
    }
    
    @Test func parsesBoolTrue() async throws {
        let snapshot = try makePlist("<key>enabled</key><true/>")
        // Plist bools are stored as integers
        #expect(snapshot.debugDescription.contains("enabled=1"))
    }
    
    @Test func parsesBoolFalse() async throws {
        let snapshot = try makePlist("<key>disabled</key><false/>")
        #expect(snapshot.debugDescription.contains("disabled=0"))
    }
    
    @Test func parsesData() async throws {
        let snapshot = try makePlist("<key>blob</key><data>aGVsbG8=</data>")
        #expect(snapshot.debugDescription.contains("blob=aGVsbG8="))
    }
    
    // MARK: - Arrays
    
    @Test func parsesStringArray() async throws {
        let snapshot = try makePlist("<key>tags</key><array><string>a</string><string>b</string></array>")
        #expect(snapshot.debugDescription.contains("tags=a,b"))
    }
    
    @Test func parsesIntArray() async throws {
        let snapshot = try makePlist("<key>nums</key><array><integer>1</integer><integer>2</integer></array>")
        #expect(snapshot.debugDescription.contains("nums=1,2"))
    }
    
    @Test func parsesDoubleArray() async throws {
        let snapshot = try makePlist("<key>vals</key><array><real>1.1</real><real>2.2</real></array>")
        #expect(snapshot.debugDescription.contains("vals=1.1,2.2"))
    }
    
    @Test func parsesBoolArray() async throws {
        let snapshot = try makePlist("<key>flags</key><array><true/><false/></array>")
        // Plist bools are stored as integers
        #expect(snapshot.debugDescription.contains("flags=1,0"))
    }
    
    // MARK: - Nested Dictionaries
    
    @Test func parsesNestedDict() async throws {
        let snapshot = try makePlist("""
            <key>http</key><dict>
                <key>timeout</key><integer>30</integer>
            </dict>
        """)
        #expect(snapshot.debugDescription.contains("http.timeout=30"))
    }
    
    @Test func parsesDeeplyNested() async throws {
        let snapshot = try makePlist("""
            <key>a</key><dict>
                <key>b</key><dict>
                    <key>c</key><string>deep</string>
                </dict>
            </dict>
        """)
        #expect(snapshot.debugDescription.contains("a.b.c=deep"))
    }
    
    // MARK: - Secrets
    
    @Test func marksSecretsAsRedacted() async throws {
        let options = PlistSnapshot.ParsingOptions(
            secretsSpecifier: .specific(["password"])
        )
        let snapshot = try makePlist("<key>password</key><string>secret123</string>", options: options)
        #expect(snapshot.debugDescription.contains("password=<REDACTED>"))
        #expect(!snapshot.debugDescription.contains("secret123"))
    }
    
    @Test func nonSecretsNotRedacted() async throws {
        let options = PlistSnapshot.ParsingOptions(
            secretsSpecifier: .specific(["password"])
        )
        let snapshot = try makePlist("<key>username</key><string>admin</string>", options: options)
        #expect(snapshot.debugDescription.contains("username=admin"))
    }
    
    // MARK: - Errors
    
    @Test func throwsOnTopLevelNotDict() async throws {
        let plist = "<?xml version=\"1.0\"?><plist version=\"1.0\"><string>not a dict</string></plist>"
        let data = plist.data(using: .utf8)!
        #expect(throws: PlistSnapshot.PlistError.self) {
            try data.withUnsafeBytes { buffer in
                try PlistSnapshot(data: RawSpan(_unsafeBytes: buffer), providerName: "test", parsingOptions: .default)
            }
        }
    }
    
    // MARK: - Description
    
    @Test func description() async throws {
        let snapshot = try makePlist("<key>a</key><string>1</string><key>b</key><string>2</string>")
        #expect(snapshot.description == "test[2 values]")
    }
    
    @Test func valueCount() async throws {
        let snapshot = try makePlist("""
            <key>http</key><dict>
                <key>timeout</key><integer>30</integer>
                <key>endpoint</key><string>api.example.com</string>
            </dict>
            <key>debug</key><true/>
        """)
        #expect(snapshot.description == "test[3 values]")
    }
    
    // MARK: - Helpers
    
    func makePlist(_ content: String, options: PlistSnapshot.ParsingOptions = .default) throws -> PlistSnapshot {
        let plist = "<?xml version=\"1.0\"?><plist version=\"1.0\"><dict>\(content)</dict></plist>"
        let data = plist.data(using: .utf8)!
        return try data.withUnsafeBytes { buffer in
            try PlistSnapshot(data: RawSpan(_unsafeBytes: buffer), providerName: "test", parsingOptions: options)
        }
    }
}
