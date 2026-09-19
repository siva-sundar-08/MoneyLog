import SwiftUI

// Settings: appearance, currency, a plain statement about privacy, erase-all-data,
// and the version number.
//
// The currency picker locks itself once transactions exist. Switching currency
// afterwards wouldn't convert anything — it would just relabel every past amount,
// turning ₹500 into $500 and quietly corrupting the history.
struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @AppStorage(PreferenceKey.appearance) private var appearanceRaw = AppearanceSetting.system.rawValue
    @AppStorage(PreferenceKey.currencyCode) private var currencyRaw = CurrencyCode.default.rawValue

    @State private var isConfirmingErase = false
    @State private var transactionCount = 0
    @State private var errorMessage: String?
    @State private var didErase = false

    private var appearance: Binding<AppearanceSetting> {
        Binding(
            get: { AppearanceSetting(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: appearance) {
                        ForEach(AppearanceSetting.allCases) { option in
                            Text(option.localizedName).tag(option)
                        }
                    } label: {
                        Label(String(localized: "settings.appearance", defaultValue: "Appearance"), systemImage: "circle.lefthalf.filled")
                    }

                    Picker(selection: $currencyRaw) {
                        ForEach(CurrencyCode.supported) { code in
                            Text("\(code.rawValue) · \(MoneyFormatter.currencySymbol(for: code))").tag(code.rawValue)
                        }
                    } label: {
                        Label(String(localized: "settings.currency", defaultValue: "Currency"), systemImage: "indianrupeesign.circle")
                    }
                    .disabled(transactionCount > 0)
                } header: {
                    Text(String(localized: "settings.preferences", defaultValue: "Preferences"))
                } footer: {
                    if transactionCount > 0 {
                        Text(String(localized: "settings.currencyLocked", defaultValue: "Currency is fixed once you've recorded transactions, so past amounts keep their meaning."))
                    }
                }

                Section {
                    Label(String(localized: "settings.privacyNote", defaultValue: "Everything stays on this iPhone. MoneyLog has no account, no server and no analytics."), systemImage: "lock")
                        .font(Typography.callout)
                        .foregroundStyle(Palette.inkSecondary)
                } header: {
                    Text(String(localized: "settings.privacy", defaultValue: "Privacy"))
                }

                Section {
                    LabeledContent(
                        String(localized: "settings.transactionCount", defaultValue: "Transactions"),
                        value: transactionCount, format: .number
                    )

                    Button(role: .destructive) {
                        isConfirmingErase = true
                    } label: {
                        Label(String(localized: "settings.erase", defaultValue: "Erase all data"), systemImage: "trash")
                    }
                } header: {
                    Text(String(localized: "settings.data", defaultValue: "Data"))
                } footer: {
                    Text(String(localized: "settings.eraseFooter", defaultValue: "Removes every transaction, account, budget and goal, then restores the starter categories. This can't be undone."))
                }

                if let errorMessage {
                    Section {
                        InlineErrorBanner(message: errorMessage)
                    }
                }

                Section {
                    LabeledContent(String(localized: "settings.version", defaultValue: "Version"), value: versionString)
                } header: {
                    Text(String(localized: "settings.about", defaultValue: "About"))
                }

                #if DEBUG
                Section {
                    NavigationLink(String(localized: "settings.diagnostics", defaultValue: "Store diagnostics")) {
                        FoundationStatusView()
                    }
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(CanvasBackground())
            .navigationTitle(Text("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.done", defaultValue: "Done")) { dismiss() }
                }
            }
            .confirmationDialog(
                Text("Erase all data?"),
                isPresented: $isConfirmingErase,
                titleVisibility: .visible
            ) {
                Button(String(localized: "settings.eraseConfirmAction", defaultValue: "Erase everything"), role: .destructive, action: erase)
                Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "settings.eraseConfirmMessage", defaultValue: "All transactions, accounts, budgets and goals will be deleted from this iPhone."))
            }
            .task { refreshCount() }
        }
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func refreshCount() {
        do {
            transactionCount = try container.transactionCount()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func erase() {
        do {
            try container.eraseAllData()
            Haptics.play(.deleted)
            router.dataDidChange()
            refreshCount()
            errorMessage = nil
            didErase = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
