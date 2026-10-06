import SwiftUI

struct InstructionsSheet: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Chat Instructions")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    store.openHelp(topic: .instructions)
                } label: {
                    Label("What are these?", systemImage: "questionmark.circle")
                }
                .buttonStyle(.borderless)
            }

            Text("Like `fm chat --instructions`: guidance the model follows for this whole chat.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ChatConversation.presets) { preset in
                        Button(preset.title) {
                            draft = preset.instructions
                        }
                        .help(preset.subtitle)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            TextEditor(text: $draft)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 180)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )

            HStack {
                Button("Reset Default") {
                    draft = ChatConversation.defaultInstructions
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    store.updateInstructions(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 560, height: 420)
        .onAppear {
            draft = store.selectedConversation?.instructions ?? ChatConversation.defaultInstructions
        }
    }
}

struct ChatOptionsSheet: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Chat Options")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    store.openHelp(topic: .options)
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.plain)
                .help("Learn about generation options")
            }
            .padding(24)
            .padding(.bottom, 0)

            Form {
                ModelCatalogSection()

                if store.showsAppleControls {
                    Section("Model use case") {
                        Picker("Use case", selection: useCaseBinding) {
                            ForEach(ModelUseCaseOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        Text(store.settings.useCase.detail)
                            .foregroundStyle(.secondary)
                    }

                    Section("Guardrails") {
                        Picker("Guardrails", selection: guardrailsBinding) {
                            ForEach(GuardrailOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        Text(store.settings.guardrails.detail)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Sampling") {
                    Toggle("Greedy sampling", isOn: greedyBinding)
                    Text("More deterministic answers — similar to `fm respond --greedy`.")
                        .foregroundStyle(.secondary)

                    Toggle("Custom temperature", isOn: customTempBinding)
                    if store.settings.useCustomTemperature {
                        Slider(value: temperatureBinding, in: 0...2, step: 0.1) {
                            Text("Temperature")
                        } minimumValueLabel: {
                            Text("0")
                        } maximumValueLabel: {
                            Text("2")
                        }
                        Text(String(format: "Temperature %.1f", store.settings.temperature))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Length") {
                    Toggle("Limit response tokens", isOn: limitTokensBinding)
                    if store.settings.limitResponseTokens {
                        Stepper(
                            "Max tokens: \(store.settings.maximumResponseTokens)",
                            value: maxTokensBinding,
                            in: 64...4096,
                            step: 64
                        )
                    }
                }

                Section("Context UI") {
                    Toggle("Show context meter", isOn: showMeterBinding)
                    Toggle("Warn near context limit", isOn: warnBinding)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 8)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
        .frame(width: 520, height: 720)
    }

    private var useCaseBinding: Binding<ModelUseCaseOption> {
        Binding(
            get: { store.settings.useCase },
            set: { value in store.updateSettings { $0.useCase = value } }
        )
    }

    private var guardrailsBinding: Binding<GuardrailOption> {
        Binding(
            get: { store.settings.guardrails },
            set: { value in store.updateSettings { $0.guardrails = value } }
        )
    }

    private var greedyBinding: Binding<Bool> {
        Binding(
            get: { store.settings.greedySampling },
            set: { value in store.updateSettings { $0.greedySampling = value } }
        )
    }

    private var customTempBinding: Binding<Bool> {
        Binding(
            get: { store.settings.useCustomTemperature },
            set: { value in store.updateSettings { $0.useCustomTemperature = value } }
        )
    }

    private var temperatureBinding: Binding<Double> {
        Binding(
            get: { store.settings.temperature },
            set: { value in store.updateSettings { $0.temperature = value } }
        )
    }

    private var limitTokensBinding: Binding<Bool> {
        Binding(
            get: { store.settings.limitResponseTokens },
            set: { value in store.updateSettings { $0.limitResponseTokens = value } }
        )
    }

    private var maxTokensBinding: Binding<Int> {
        Binding(
            get: { store.settings.maximumResponseTokens },
            set: { value in store.updateSettings { $0.maximumResponseTokens = value } }
        )
    }

    private var showMeterBinding: Binding<Bool> {
        Binding(
            get: { store.settings.showContextMeter },
            set: { value in store.updateSettings { $0.showContextMeter = value } }
        )
    }

    private var warnBinding: Binding<Bool> {
        Binding(
            get: { store.settings.warnNearContextLimit },
            set: { value in store.updateSettings { $0.warnNearContextLimit = value } }
        )
    }
}

struct RenameChatSheet: View {
    @Binding var title: String
    @Environment(\.dismiss) private var dismiss
    let onSave: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename Chat")
                .font(.title2.weight(.semibold))
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(title)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

struct HelpSheet: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationSplitView {
            List(HelpTopic.allCases, selection: $store.helpTopic) { topic in
                Label(topic.title, systemImage: topic.symbolName)
                    .tag(topic)
            }
            .listStyle(.sidebar)
            .navigationTitle("Help")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label(store.helpTopic.title, systemImage: store.helpTopic.symbolName)
                        .font(.largeTitle.weight(.semibold))

                    Text(store.helpTopic.body)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: 560, alignment: .leading)

                    if store.helpTopic == .overview {
                        GroupBox("Quick status") {
                            VStack(alignment: .leading, spacing: 8) {
                                LabeledContent("Selected", value: store.activeModelDisplayName)
                                LabeledContent("Status", value: store.availability.title)
                                LabeledContent("Fit", value: store.selectedFit.summary)
                                LabeledContent("Context window", value: "\(store.contextUsage.contextSize) tokens")
                                LabeledContent("Used", value: store.contextUsage.statusLabel)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(4)
                        }
                    }

                    if store.helpTopic == .tips {
                        GroupBox("Try these") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(PromptSuggestion.all) { suggestion in
                                    Button(suggestion.title) {
                                        store.applySuggestion(suggestion)
                                        dismiss()
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(4)
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 780, height: 520)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        TabView {
            Form {
                Section("Selected model") {
                    LabeledContent("Model", value: store.activeModelDisplayName)
                    LabeledContent("Provider", value: store.selectedModelDescriptor.providerTitle)
                    LabeledContent("Status", value: store.availability.title)
                    Text(store.availability.detail)
                        .foregroundStyle(.secondary)
                    LabeledContent("Fit", value: store.selectedFit.summary)
                    Text(store.selectedFit.detail)
                        .foregroundStyle(.secondary)
                    Button("Refresh Availability") {
                        store.refreshMachineProfile()
                    }
                }

                Section("This Mac") {
                    LabeledContent("Machine", value: store.machineProfile.machineModel)
                    LabeledContent("Chip", value: store.machineProfile.chipDescription)
                    LabeledContent("Memory", value: store.machineProfile.memoryLabel)
                    LabeledContent("Free disk", value: store.machineProfile.freeDiskLabel)
                    Text("Models cache: \(store.machineProfile.modelsDirectoryPath)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }

                Section("Context") {
                    LabeledContent("Window size", value: "\(store.contextUsage.contextSize) tokens")
                    LabeledContent("Usage", value: store.contextUsage.statusLabel)
                    Toggle("Show context meter", isOn: Binding(
                        get: { store.settings.showContextMeter },
                        set: { value in store.updateSettings { $0.showContextMeter = value } }
                    ))
                    Toggle("Warn near limit", isOn: Binding(
                        get: { store.settings.warnNearContextLimit },
                        set: { value in store.updateSettings { $0.warnNearContextLimit = value } }
                    ))
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Status", systemImage: "waveform") }

            ChatOptionsEmbedded()
                .tabItem { Label("Options", systemImage: "slider.horizontal.3") }

            Form {
                Section("About") {
                    LabeledContent("Engine", value: store.activeModelDisplayName)
                    LabeledContent("Catalog", value: "Local models + future providers")
                    LabeledContent("Privacy", value: "On-device / local-only")
                    Text("Apple Foundation Models are live today. Ollama, Hugging Face, and Unsloth are stubbed for later local plug-ins.")
                        .foregroundStyle(.secondary)
                    Button("Open Help") { store.openHelp() }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding()
    }
}

struct ModelCatalogSection: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        Section("Models") {
            Picker("Model", selection: modelBinding) {
                ForEach(LocalModelCatalog.all) { model in
                    Text(model.displayName).tag(model.id)
                }
            }
            HStack(spacing: 8) {
                Text(store.selectedModelDescriptor.providerTitle)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                FitBadge(fit: store.selectedFit)
            }
            Text(store.selectedFit.detail)
                .foregroundStyle(.secondary)
            if !store.selectedModelDescriptor.notes.isEmpty {
                Text(store.selectedModelDescriptor.notes)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { store.settings.selectedModelID },
            set: { store.selectModel(id: $0) }
        )
    }
}

struct FitBadge: View {
    let fit: FitResult

    var body: some View {
        Text(fit.verdict.badgeTitle)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(foreground)
            .background(foreground.opacity(0.12), in: Capsule())
    }

    private var foreground: Color {
        switch fit.verdict {
        case .runnable: .green
        case .tight: .orange
        case .needsRAM, .needsDisk, .unsupported: .red
        case .comingSoon: .secondary
        }
    }
}

private struct ChatOptionsEmbedded: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        Form {
            ModelCatalogSection()
            if store.showsAppleControls {
                Section("Use case") {
                    Picker("Use case", selection: Binding(
                        get: { store.settings.useCase },
                        set: { value in store.updateSettings { $0.useCase = value } }
                    )) {
                        ForEach(ModelUseCaseOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }
                Section("Guardrails") {
                    Picker("Guardrails", selection: Binding(
                        get: { store.settings.guardrails },
                        set: { value in store.updateSettings { $0.guardrails = value } }
                    )) {
                        ForEach(GuardrailOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }
            }
            Section("Sampling") {
                Toggle("Greedy sampling", isOn: Binding(
                    get: { store.settings.greedySampling },
                    set: { value in store.updateSettings { $0.greedySampling = value } }
                ))
                Toggle("Custom temperature", isOn: Binding(
                    get: { store.settings.useCustomTemperature },
                    set: { value in store.updateSettings { $0.useCustomTemperature = value } }
                ))
                if store.settings.useCustomTemperature {
                    Slider(value: Binding(
                        get: { store.settings.temperature },
                        set: { value in store.updateSettings { $0.temperature = value } }
                    ), in: 0...2, step: 0.1)
                }
            }
            Section("Length") {
                Toggle("Limit response tokens", isOn: Binding(
                    get: { store.settings.limitResponseTokens },
                    set: { value in store.updateSettings { $0.limitResponseTokens = value } }
                ))
                if store.settings.limitResponseTokens {
                    Stepper(
                        "Max tokens: \(store.settings.maximumResponseTokens)",
                        value: Binding(
                            get: { store.settings.maximumResponseTokens },
                            set: { value in store.updateSettings { $0.maximumResponseTokens = value } }
                        ),
                        in: 64...4096,
                        step: 64
                    )
                }
            }
        }
        .formStyle(.grouped)
    }
}
