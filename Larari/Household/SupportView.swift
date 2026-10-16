import LarariCore
import SafariServices
import SwiftUI

/// The space settings sheet's last section (X-03, Apple-native option B, user choice 2026-09-26): one button
/// that opens our support URL in an in-app Safari sheet, with the guide §9.2 copy as its footer. A donation that
/// grants nothing: no state, no purchase, no unlock.
struct SupportSection: View {
    @State private var showsPage = false

    var body: some View {
        Section {
            Button {
                showsPage = true
            } label: {
                HStack {
                    Label("support.open", systemImage: "heart")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityIdentifier("support.open")
            .accessibilityHint(Text("support.open.hint"))
            // On the button, not the Section: a List hands a Section's modifiers to its header, row and footer,
            // and three presenters for one binding closed every sheet the moment the page opened.
            .sheet(isPresented: $showsPage) {
                page
            }
        } header: {
            Text(verbatim: "Larari")
        } footer: {
            Text("support.body")
                .accessibilityIdentifier("support.body")
        }
    }

    @ViewBuilder private var page: some View {
        #if DEBUG
        if UITestHooks.isActive {
            // UI tests make no network calls: a local stand-in takes the web page's place.
            Text(verbatim: "support.page").accessibilityIdentifier("support.page")
        } else {
            SafariView(url: SupportLink.url).ignoresSafeArea()
        }
        #else
        SafariView(url: SupportLink.url).ignoresSafeArea()
        #endif
    }
}

/// `SFSafariViewController`: the real Safari UI for our own URL, never a web view that imitates a checkout.
private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
