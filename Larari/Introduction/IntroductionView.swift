import LarariCore
import SwiftUI

/// Swipeable first-launch introduction (P1-10, four pages since P1-10b) with page dots, Skip, Next and Get started.
/// The notifications and store pages ask for their permission with their main button and have "Not now" instead of
/// Skip (user pick X).
struct IntroductionView: View {
    @Bindable var model: IntroductionModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TabView(selection: $model.currentPage) {
            ForEach(IntroductionPage.allCases) { page in
                IntroductionPageView(page: page, model: model)
                    .tag(page)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        // The notifications page's Next moves on after the permission prompt, outside any withAnimation.
        .animation(reduceMotion ? nil : Motion.settle, value: model.currentPage)
        .safeAreaInset(edge: .top) {
            HStack {
                Spacer()
                if !model.asksPermission {
                    Button("intro.skip") { model.skip() }
                        .accessibilityIdentifier("introduction.skip")
                }
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 44)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                switch model.currentPage {
                case .welcome, .purchase:
                    Button {
                        withMotion(Motion.settle, reduceMotion: reduceMotion) { model.next() }
                    } label: {
                        Text("intro.next").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("introduction.next")
                case .notifications:
                    permissionButtons(title: "intro.next", identifier: "introduction.notifications.next",
                                      notNowIdentifier: "introduction.notifications.notNow") {
                        await model.allowNotifications()
                    } notNow: {
                        model.declineNotifications()
                    }
                case .stores:
                    permissionButtons(title: "intro.getStarted", identifier: "introduction.getStarted",
                                      notNowIdentifier: "introduction.stores.notNow") {
                        await model.finish()
                    } notNow: {
                        model.declineStoreReminders()
                    }
                }
            }
            .disabled(model.isAsking)
            .controlSize(.large)
            .frame(maxWidth: 520)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .tint(.accentColor)
    }

    /// The main button asks for the page's permission; "Not now" turns its switches off without asking.
    private func permissionButtons(title: LocalizedStringKey, identifier: String, notNowIdentifier: String,
                                   action: @escaping () async -> Void, notNow: @escaping () -> Void) -> some View {
        Group {
            Button {
                Task { await action() }
            } label: {
                Text(title).frame(maxWidth: .infinity)
            }
            .prominentButtonStyle()
            .accessibilityIdentifier(identifier)
            Button {
                withMotion(Motion.settle, reduceMotion: reduceMotion) { notNow() }
            } label: {
                Text("intro.notNow").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier(notNowIdentifier)
        }
    }
}
