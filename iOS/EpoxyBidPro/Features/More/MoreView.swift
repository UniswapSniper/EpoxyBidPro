import SwiftUI

struct MoreView: View {
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.english.rawValue

    private var selectedLanguage: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: appLanguageRawValue) ?? .english },
            set: { appLanguageRawValue = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("section.language") {
                    Picker("setting.appLanguage", selection: selectedLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayNameKey)
                                .tag(language)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("setting.languageDescription")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("section.about") {
                    Text("Settings, reports, invoicing")
                }
            }
            .navigationTitle("More")
        }
    }
}
