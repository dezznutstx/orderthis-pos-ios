import Foundation

struct MenuItem: Identifiable, Hashable {
    let id: Int
    let name: String
    let price: Double
    let category: String
    let description: String
    let imageURL: URL?
    init(json: [String: Any]) {
        id = (json["id"] as? Int) ?? 0
        name = (json["name"] as? String) ?? (json["item_name"] as? String) ?? "Item"
        price = (json["price"] as? Double) ?? 0
        category = (json["category"] as? String) ?? "Misc"
        description = (json["description"] as? String) ?? ""
        imageURL = URL(string: (json["image_url"] as? String) ?? "")
    }
}

struct POSLine: Identifiable, Hashable {
    var id: Int { item.id }
    let item: MenuItem
    var quantity: Int
    var total: Double { item.price * Double(quantity) }
}

struct POSTab: Identifiable, Hashable {
    let id: Int
    let name: String
    let total: Double
    let cart: [[String: Any]]
    static func == (lhs: POSTab, rhs: POSTab) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    init(json: [String: Any]) {
        id = json["id"] as? Int ?? 0
        name = (json["tab_name"] as? String) ?? (json["customer_name"] as? String) ?? (json["name"] as? String) ?? "Tab \(id)"
        total = (json["total"] as? Double) ?? 0
        cart = json["cart"] as? [[String: Any]] ?? []
    }
}
