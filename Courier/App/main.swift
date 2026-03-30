// Explicit entry point — skips App.main() when the process is running under the test runner.
// xcodebuild sets XCTestSessionIdentifier in the environment for test runs, which lets us
// avoid calling CourierApp.main() (and creating an NSApplication) when tests are loading.
import AppKit

if ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] == nil {
    CourierApp.main()
}
