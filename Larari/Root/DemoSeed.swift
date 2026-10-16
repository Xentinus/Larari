#if DEBUG
import CoreData
import Foundation
import LarariCore

/// App Store screenshot data for `-uiTestDemo` launches (T-02): a full household inventory with product photos,
/// a shopping list and price history, named in the app's language (English, Hungarian or German).
/// The photos are `DemoPhotos/demo-*.jpg`, which Release builds leave out (`EXCLUDED_SOURCE_FILE_NAMES`).
@MainActor
enum DemoSeed {
    enum Language { case en, hu, de }

    static var language: Language {
        switch Bundle.main.preferredLocalizations.first?.prefix(2) {
        case "hu": .hu
        case "de": .de
        default: .en
        }
    }

    /// One name per language, in the order en, hu, de.
    struct Words {
        let en: String, hu: String, de: String
        init(_ en: String, _ hu: String, _ de: String) { self.en = en; self.hu = hu; self.de = de }
        var text: String {
            switch DemoSeed.language {
            case .en: en
            case .hu: hu
            case .de: de
            }
        }
    }

    enum Place { case fridge, pantry, freezer, fruitBowl, none }

    struct Item {
        let photo: String
        let name: Words
        let category: Words
        let unit: MeasureUnit
        let quantity: Decimal
        /// Days from today; nil means no expiry date.
        let expires: Int?
        let place: Place
        /// Price for the quantity, in the language's currency (USD, HUF, EUR).
        let price: (en: Decimal, hu: Decimal, de: Decimal)?
        var isFavorite = false
    }

    static let dairy = Words("Dairy", "Tejtermék", "Milchprodukte")
    static let bakery = Words("Bakery", "Pékáru", "Backwaren")
    static let fruit = Words("Fruit", "Gyümölcs", "Obst")
    static let vegetables = Words("Vegetables", "Zöldség", "Gemüse")
    static let meat = Words("Meat", "Hús", "Fleisch")
    static let staples = Words("Staples", "Alapanyag", "Grundnahrungsmittel")
    static let drinks = Words("Drinks", "Ital", "Getränke")
    static let frozen = Words("Frozen", "Fagyasztott", "Tiefkühlware")

