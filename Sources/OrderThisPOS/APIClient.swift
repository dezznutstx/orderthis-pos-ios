import Foundation

struct PairResult: Decodable {
    let ok: Bool?
    let success: Bool?
    let error: String?
    let tenantURL: String?
    let tenantSlug: String?
    let deviceToken: String?
    let deviceID: Int?
    enum CodingKeys: String, CodingKey {
        case ok, success, error
        case tenantURL = "tenant_url", tenantSlug = "tenant_slug"
        case deviceToken = "device_token", deviceID = "device_id"
    }
}

final class APIClient {
    private let session: URLSession = .shared
    var baseURL: URL?

    func pair(code: String) async throws -> PairResult {
        var request = URLRequest(url: URL(string: "https://api.orderthis.website/pairing/activate")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "pairing_code": code, "device_type": "pos", "device_name": "iPhone / iPad", "app_version": "7.8.1-ios"
        ])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "Pairing request failed"
            throw APIError.message(text)
        }
        let result = try JSONDecoder().decode(PairResult.self, from: data)
        guard result.ok == true || result.success == true else { throw APIError.message(result.error ?? "Pairing failed") }
        if let url = result.tenantURL { baseURL = URL(string: url.hasSuffix("/") ? url : url + "/") }
        return result
    }

    func login(pin: String) async throws -> [String: Any] {
        let data = try await request(path: "mobile_login.php", query: [URLQueryItem(name: "pin", value: pin)])
        let json = try object(data)
        guard (json["success"] as? Bool ?? json["ok"] as? Bool ?? false) else {
            throw APIError.message(json["message"] as? String ?? "PIN was not accepted")
        }
        return json
    }

    func menu() async throws -> [MenuItem] {
        let json = try object(try await request(path: "api.php", query: [URLQueryItem(name: "action", value: "menu")]))
        let rows = (json["items"] as? [[String: Any]]) ?? (json["data"] as? [[String: Any]]) ?? []
        return rows.map(MenuItem.init(json:))
    }

    func tabs() async throws -> [POSTab] {
        let json = try object(try await request(path: "api.php", query: [URLQueryItem(name: "action", value: "tabs")]))
        return ((json["tabs"] as? [[String: Any]]) ?? []).map(POSTab.init(json:))
    }

    func createTab(name: String, staffID: Int, staffName: String) async throws -> POSTab {
        let json = try object(try await post(action: "save_tab", body: [
            "tab_name": name, "customer_name": name, "customer_phone": "", "customer_email": "", "notes": "",
            "staff_id": staffID, "server_id": staffID, "employee_id": staffID, "staff_name": staffName,
            "server_name": staffName, "cart": []
        ]))
        guard json["ok"] as? Bool == true else { throw APIError.message(json["error"] as? String ?? "Could not create tab") }
        return POSTab(json: ["id": json["tab_id"] as? Int ?? 0, "tab_name": name, "total": 0.0, "cart": []])
    }

    func sendOrder(tab: POSTab, lines: [POSLine], staffID: Int, staffName: String) async throws -> String {
        let cart: [[String: Any]] = lines.map { line in
            ["source_id": line.item.id, "menu_item_id": line.item.id, "item_name": line.item.name,
             "name": line.item.name, "qty": line.quantity, "quantity": line.quantity,
             "unit_price": line.item.price, "price": line.item.price, "line_total": line.total,
             "total": line.total, "mods_total": 0, "modifiers": [], "category": line.item.category,
             "item_notes": line.item.description, "notes": line.item.description, "send_to_kds": 1]
        }
        let common: [String: Any] = ["tab_id": tab.id, "tab_name": tab.name, "customer_name": tab.name,
            "customer_phone": "", "customer_email": "", "notes": "", "staff_id": staffID,
            "server_id": staffID, "employee_id": staffID, "staff_name": staffName, "server_name": staffName]
        var save = common; save["cart"] = cart
        let saved = try object(try await post(action: "save_tab", body: save))
        guard saved["ok"] as? Bool == true else { throw APIError.message(saved["error"] as? String ?? "Could not save tab") }
        var order = common
        order["tab_id"] = (saved["tab_id"] as? Int) ?? tab.id
        order["payment_method"] = "unpaid"; order["payment_status"] = "unpaid"
        order["promo_code"] = ""; order["manual_discount"] = 0; order["tip_amount"] = 0
        order["cart"] = cart
        let response = try object(try await post(action: "send_order", body: order))
        guard response["ok"] as? Bool == true || response["success"] as? Bool == true else {
            throw APIError.message(response["error"] as? String ?? "Order was not sent")
        }
        return response["order_number"] as? String ?? "Sent"
    }

    private func post(action: String, body: [String: Any]) async throws -> Data {
        var request = try makeRequest(path: "api.php", query: [URLQueryItem(name: "action", value: action)])
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await execute(request)
    }

    private func request(path: String, query: [URLQueryItem]) async throws -> Data {
        try await execute(makeRequest(path: path, query: query))
    }

    private func makeRequest(path: String, query: [URLQueryItem]) throws -> URLRequest {
        guard let baseURL else { throw APIError.message("Pair this device first") }
        let url = baseURL.appendingPathComponent(path)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = query
        return URLRequest(url: components.url!)
    }

    private func execute(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "Request failed"
            throw APIError.message("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0): \(text.prefix(350))")
        }
        return data
    }

    private func object(_ data: Data) throws -> [String: Any] {
        if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] { return root }
        if let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] { return ["items": rows, "tabs": rows] }
        return [:]
    }
}

enum APIError: Error, LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return "Unexpected error" }
}
