import Foundation

@MainActor final class POSModel: ObservableObject {
    @Published var paired = false
    @Published var loggedIn = false
    @Published var loading = false
    @Published var error = ""
    @Published var status = ""
    @Published var staffName = "Staff"
    @Published var staffID = 0
    @Published var tenantURL = ""
    @Published var menu: [MenuItem] = []
    @Published var tabs: [POSTab] = []
    @Published var selectedTab: POSTab?
    @Published var lines: [POSLine] = []
    @Published var category = "All"
    let api = APIClient()

    init() {
        tenantURL = UserDefaults.standard.string(forKey: "tenant_url") ?? ""
        paired = !tenantURL.isEmpty
        api.baseURL = URL(string: tenantURL)
    }
    var categories: [String] { ["All"] + Array(Set(menu.map(\.category))).sorted() }
    var visibleMenu: [MenuItem] { category == "All" ? menu : menu.filter { $0.category == category } }
    var total: Double { lines.reduce(0) { $0 + $1.total } }

    func pair(code: String) async {
        await run("Pairing device…") {
            let result = try await api.pair(code: code)
            guard let url = result.tenantURL, !url.isEmpty else { throw APIError.message("Pairing response did not include a restaurant address") }
            tenantURL = url; UserDefaults.standard.set(url, forKey: "tenant_url")
            paired = true; status = "Device paired"
        }
    }
    func login(pin: String) async {
        await run("Signing in…") {
            let response = try await api.login(pin: pin)
            let employee = response["employee"] as? [String: Any] ?? [:]
            staffID = employee["id"] as? Int ?? 0
            staffName = employee["name"] as? String ?? "Staff"
            loggedIn = true
            async let m = api.menu(); async let t = api.tabs()
            menu = try await m; tabs = try await t
            status = "Signed in as \(staffName)"
        }
    }
    func refresh() async {
        await run("Refreshing…") {
            async let m = api.menu(); async let t = api.tabs()
            menu = try await m; tabs = try await t
            status = "Updated"
        }
    }
    func createTab(name: String) async {
        await run("Creating tab…") {
            let tab = try await api.createTab(name: name, staffID: staffID, staffName: staffName)
            tabs.insert(tab, at: 0); selectedTab = tab; status = "Tab opened"
        }
    }
    func add(_ item: MenuItem) {
        if let index = lines.firstIndex(where: { $0.item.id == item.id }) { lines[index].quantity += 1 }
        else { lines.append(POSLine(item: item, quantity: 1)) }
    }
    func adjust(_ line: POSLine, by delta: Int) {
        guard let index = lines.firstIndex(where: { $0.item.id == line.item.id }) else { return }
        lines[index].quantity += delta
        if lines[index].quantity <= 0 { lines.remove(at: index) }
    }
    func send() async {
        guard let selectedTab else { error = "Open or select a tab first"; return }
        guard !lines.isEmpty else { error = "Add menu items first"; return }
        await run("Sending order…") {
            let number = try await api.sendOrder(tab: selectedTab, lines: lines, staffID: staffID, staffName: staffName)
            lines = []; status = "Order \(number) sent to kitchen"
            tabs = try await api.tabs()
        }
    }
    func logout() { loggedIn = false; lines = []; selectedTab = nil; status = "" }
    private func run(_ message: String, action: () async throws -> Void) async {
        loading = true; error = ""; status = message
        do { try await action() } catch { self.error = error.localizedDescription }
        loading = false
    }
}
