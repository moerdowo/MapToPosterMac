import SwiftUI

struct ContentView: View {
    @StateObject private var vm = PosterViewModel()

    var body: some View {
        HSplitView {
            settingsPanel
                .frame(minWidth: 320, idealWidth: 360, maxWidth: 460)
            previewPanel
                .frame(minWidth: 420)
        }
        .frame(minWidth: 880, minHeight: 640)
    }

    // MARK: - Settings panel

    private var settingsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                group("Location") {
                    labeledField("City", text: $vm.settings.city)
                    labeledField("Country", text: $vm.settings.country)

                    Toggle("Use manual coordinates", isOn: $vm.settings.useManualCenter)
                        .toggleStyle(.switch)
                    if vm.settings.useManualCenter {
                        HStack {
                            numberField("Latitude", value: $vm.settings.latitude, format: "%.4f")
                            numberField("Longitude", value: $vm.settings.longitude, format: "%.4f")
                        }
                    }
                }

                group("Map Radius") {
                    HStack {
                        Text("Distance")
                        Spacer()
                        Text("\(Int(vm.settings.distance)) m").foregroundStyle(.secondary)
                    }
                    Slider(value: $vm.settings.distance, in: 4000...20000, step: 500)
                    Text("Larger = more area, more detail to download.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                group("Theme") {
                    Picker("Theme", selection: $vm.settings.themeID) {
                        ForEach(Theme.all) { theme in
                            Text(theme.name).tag(theme.id)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: vm.settings.themeID) { _ in vm.rerenderStyleOnly() }
                    Text(vm.settings.theme.description)
                        .font(.caption).foregroundStyle(.secondary)
                    themeSwatches(vm.settings.theme)
                }

                group("Size & Resolution") {
                    stepperRow("Width", value: $vm.settings.widthInches, range: 4...20, unit: "in")
                    stepperRow("Height", value: $vm.settings.heightInches, range: 4...20, unit: "in")
                    HStack {
                        Text("Resolution")
                        Spacer()
                        Text("\(Int(vm.settings.dpi)) DPI").foregroundStyle(.secondary)
                    }
                    Slider(value: $vm.settings.dpi, in: 72...300, step: 1)
                        .onChange(of: vm.settings.dpi) { _ in }
                }

                group("Typography") {
                    labeledField("Display city (optional)", text: $vm.settings.displayCity,
                                 placeholder: vm.settings.city)
                    labeledField("Display country (optional)", text: $vm.settings.displayCountry,
                                 placeholder: vm.settings.country)
                    Picker("Font", selection: $vm.settings.fontFamily) {
                        ForEach(fontFamilies, id: \.self) { fam in
                            Text(fam).tag(fam)
                        }
                    }
                    .onChange(of: vm.settings.fontFamily) { _ in vm.rerenderStyleOnly() }
                }

                group("Layers") {
                    Toggle("Water", isOn: $vm.settings.showWater)
                        .onChange(of: vm.settings.showWater) { _ in vm.rerenderStyleOnly() }
                    Toggle("Parks & green space", isOn: $vm.settings.showParks)
                        .onChange(of: vm.settings.showParks) { _ in vm.rerenderStyleOnly() }
                    Toggle("Buildings (downloads more data)", isOn: $vm.settings.showBuildings)
                }
            }
            .padding(18)
        }
    }

    // MARK: - Preview panel

    private var previewPanel: some View {
        VStack(spacing: 0) {
            ZStack {
                Color(nsColor: .underPageBackgroundColor)
                if let poster = vm.poster {
                    Image(nsImage: poster)
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                        .shadow(radius: 8)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "map")
                            .font(.system(size: 56))
                            .foregroundStyle(.tertiary)
                        Text("Type a city and press Generate")
                            .foregroundStyle(.secondary)
                    }
                }
                if vm.isWorking {
                    Color.black.opacity(0.25)
                    ProgressView().controlSize(.large)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack(spacing: 12) {
                if let error = vm.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .lineLimit(2)
                } else {
                    Text(vm.statusMessage).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Export PNG…") { vm.export() }
                    .disabled(vm.poster == nil || vm.isWorking)
                Button {
                    vm.generate()
                } label: {
                    Label("Generate", systemImage: "wand.and.stars")
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.borderedProminent)
                .disabled(vm.isWorking || vm.settings.city.isEmpty)
            }
            .padding(12)
        }
    }

    // MARK: - Small helpers

    private func group<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func numberField(_ label: String, value: Binding<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, value: value, formatter: NumberFormatter.decimal)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func stepperRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(Int(value.wrappedValue)) \(unit)").foregroundStyle(.secondary)
            Stepper("", value: value, in: range, step: 1)
                .labelsHidden()
                .onChange(of: value.wrappedValue) { _ in }
        }
    }

    private func themeSwatches(_ theme: Theme) -> some View {
        HStack(spacing: 4) {
            ForEach([theme.bg, theme.roadMotorway, theme.roadPrimary, theme.roadSecondary,
                     theme.roadTertiary, theme.water, theme.text], id: \.self) { hex in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(nsColor: NSColor(hex: hex)))
                    .frame(height: 18)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(.black.opacity(0.1)))
            }
        }
    }

    private var fontFamilies: [String] {
        var fams = Set(NSFontManager.shared.availableFontFamilies)
        fams.insert(vm.settings.fontFamily)
        // Surface a few sensible defaults first.
        let preferred = ["Helvetica Neue", "Avenir Next", "Futura", "Gill Sans",
                         "Georgia", "Times New Roman", "Menlo"]
        let rest = fams.subtracting(preferred).sorted()
        return preferred.filter { fams.contains($0) } + rest
    }
}

private extension NumberFormatter {
    static let decimal: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 6
        return f
    }()
}
