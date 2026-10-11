import Foundation
import Testing
@testable import LarariShared

@Suite("ShoppingActivityContent")
struct ShoppingActivityContentTests {
    func content(remaining: Int, done: Int) -> ShoppingActivityContent {
        ShoppingActivityContent(title: "Spar Budaörs", spaceName: "Otthon", listCount: 2, remainingCount: remaining,
                                doneCount: done)
    }

    @Test func countsAndFinishedState() {
        #expect(content(remaining: 5, done: 3).totalCount == 8)
        #expect(!content(remaining: 5, done: 3).isFinished)
        #expect(content(remaining: 0, done: 8).isFinished)
    }

    @Test func roundTripsThroughJSON() throws {
        let original = content(remaining: 2, done: 1)
        let decoded = try JSONDecoder().decode(ShoppingActivityContent.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test func scopesRoundTripThroughJSON() throws {
        for scope in [ShoppingActivityScope.store(UUID()), .stores([UUID(), UUID()]), .chain("tesco expressz")] {
            let decoded = try JSONDecoder().decode(ShoppingActivityScope.self, from: JSONEncoder().encode(scope))
            #expect(decoded == scope)
        }
    }

    @Test func onlyAChainScopeIsAChain() {
        #expect(ShoppingActivityScope.chain("spar").isChain)
        #expect(!ShoppingActivityScope.store(UUID()).isChain)
        #expect(!ShoppingActivityScope.stores([UUID(), UUID()]).isChain)
    }

    @Test func staysWellUnderActivityKitsFourKilobytes() throws {
        let long = String(repeating: "é", count: 40)
        let full = ShoppingActivityContent(title: long, spaceName: long, listCount: 99, remainingCount: 999,
                                           doneCount: 999)
        #expect(try JSONEncoder().encode(full).count < 512)
    }
}
