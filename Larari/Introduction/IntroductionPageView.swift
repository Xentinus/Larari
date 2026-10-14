import LarariCore
import SwiftUI

extension IntroductionPage {
    var title: LocalizedStringKey {
        switch self {
        case .welcome: "intro.welcome.title"
        case .free: "intro.free.title"
        case .inventory: "intro.inventory.title"
        case .shopping: "intro.shopping.title"
        case .purchase: "intro.purchase.title"
        case .spaces: "intro.spaces.title"
        case .privacy: "intro.privacy.title"
        case .notifications: "intro.notifications.title"
        }
    }

    var body: LocalizedStringKey {
        switch self {
        case .welcome: "intro.welcome.body"
        case .free: "intro.free.body"
        case .inventory: "intro.inventory.body"
        case .shopping: "intro.shopping.body"
        case .purchase: "intro.purchase.body"
        case .spaces: "intro.spaces.body"
        case .privacy: "intro.privacy.body"
        case .notifications: "intro.notifications.body"
        }
    }
}

/// One page: an animated scene, a title and a short text. Side by side when height is compact. The purchase page
/// (P4-07) adds its choice and the Settings hint under the text.
struct IntroductionPageView: View {
    let page: IntroductionPage
    let isActive: Bool
    @Binding var addsToInventory: Bool
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// The purchase page is the longest: scrolled to the end, its hint clears the page dots drawn over the page.
    private var bottomMargin: CGFloat { page == .purchase ? 40 : 0 }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                layout
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height - bottomMargin)
            }
            .scrollBounceBehavior(.basedOnSize)
            .contentMargins(.bottom, bottomMargin, for: .scrollContent)
        }
    }

    @ViewBuilder
    private var layout: some View {
        if verticalSizeClass == .compact {
            HStack(spacing: 40) {
                scene.frame(maxWidth: 340, maxHeight: 260)
                text(alignment: .leading)
            }
            .frame(maxWidth: 760)
        } else {
            VStack(spacing: 28) {
                // The purchase page's scene is shorter, so its choice clears the page dots.
                scene.frame(maxWidth: 340).frame(height: page == .purchase ? 190 : 300)
                text(alignment: .center)
            }
            .frame(maxWidth: 520)
        }
    }

    /// Capped at `.large`: the text scales fully, the illustration never pushes it off screen.
    private var scene: some View {
        IntroScene(page: page, isActive: isActive, addsToInventory: addsToInventory)
            .dynamicTypeSize(...DynamicTypeSize.large)
            .accessibilityHidden(true)
    }

    private func text(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 12) {
            Text(page.title)
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)   // full height at the largest sizes (X-04)
                .accessibilityAddTraits(.isHeader)
            Text(page.body)
                .font(.body)
                .foregroundStyle(.secondary)
            if page == .purchase {
                PurchaseChoice(addsToInventory: $addsToInventory)
                    .padding(.top, 10)
                Text("intro.purchase.hint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
    }
}

/// The purchase page's two rows, one selection: into inventory (the default) or only off the list. Written to the
/// setting at once by the model.
private struct PurchaseChoice: View {
    @Binding var addsToInventory: Bool

    var body: some View {
        IntroChoiceGroup {
            IntroChoiceRow(symbol: "shippingbox", title: "intro.purchase.inventory",
                           detail: "intro.purchase.inventory.detail", isSelected: addsToInventory,
                           identifier: "introduction.purchase.inventory") { addsToInventory = true }
            Divider().padding(.leading, 58)
            IntroChoiceRow(symbol: "list.bullet", title: "intro.purchase.listOnly",
                           detail: "intro.purchase.listOnly.detail", isSelected: !addsToInventory,
                           identifier: "introduction.purchase.listOnly") { addsToInventory = false }
        }
    }
}

/// The rounded group around an introduction choice's rows (P4-07, P2-10a).
struct IntroChoiceGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Color(uiColor: .secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .multilineTextAlignment(.leading)
    }
}

/// One selectable row of an introduction choice: a symbol, a title, a one-line detail and a check circle.
struct IntroChoiceRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let isSelected: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(Palette.mochaButtonBackground)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(isSelected ? Palette.mochaButtonForeground : Color(uiColor: .tertiaryLabel),
                                     isSelected ? Palette.mochaButtonBackground : Color(uiColor: .tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}
