//
//  OnboardingInstallModelView.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/4/24.
//

import MLXLMCommon
import SwiftUI

struct OnboardingInstallModelView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(LLMEvaluator.self) var llm
    @State private var deviceSupportsMetal3: Bool = true
    @Binding var showOnboarding: Bool
    @State var selectedModel = ModelConfiguration.defaultModel
    /// When non-nil, user selected this model name (appleIntelligenceModelId or MLX name).
    @State private var selectedModelName: String?
    let suggestedModel = ModelConfiguration.defaultModel

    private static let sizeFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    func sizeBadge(_ model: ModelConfiguration?) -> String? {
        guard let size = model?.modelSize else { return nil }
        let formatted = Self.sizeFormatter.string(from: size as NSNumber) ?? "\(size)"
        return "\(formatted) GB"
    }

    let modelMemoryThreshold = 0.6

    var body: some View {
        ZStack {
            if deviceSupportsMetal3 {
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.down.circle.dotted")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 64, height: 64)
                                .foregroundStyle(.primary, .tertiary)

                            Text("Choose a Model")
                                .font(.title)
                                .fontWeight(.semibold)
                            Text("Select your first model to get started.")
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        VStack(spacing: 12) {
                            if AppleIntelligenceService.isAvailable {
                                ModelCard(
                                    title: "Apple Foundation",
                                    description: "On-device model by Apple. Same model that powers Apple Intelligence.",
                                    isSelected: selectedModelName == appleIntelligenceModelId,
                                    iconName: "apple.logo"
                                ) {
                                    selectedModelName = appleIntelligenceModelId
                                    selectedModel = ModelConfiguration.defaultModel
                                }
                            }

                            ForEach(selectableMLXModels, id: \.name) { model in
                                ModelCard(
                                    title: appManager.modelDisplayName(model.name),
                                    description: "A powerful model optimized for Apple Silicon. \(sizeBadge(model) ?? "")",
                                    isSelected: selectedModelName == model.name,
                                    iconName: "cpu"
                                ) {
                                    selectedModelName = model.name
                                    selectedModel = model
                                }
                            }
                        }
                        .padding(.horizontal)

                        Text("Please keep the app open during download.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)

                        VStack(spacing: 12) {
                            Button {
                                continueTapped()
                            } label: {
                                Text("Continue")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    #if os(iOS) || os(visionOS)
                                    .frame(height: 44)
                                    #endif
                                    #if os(iOS)
                                    .foregroundStyle(.background)
                                    #endif
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .disabled(selectedModelName == nil)

                            Button("Skip") {
                                skipTapped()
                            }
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
                .task {
                    checkModels()
                }
            } else {
                DeviceNotSupportedView()
            }
        }
        .onAppear {
            checkMetal3Support()
        }
        .background {
            NavigationLink(
                destination: OnboardingDownloadingModelProgressView(showOnboarding: $showOnboarding, selectedModel: $selectedModel)
                    .environmentObject(appManager)
                    .environment(llm),
                isActive: $showDownloadView
            ) {
                EmptyView()
            }
            .hidden()
        }
    }

    private var selectableMLXModels: [ModelConfiguration] {
        ModelConfiguration.availableModels
            .filter { !appManager.installedModels.contains($0.name) }
            .filter { model in
                guard let size = model.modelSize else { return false }
                return size <= Decimal(modelMemoryThreshold * appManager.availableMemory)
            }
            .sorted { $0.name < $1.name }
    }

    private func continueTapped() {
        guard let name = selectedModelName else { return }
        if name == appleIntelligenceModelId {
            appManager.currentModelName = appleIntelligenceModelId
            showOnboarding = false
        } else {
            appManager.playHaptic()
            showDownloadView = true
        }
    }

    @State private var showDownloadView = false

    private func skipTapped() {
        appManager.currentModelName = appManager.displayedInstalledModels.first
        showOnboarding = false
    }

    func checkModels() {
        if selectedModelName == nil, AppleIntelligenceService.isAvailable {
            selectedModelName = appleIntelligenceModelId
            return
        }
        if selectedModelName == nil, let first = selectableMLXModels.first {
            selectedModelName = first.name
            selectedModel = first
        }
    }

    func checkMetal3Support() {
        #if os(iOS)
        if let device = MTLCreateSystemDefaultDevice() {
            deviceSupportsMetal3 = device.supportsFamily(.metal3)
        }
        #endif
    }
}

private struct ModelCard: View {
    let title: String
    let description: String
    let isSelected: Bool
    let iconName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(isSelected ? 0.06 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.primary.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        #if os(macOS)
        .buttonStyle(.plain)
        #endif
    }
}

#Preview {
    OnboardingInstallModelView(showOnboarding: .constant(true))
        .environmentObject(AppManager())
        .environment(LLMEvaluator())
}
