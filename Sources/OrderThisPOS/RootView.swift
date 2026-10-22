import SwiftUI

private let orange = Color(red: 0.96, green: 0.36, blue: 0.06)
private let ink = Color(red: 0.10, green: 0.13, blue: 0.18)

struct RootView: View {
    @EnvironmentObject private var model: POSModel
    @State private var code = ""
    @State private var pin = ""
    @State private var showNewTab = false
    @State private var newTabName = ""

    var body: some View {
        Group {
            if !model.paired { pairing }
            else if !model.loggedIn { login }
            else { pointOfSale }
        }
        .tint(orange)
        .alert("Open a tab", isPresented: $showNewTab) {
            TextField("Customer or table name", text: $newTabName)
            Button("Cancel", role: .cancel) { newTabName = "" }
            Button("Open") {
                let name = newTabName.trimmingCharacters(in: .whitespacesAndNewlines)
                newTabName = ""
                Task { await model.createTab(name: name.isEmpty ? "Walk-in" : name) }
            }
        } message: { Text("Enter a name or table number.") }
    }

    private var pairing: some View {
        VStack(spacing: 20) {
            brandHeader
            Text("Pair this POS with your restaurant")
                .font(.title2.bold()).multilineTextAlignment(.center)
            Text("Enter the 6-digit code from KitchenOps.")
                .foregroundStyle(.secondary)
            TextField("000000", text: $code)
                .keyboardType(.numberPad).textContentType(.oneTimeCode)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center).padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.gray.opacity(0.2)))
                .onChange(of: code) { value in code = String(value.filter(\.isNumber).prefix(6)) }
            Button { Task { await model.pair(code: code) } } label: {
                actionLabel(model.loading ? "PAIRING…" : "PAIR DEVICE")
            }.disabled(model.loading || code.count != 6)
            feedback
        }
        .padding(24).frame(maxWidth: 480).frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.96, green: 0.97, blue: 0.98))
    }

    private var login: some View {
        VStack(spacing: 16) {
            brandHeader
            Text("Staff sign in").font(.title2.bold())
            SecureField("Enter staff PIN", text: $pin)
                .keyboardType(.numberPad).textContentType(.oneTimeCode)
                .multilineTextAlignment(.center).font(.title3.monospacedDigit())
                .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 12))
                .onChange(of: pin) { value in pin = String(value.filter(\.isNumber).prefix(10)) }
            Button { Task { await model.login(pin: pin) } } label: {
                actionLabel(model.loading ? "SIGNING IN…" : "SIGN IN")
            }.disabled(model.loading || pin.isEmpty)
            feedback
            Text("Restaurant device paired").font(.caption).foregroundStyle(.secondary)
        }
        .padding(24).frame(maxWidth: 460).frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.96, green: 0.97, blue: 0.98))
    }

    private var pointOfSale: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image("OrderThisLogo").resizable().scaledToFit().frame(width: 150, height: 48)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(model.staffName).font(.subheadline.bold())
                    Text(model.status).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Button { Task { await model.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.bordered)
                Button("Sign out") { model.logout() }.buttonStyle(.bordered)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(.white)
            Divider()
            tabStrip
            Divider()
            categoryStrip
            Divider()
            HStack(spacing: 0) {
                menuGrid
                Divider()
                cartPanel.frame(width: 310)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            feedback.padding(.horizontal, 12).padding(.bottom, 8)
        }
        .background(Color(red: 0.96, green: 0.97, blue: 0.98))
    }

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { showNewTab = true } label: {
                    Label("New tab", systemImage: "plus").font(.subheadline.bold())
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(orange, in: Capsule()).foregroundStyle(.white)
                }
                ForEach(model.tabs) { tab in
                    Button { model.selectedTab = tab } label: {
                        VStack(spacing: 2) {
                            Text(tab.name).font(.subheadline.bold()).lineLimit(1)
                            Text(tab.total, format: .currency(code: "USD")).font(.caption)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(model.selectedTab?.id == tab.id ? ink : .white, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(model.selectedTab?.id == tab.id ? .white : ink)
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 12).padding(.vertical, 8)
        }
        .background(Color(red: 0.96, green: 0.97, blue: 0.98))
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.categories, id: \.self) { category in
                    Button(category.capitalized) { model.category = category }
                        .font(.subheadline.bold()).padding(.horizontal, 14).padding(.vertical, 8)
                        .background(model.category == category ? orange.opacity(0.12) : .clear, in: Capsule())
                        .foregroundStyle(model.category == category ? orange : ink)
                }
            }.padding(.horizontal, 12).padding(.vertical, 4)
        }
    }

    private var menuGrid: some View {
        ScrollView {
            if model.visibleMenu.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "fork.knife").font(.largeTitle).foregroundStyle(.secondary)
                    Text(model.menu.isEmpty ? "Menu not loaded" : "No items").font(.headline)
                    Text(model.menu.isEmpty ? "Refresh to load the restaurant menu." : "Try another category.").font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.top, 60)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                    ForEach(model.visibleMenu) { item in
                        Button { model.add(item) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.name).font(.headline).multilineTextAlignment(.leading).lineLimit(2)
                                Spacer(minLength: 0)
                                HStack {
                                    Text(item.price, format: .currency(code: "USD")).font(.subheadline.bold())
                                    Spacer()
                                    Image(systemName: "plus.circle.fill").foregroundStyle(orange)
                                }
                            }
                            .padding(12).frame(maxWidth: .infinity, minHeight: 95, alignment: .leading)
                            .background(.white, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.05)))
                        }.buttonStyle(.plain).foregroundStyle(ink)
                    }
                }.padding(12)
            }
        }
    }

    private var cartPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Current order").font(.headline)
                Spacer()
                Text("\(model.lines.reduce(0) { $0 + $1.quantity }) items").font(.caption).foregroundStyle(.secondary)
            }
            if let tab = model.selectedTab {
                Label(tab.name, systemImage: "person.crop.circle").font(.subheadline.bold()).foregroundStyle(orange)
            } else {
                Text("Select or open a tab to send an order.").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(model.lines) { line in
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.item.name).font(.subheadline.bold())
                                Text(line.total, format: .currency(code: "USD")).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 2)
                            Button { model.adjust(line, by: -1) } label: { Image(systemName: "minus.circle") }
                            Text("\(line.quantity)").font(.subheadline.monospacedDigit())
                            Button { model.adjust(line, by: 1) } label: { Image(systemName: "plus.circle") }
                        }
                    }
                }
            }
            Divider()
            HStack { Text("Subtotal").font(.headline); Spacer(); Text(model.total, format: .currency(code: "USD")).font(.headline) }
            Button { Task { await model.send() } } label: { actionLabel(model.loading ? "SENDING…" : "SEND TO KITCHEN") }
                .disabled(model.loading || model.lines.isEmpty || model.selectedTab == nil)
            Text("Payment is handled separately in the POS workflow.").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(12).background(.white)
    }

    private var brandHeader: some View {
        VStack(spacing: 14) {
            Image("OrderThisLogo").resizable().scaledToFit().frame(maxWidth: 250, maxHeight: 90)
            Text("RESTAURANT POS").font(.caption.weight(.heavy)).tracking(2).foregroundStyle(orange)
        }
    }
    private var feedback: some View {
        Group {
            if !model.error.isEmpty { Text(model.error).foregroundStyle(.red).font(.footnote.bold()).multilineTextAlignment(.center) }
            else if model.loading { ProgressView().controlSize(.small) }
            else if !model.status.isEmpty { Text(model.status).foregroundStyle(.secondary).font(.footnote).multilineTextAlignment(.center) }
        }
    }
    private func actionLabel(_ title: String) -> some View {
        Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(orange, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
    }
}
