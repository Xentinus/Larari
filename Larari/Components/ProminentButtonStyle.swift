import SwiftUI

extension View {
    /// `.borderedProminent` with a label that stays readable on the accent in both appearances (X-04, user pick A,
    /// 2026-10-12): the `OnAccent` asset is white on the Mocha tint in light mode and dark Mocha (#2B2118) on the
    /// light dark-mode tint, where white read at 1.9:1.
    func prominentButtonStyle() -> some View {
        buttonStyle(.borderedProminent).foregroundStyle(Color.onAccent)
    }
}
