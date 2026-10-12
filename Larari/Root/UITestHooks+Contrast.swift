#if DEBUG
import Foundation

extension UITestHooks {
    /// `-uiTestIncreaseContrast`: the scene resolves colours as with Settings ▸ Accessibility ▸ Increase Contrast, so
    /// the accessibility audit checks the high-contrast accent (X-04 1A: Mocha 500 by default, Mocha 800 there).
    static var increasesContrast: Bool { isActive && contains("-uiTestIncreaseContrast") }

    /// `-uiTestDarkMode`: the scene is dark whatever the device is set to, so the audit checks dark mode too.
    static var forcesDarkMode: Bool { isActive && contains("-uiTestDarkMode") }
}
#endif