    static func d(_ text: String) -> Decimal { Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) ?? 0 }

    static let items: [Item] = [
        Item(photo: "milk", name: Words("Milk", "Tej", "Milch"), category: dairy, unit: .liter, quantity: 1, expires: 2,
             place: .fridge, price: (d("1.29"), 459, d("1.19")), isFavorite: true),
        Item(photo: "bread", name: Words("Sourdough bread", "Kovászos kenyér", "Sauerteigbrot"), category: bakery,
             unit: .piece, quantity: 1, expires: -1, place: .pantry, price: (d("4.50"), 1290, d("3.90"))),
        Item(photo: "chicken", name: Words("Chicken breast", "Csirkemell", "Hähnchenbrust"), category: meat,
             unit: .kilogram, quantity: d("0.6"), expires: 1, place: .fridge, price: (d("7.20"), 2390, d("6.49"))),
        Item(photo: "strawberries", name: Words("Strawberries", "Eper", "Erdbeeren"), category: fruit, unit: .kilogram,
             quantity: d("0.5"), expires: 2, place: .fridge, price: (d("4.99"), 1490, d("3.99"))),
        Item(photo: "yogurt", name: Words("Greek yogurt", "Görög joghurt", "Griechischer Joghurt"), category: dairy,
             unit: .piece, quantity: 4, expires: 3, place: .fridge, price: nil),
        Item(photo: "tomatoes", name: Words("Cherry tomatoes", "Koktélparadicsom", "Kirschtomaten"),
             category: vegetables, unit: .kilogram, quantity: d("0.5"), expires: 4, place: .fridge, price: nil),
        Item(photo: "cucumber", name: Words("Cucumber", "Uborka", "Gurke"), category: vegetables, unit: .piece,
             quantity: 2, expires: 5, place: .fridge, price: nil),
        Item(photo: "oj", name: Words("Orange juice", "Narancslé", "Orangensaft"), category: drinks, unit: .liter,
             quantity: 1, expires: 6, place: .fridge, price: nil),
        Item(photo: "pepper", name: Words("Bell pepper", "Paprika", "Paprika"), category: vegetables, unit: .piece,
             quantity: 3, expires: 6, place: .fridge, price: nil),
        Item(photo: "sourcream", name: Words("Sour cream", "Tejföl", "Saure Sahne"), category: dairy, unit: .piece,
             quantity: 1, expires: 7, place: .fridge, price: nil),
        Item(photo: "cheese", name: Words("Cheese", "Sajt", "Käse"), category: dairy, unit: .kilogram,
             quantity: d("0.3"), expires: 9, place: .fridge, price: (d("6.80"), 2190, d("4.99"))),
        Item(photo: "eggs", name: Words("Eggs", "Tojás", "Eier"), category: dairy, unit: .piece, quantity: 10,
             expires: 12, place: .fridge, price: (d("3.99"), 1190, d("2.99"))),
        Item(photo: "lemons", name: Words("Lemons", "Citrom", "Zitronen"), category: fruit, unit: .piece, quantity: 4,
             expires: 12, place: .fruitBowl, price: nil),
        Item(photo: "bananas", name: Words("Bananas", "Banán", "Bananen"), category: fruit, unit: .piece, quantity: 6,
             expires: 3, place: .fruitBowl, price: nil),
        Item(photo: "apples", name: Words("Apples", "Alma", "Äpfel"), category: fruit, unit: .kilogram,
             quantity: d("1.5"), expires: 10, place: .fruitBowl, price: nil),
        Item(photo: "carrots", name: Words("Carrots", "Répa", "Karotten"), category: vegetables, unit: .kilogram,
             quantity: 1, expires: 14, place: .fridge, price: nil),
        Item(photo: "butter", name: Words("Butter", "Vaj", "Butter"), category: dairy, unit: .pack, quantity: 1,
             expires: 20, place: .fridge, price: nil),
        Item(photo: "potatoes", name: Words("Potatoes", "Burgonya", "Kartoffeln"), category: vegetables,
             unit: .kilogram, quantity: d("2.5"), expires: 21, place: .pantry, price: nil),
        Item(photo: "onions", name: Words("Red onions", "Lilahagyma", "Rote Zwiebeln"), category: vegetables,
             unit: .kilogram, quantity: 1, expires: 30, place: .pantry, price: nil),
        Item(photo: "coffee", name: Words("Coffee beans", "Szemes kávé", "Kaffeebohnen"), category: drinks,
             unit: .kilogram, quantity: d("0.5"), expires: 120, place: .pantry, price: (d("9.99"), 4290, d("8.49")),
             isFavorite: true),
        Item(photo: "flour", name: Words("Flour", "Liszt", "Mehl"), category: staples, unit: .kilogram, quantity: 2,
             expires: 180, place: .pantry, price: nil),
        Item(photo: "peas", name: Words("Green peas", "Zöldborsó", "Erbsen"), category: frozen, unit: .kilogram,
             quantity: d("0.45"), expires: 200, place: .freezer, price: nil),
        Item(photo: "rice", name: Words("Rice", "Rizs", "Reis"), category: staples, unit: .kilogram, quantity: 1,
             expires: 300, place: .pantry, price: nil),
        Item(photo: "pasta", name: Words("Pasta", "Tészta", "Nudeln"), category: staples, unit: .pack, quantity: 3,
             expires: 365, place: .pantry, price: nil),
        Item(photo: "oliveoil", name: Words("Olive oil", "Olívaolaj", "Olivenöl"), category: staples,
             unit: .bottle, quantity: 1, expires: 400, place: .pantry, price: (d("8.99"), 3490, d("7.99"))),
    ]

    static var currency: String {
        switch language {
        case .en: "USD"
        case .hu: "HUF"
        case .de: "EUR"
        }
    }

    static func price(_ item: Item) -> Decimal? {
        guard let price = item.price else { return nil }
        switch language {
        case .en: return price.en
        case .hu: return price.hu
        case .de: return price.de
        }
    }

    static func photo(_ name: String) -> Data? {
        Bundle.main.url(forResource: "demo-\(name)", withExtension: "jpg").flatMap { try? Data(contentsOf: $0) }
    }

    static func populate(_ container: ServiceContainer, in space: Space) async throws {
        guard try container.products.products(in: space).isEmpty else { return }

        let locations = container.storageLocations
        let fridge = try locations.create(in: space, name: Words("Fridge", "Hűtő", "Kühlschrank").text, color: .blue,
                                          isFreezer: false)
        let pantry = try locations.create(in: space, name: Words("Pantry", "Kamra", "Vorratskammer").text,
                                          color: .orange, isFreezer: false)
        let freezer = try locations.create(in: space, name: Words("Freezer", "Fagyasztó", "Gefrierschrank").text,
                                           color: .teal, isFreezer: true)
        let fruitBowl = try locations.create(in: space, name: Words("Fruit bowl", "Gyümölcstál", "Obstschale").text,
                                             color: .green, isFreezer: false)
        func location(_ place: Place) -> StorageLocation? {
            switch place {
            case .fridge: fridge
            case .pantry: pantry
            case .freezer: freezer
            case .fruitBowl: fruitBowl
            case .none: nil
            }
        }

        let market = try container.shoppingLocations.upsert(
            StoreResult(mapItemIdentifier: "demo-market", name: Words("Market Hall", "Vásárcsarnok", "Markthalle").text,
                        latitude: 47.4870, longitude: 19.0582), in: space)
        if let address = StoreAddress(short: Words("Main Street 12", "Fővám tér 1., Budapest", "Hauptstraße 12").text,
                                      category: "MKPOICategoryFoodMarket") {
            container.storeAddressCache.set(address, for: "demo-market")
        }
        let corner = try container.shoppingLocations.upsert(
            StoreResult(mapItemIdentifier: "demo-corner", name: Words("Corner Shop", "Sarki bolt", "Eckladen").text,
                        latitude: 47.4979, longitude: 19.0402), in: space)
        if let address = StoreAddress(short: Words("Park Lane 3", "Fő utca 3., Budapest", "Parkweg 3").text,
                                      category: "MKPOICategoryGrocery") {
            container.storeAddressCache.set(address, for: "demo-corner")
        }

        let inventory = container.inventory
        let calendar = inventory.calendar
        let today = calendar.startOfDay(for: inventory.currentDate())
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today) ?? today }

        var products: [String: Product] = [:]
        for item in items {
            let product = try await container.products.create(
                in: space, draft: ProductDraft(name: item.name.text, category: item.category.text,
                                               defaultUnit: item.unit, isFavorite: item.isFavorite,
                                               imageData: photo(item.photo)))
            products[item.photo] = product
            try inventory.addStock(product: product, quantity: item.quantity, unit: item.unit,
                                               expiresAt: item.expires.map(day), purchasedAt: day(-2),
                                               price: price(item), currency: price(item) == nil ? nil : currency,
                                               storageLocation: location(item.place),
                                               shoppingLocation: price(item) == nil ? nil : market)
        }

        // Six months of milk, coffee, eggs and cheese prices, so the product detail draws a trend.
        let history: [(String, [Decimal])] = [
            ("milk", language == .hu ? [419, 429, 439, 449, 469, 459]
                : language == .de ? [d("1.05"), d("1.09"), d("1.09"), d("1.15"), d("1.19"), d("1.19")]
                : [d("1.09"), d("1.15"), d("1.19"), d("1.19"), d("1.25"), d("1.29")]),
            ("coffee", language == .hu ? [3890, 3990, 4190, 4290, 4490, 4290]
                : language == .de ? [d("7.49"), d("7.99"), d("7.99"), d("8.49"), d("8.99"), d("8.49")]
                : [d("8.49"), d("8.99"), d("9.49"), d("9.49"), d("10.49"), d("9.99")]),
            ("eggs", language == .hu ? [990, 1050, 1090, 1150, 1190, 1190]
                : language == .de ? [d("2.49"), d("2.59"), d("2.79"), d("2.79"), d("2.99"), d("2.99")]
                : [d("3.29"), d("3.49"), d("3.69"), d("3.79"), d("3.99"), d("3.99")]),
        ]
        for (key, prices) in history {
            guard let product = products[key], let unit = items.first(where: { $0.photo == key })?.unit else { continue }
            for (index, value) in prices.enumerated() {
                let store = index.isMultiple(of: 2) ? market : corner
                try inventory.recordPurchase(product: product, quantity: 1, unit: unit, price: value,
                                                 currency: currency, store: store, purchasedAt: day(-180 + index * 30),
                                                 commit: false)
            }
        }
        try inventory.saveIfNeeded()

        let shopping = container.shopping
        let weekly = try shopping.createList(name: Words("Weekly shop", "Heti bevásárlás", "Wocheneinkauf").text,
                                             in: space)
        let weekend = try shopping.createList(name: Words("Weekend", "Hétvége", "Wochenende").text, in: space)
        let weeklyItems: [(String, Decimal, ShoppingLocation?)] = [
            ("milk", 2, market), ("bread", 1, corner), ("eggs", 10, market), ("bananas", 6, market),
            ("butter", 1, corner), ("coffee", d("0.5"), market),
        ]
        for (key, quantity, store) in weeklyItems {
            guard let product = products[key] else { continue }
            try shopping.addItem(to: weekly, product: product, quantity: quantity, shoppingLocation: store)
        }
        for (key, quantity) in [("strawberries", 1), ("cheese", d("0.3")), ("oj", 2)] as [(String, Decimal)] {
            guard let product = products[key] else { continue }
            try shopping.addItem(to: weekend, product: product, quantity: quantity, shoppingLocation: market)
        }
        try shopping.addItem(to: weekend, customName: Words("Napkins", "Szalvéta", "Servietten").text)

        try await populateHousehold(container)
    }

    /// A shared household with three more members, for the family-sharing screenshot. Local mode lists Member
    /// records only (no CloudKit participants), so the others are plain records with a name, colour and photo.
    static func populateHousehold(_ container: ServiceContainer) async throws {
        guard let sharing = container.sharing else { return }
        let me = Words("Emma", "Anna", "Lena")
        let home = try await sharing.createHousehold(name: Words("Our home", "Otthon", "Zuhause").text,
                                                     ownerDisplayName: me.text)
        if let members = container.members {
            try members.ensureCurrentMember(in: home, displayName: me.text, avatar: photo("member-mom"),
                                           colorKey: "mocha")
        }
        let others: [(String, Words, String, String)] = [
            ("_demo_partner", Words("Liam", "Bence", "Jonas"), "sky", "member-dad"),
            ("_demo_kid1", Words("Olivia", "Zsófi", "Mia"), "rose", "member-girl"),
            ("_demo_kid2", Words("Noah", "Marci", "Paul"), "lime", "member-boy"),
        ]
        for (record, name, color, picture) in others {
            let member = container.spaceStore.insert(Member.self, in: home, by: record)
            member.space = home
            member.userRecordName = record
            member.colorSeed = record
            member.displayName = name.text
            member.colorKey = color
            member.avatar = try photo(picture).map(ImageProcessor.prepare)
        }
        try container.context.save()
    }
}
#endif
