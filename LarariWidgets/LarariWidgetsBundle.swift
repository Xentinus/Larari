import SwiftUI
import WidgetKit

/// Everything the widget extension shows: the Expiring soon and Shopping list widgets (N-05) and the shopping Live
/// Activity (N-04).
@main
struct LarariWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ExpiringSoonWidget()
        ShoppingListWidget()
        ShoppingLiveActivity()
    }
}
