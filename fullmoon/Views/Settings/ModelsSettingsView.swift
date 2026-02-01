//
//  ModelsSettingsView.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/5/24.
//

import SwiftUI
import MLXLMCommon

struct ModelsSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(LLMEvaluator.self) var llm
    @State var showOnboardingInstallModelView = false

    var body: some View {
        Form {
            Section(header: Text("installed")) {
                ForEach(appManager.displayedInstalledModels, id: \.self) { modelName in
                    Button {
                        Task {
                            await switchModel(modelName)
                        }
                    } label: {
                        Label {
                            Text(appManager.modelDisplayName(modelName))
                                .tint(.primary)
                        } icon: {
                            Image(systemName: appManager.currentModelName == modelName ? "checkmark.circle.fill" : "circle")
                        }
                    }
                    #if os(macOS)
                    .buttonStyle(.borderless)
                    #endif
                }
            }

            Button {
                showOnboardingInstallModelView = true
            } label: {
                Label("Install a model", systemImage: "arrow.down.circle.dotted")
            }
            #if os(macOS)
            .buttonStyle(.borderless)
            #endif

            Section {} footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("On-device AI models may produce inaccurate or incomplete responses. Please verify critical information and double-check responses.")
                        .font(.footnote)
                    Text("Models are provided by huggingface.co.")
                        .font(.footnote)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Models")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showOnboardingInstallModelView) {
            NavigationStack {
                OnboardingInstallModelView(showOnboarding: $showOnboardingInstallModelView)
                    .environment(llm)
                    .toolbar {
                        #if os(iOS) || os(visionOS)
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: { showOnboardingInstallModelView = false }) {
                                Image(systemName: "xmark")
                            }
                        }
                        #elseif os(macOS)
                        ToolbarItem(placement: .destructiveAction) {
                            Button(action: { showOnboardingInstallModelView = false }) {
                                Text("Close")
                            }
                        }
                        #endif
                    }
            }
        }
    }

    private func switchModel(_ modelName: String) async {
        appManager.currentModelName = modelName
        appManager.playHaptic()
        await llm.switchModel(modelName: modelName)
    }
}

#Preview {
    ModelsSettingsView()
        .environmentObject(AppManager())
        .environment(LLMEvaluator())
}
