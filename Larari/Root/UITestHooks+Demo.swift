#if DEBUG
import Foundation

extension UITestHooks {
    /// `-uiTestDemo`: the App Store screenshot data (`DemoSeed`), in the app's language. Only honoured under
    /// `-uiTestAccountState`, i.e. the in-memory store.
    static var isDemo: Bool { isActive && contains("-uiTestDemo") }
}
#endif
