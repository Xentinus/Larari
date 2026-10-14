import LarariCore
import SwiftUI

extension IntroductionPage {
    var title: LocalizedStringKey {
        switch self {
        case .welcome: "intro.welcome.title"
        case .purchase: "intro.purchase.title"
        case .notifications: "intro.notifications.title"
        case .stores: "intro.stores.title"
        }
    }

    /// The welcome page has its feature rows instead.
    var body: LocalizedStringKey? {
        switch self {
        case .welcome: nil
        case .purchase: "intro.purchase.body"
        case .notifications: "intro.notifications.body"
        case .stores: "intro.stores.body"
        }
    }

    var hint: LocalizedStringKey? {
        switch self {
        case .welcome: nil
        case .purchase: "intro.purchase.hint"
        case .notifications: "intro.notifications.hint"
        case .stores: "intro.stores.hint"
        }
    }
}

/// One page (P1-10b, the Apple Welcome pattern): a title, then the welcome page's feature rows, a page's choice or
/// the store page's sample reminder, and its hint. Side by side when height is compact.
struct IntroductionPageView: View {
    let page: IntroductionPage
    @Bindable var model: IntroductionModel
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Scrolled to the end, the last line clears the page dots drawn over the page.
    private let bottomMargin: CGFloat = 40

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
                header(alignment: .leading).frame(maxWidth: 300)
                content
            }
            .frame(maxWidth: 760)
        } else {
            VStack(spacing: 28) {
                header(alignment: .center)
                content
            }
            .frame(maxWidth: 520)
        }
    }

    private func header(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 12) {
            if page == .welcome {
                IntroLogoImage(size: 88)
                    .padding(.bottom, 4)
            } else if page == .stores {
                SampleStoreReminder()
                    .padding(.bottom, 8)
            }
            Text(page.title)
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)   // full height at the largest sizes (X-04)
                .accessibilityAddTraits(.isHeader)
            if let body = page.body {
                Text(body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
    }

    private var content: some View {
        VStack(spacing: 12) {
            switch page {
            case .welcome: FeatureList()
            case .purchase: PurchaseChoice(addsToInventory: $model.addsToInventory)
            case .notifications: SummaryChoice(choice: $model.summaryChoice)
            case .stores: EmptyView()
            }
            if let hint = page.hint {
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The app icon with the icon's corner shape. Decorative: the title names the app.
private struct IntroLogoImage: View {
    let size: CGFloat

    var body: some View {
        Image("IntroLogo")
            .resizable()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// The store page's picture: a store reminder as it arrives (P4-06), with a sample store and count. Decorative.
private struct SampleStoreReminder: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            IntroLogoImage(size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text("intro.stores.sample.title").font(.subheadline.weight(.semibold))
                Text("intro.stores.sample.body").font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .multilineTextAlignment(.leading)
        .padding(12)
        .frame(maxWidth: 340)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .dynamicTypeSize(...DynamicTypeSize.large)
        .accessibilityHidden(true)
    }
}

/// The welcome page's four rows: what Larari does, sharing, and where the data lives.
private struct FeatureList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            FeatureRow(symbol: "shippingbox", title: "intro.welcome.inventory.title",
                       detail: "intro.welcome.inventory.detail")
            FeatureRow(symbol: "cart", title: "intro.welcome.shopping.title", detail: "intro.welcome.shopping.detail")
            FeatureRow(symbol: "person.2", title: "intro.welcome.spaces.title", detail: "intro.welcome.spaces.detail")
            FeatureRow(symbol: "checkmark.shield", title: "intro.welcome.privacy.title",
                       detail: "intro.welcome.privacy.detail")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A symbol, a bold title and a short line, read as one element.
private struct FeatureRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(Palette.mochaButtonBackground)
                .frame(width: 40)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .multilineTextAlignment(.leading)
        .accessibilityElement(children: .combine)
    }
}

/// The notifications page's three rows, one selection, "both" preselected (P2-10a). Written by Get started when
/// notifications are allowed.
private struct SummaryChoice: View {
    @Binding var choice: NotificationKinds

    var body: some View {
        IntroChoiceGroup {
            row(.daily, symbol: "sun.max", title: "intro.summary.daily", detail: "intro.summary.daily.detail",
                identifier: "introduction.summary.daily")
            Divider().padding(.leading, 58)
            row(.weekly, symbol: "calendar", title: "intro.summary.weekly", detail: "intro.summary.weekly.detail",
                identifier: "introduction.summary.weekly")
            Divider().padding(.leading, 58)
            row(.all, symbol: "bell.badge", title: "intro.summary.both", detail: "intro.summary.both.detail",
                identifier: "introduction.summary.both")
        }
    }

    private func row(_ kinds: NotificationKinds, symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey,
                     identifier: String) -> some View {
        IntroChoiceRow(symbol: symbol, title: title, detail: detail, isSelected: choice == kinds,
                       identifier: identifier) { choice = kinds }
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
