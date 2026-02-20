import SwiftUI

/// Custom switch toggle style using MakLock Gold for consistent appearance.
/// Ignores the macOS system accent color — always renders gold when ON, gray when OFF,
/// with a clearly visible white knob.
struct GoldSwitchStyle: ToggleStyle {
    var small = false

    private var trackWidth: CGFloat { small ? 32 : 38 }
    private var trackHeight: CGFloat { small ? 18 : 22 }
    private var knobSize: CGFloat { small ? 14 : 18 }
    private var knobPadding: CGFloat { 2 }

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            Spacer()

            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? MakLockColors.gold : Color(nsColor: .separatorColor))
                    .frame(width: trackWidth, height: trackHeight)

                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                    .frame(width: knobSize, height: knobSize)
                    .padding(knobPadding)
            }
            .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
            .onTapGesture {
                configuration.isOn.toggle()
            }
        }
    }
}

extension ToggleStyle where Self == GoldSwitchStyle {
    /// MakLock Gold switch style — standard size.
    static var goldSwitch: GoldSwitchStyle { GoldSwitchStyle() }

    /// MakLock Gold switch style — compact size for popovers and tight layouts.
    static var goldSwitchSmall: GoldSwitchStyle { GoldSwitchStyle(small: true) }
}
