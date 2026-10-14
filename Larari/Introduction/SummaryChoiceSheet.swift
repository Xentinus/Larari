import LarariCore
import SwiftUI

/// "When should we notify you?" (P2-10a, G-A): after "Get started" got notification permission, the daily summary,
/// the weekly overview or both, "both" preselected. "Done" writes the Settings ▸ Larari switches; a swipe keeps them.
struct SummaryChoiceSheet: View {
    @Bindable var model: IntroductionModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.onAccent)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityHidden(true)
                Text("intro.summary.title")
                    .font(.title.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("intro.summary.subtitle")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
                IntroChoiceGroup {
                    row(.daily, symbol: "sun.max", title: "intro.summary.daily", detail: "intro.summary.daily.detail",
                        identifier: "introduction.summary.daily")
                    Divider().padding(.leading, 58)
                    row(.weekly, symbol: "calendar", title: "intro.summary.weekly",
                        detail: "intro.summary.weekly.detail", identifier: "introduction.summary.weekly")
                    Divider().padding(.leading, 58)
                    row(.all, symbol: "bell.badge", title: "intro.summary.both", detail: "intro.summary.both.detail",
                        identifier: "introduction.summary.both")
                }
                Text("intro.summary.hint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 520)
            .padding(.horizontal, 24)
            .padding(.top, 36)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            Button {
                model.confirmSummaryChoice()
            } label: {
                Text("common.done").frame(maxWidth: .infinity)
            }
            .prominentButtonStyle()
            .controlSize(.large)
            .frame(maxWidth: 520)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .accessibilityIdentifier("introduction.summary.done")
        }
        .presentationDragIndicator(.visible)
        .tint(.accentColor)
    }

    private func row(_ kinds: NotificationKinds, symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey,
                     identifier: String) -> some View {
        IntroChoiceRow(symbol: symbol, title: title, detail: detail, isSelected: model.summaryChoice == kinds,
                       identifier: identifier) { model.summaryChoice = kinds }
    }
}
