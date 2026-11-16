import SwiftUI

/// 关于我们页：品牌、版本与功能简述。
public struct MetronomeAboutView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "metronome")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentColor)

                Text(MetronomeLocalization.string("Metronome"))
                    .font(.largeTitle.weight(.bold))

                Text(aboutDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("Version \(version) (\(build))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .navigationTitle("关于节拍匠")
    }

    /// 只列当前平台真实具备的能力，避免在 macOS 上声称触觉反馈。
    private var aboutDescription: String {
        #if os(iOS)
        "节拍匠是一款采样级精准的练习节拍器，支持 BPM、拍号、细分、重音、音色、音量、屏幕闪光与触觉反馈；可设置预备拍、变速训练、静音练习与演出锁定。"
        #else
        "节拍匠是一款采样级精准的练习节拍器，支持 BPM、拍号、细分、重音、音色、音量与屏幕闪光；可设置预备拍、变速训练、静音练习与演出锁定。"
        #endif
    }
}
