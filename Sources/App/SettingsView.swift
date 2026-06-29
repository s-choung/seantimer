import SwiftUI

/// Gear-button popover: finish-sound on/off, volume, and a Test button.
/// Both settings persist via UserDefaults (see TimerModel).
struct SettingsView: View {
    @Bindable var model: TimerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Toggle(isOn: $model.darkMode) {
                Label("다크 모드", systemImage: model.darkMode ? "moon.fill" : "moon")
                    .font(Theme.labelFont)
            }
            .toggleStyle(.switch)
            .tint(Theme.red)

            Toggle(isOn: $model.soundEnabled) {
                Label("Finish sound", systemImage: "bell")
                    .font(Theme.labelFont)
            }
            .toggleStyle(.switch)
            .tint(Theme.red)

            VStack(alignment: .leading, spacing: 8) {
                Text("Volume")
                    .font(Theme.labelFont)
                    .foregroundStyle(model.soundEnabled ? Theme.ink : Theme.inkSoft)
                HStack(spacing: 10) {
                    Image(systemName: "speaker.fill")
                        .foregroundStyle(Theme.inkSoft)
                    Slider(value: $model.volume, in: 0 ... 1)
                        .tint(Theme.red)
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(Theme.inkSoft)
                }
                Button(action: model.playFinishSound) {
                    Label("Test", systemImage: "play.fill")
                        .font(Theme.labelFont)
                }
                .buttonStyle(.bordered)
                .tint(Theme.red)
            }
            .disabled(!model.soundEnabled)
            .opacity(model.soundEnabled ? 1 : 0.5)
        }
        .padding(20)
        .frame(width: 250)
    }
}
