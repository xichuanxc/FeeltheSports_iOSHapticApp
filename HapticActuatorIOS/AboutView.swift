import SwiftUI
import Darwin

struct AboutView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                infoCard
            }
            .padding()
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Header

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 16) {
            Image("HapticIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text("FeeltheSports")
                    .font(.title3.weight(.bold))
                Text("Real-time haptic feedback\nfor tennis match viewing")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: Info card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            row("Developed by",  "Chuan Xi")
            Divider().padding(.leading, 16)
            row("Supervised by", "Assoc. Prof. David Nichols")
            Divider().padding(.leading, 16)
            row("",              "Dr. Jemma König")
            Divider().padding(.leading, 16)
            row("Institution",   "University of Waikato\nTe Whare Wānanga o Waikato")
            Divider().padding(.leading, 16)
            row("School",        "School of Computing\nand Mathematical Sciences")
            Divider().padding(.leading, 16)
            row("Email",         "xichuanxc@gmail.com")
            Divider().padding(.leading, 16)
            row("Version",       versionString)
            Divider().padding(.leading, 16)
            row("Device",        "\(deviceModel)  ·  iOS \(UIDevice.current.systemVersion)")
            Divider().padding(.leading, 16)
            row("Haptics",       hapticsSummary)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if label.isEmpty {
                Spacer().frame(width: 110)
            } else {
                Text(label)
                    .foregroundStyle(.secondary)
                    .frame(width: 110, alignment: .leading)
            }
            Text(value)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Data helpers

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        guard let url   = Bundle.main.executableURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date  = attrs[.modificationDate] as? Date
        else { return version }
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return "\(version)  BUILD \(f.string(from: date))"
    }

    private var hapticsSummary: String {
        var parts: [String] = [state.capabilities.tier.label]
        if state.capabilities.supportsTransient  { parts.append("Transient") }
        if state.capabilities.supportsContinuous { parts.append("Continuous") }
        return parts.joined(separator: "  ·  ")
    }

    private var deviceModel: String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &buf, &size, nil, 0)
        let id = String(cString: buf)
        return knownModels[id] ?? id
    }

    private let knownModels: [String: String] = [
        "iPhone10,1": "iPhone 8",            "iPhone10,4": "iPhone 8",
        "iPhone10,2": "iPhone 8 Plus",       "iPhone10,5": "iPhone 8 Plus",
        "iPhone10,3": "iPhone X",            "iPhone10,6": "iPhone X",
        "iPhone11,2": "iPhone XS",           "iPhone11,4": "iPhone XS Max",
        "iPhone11,6": "iPhone XS Max",       "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11",           "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",   "iPhone12,8": "iPhone SE (2nd gen)",
        "iPhone13,1": "iPhone 12 mini",      "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",       "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",       "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",      "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3rd gen)",
        "iPhone14,7": "iPhone 14",           "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",       "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",           "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",       "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone16,3": "iPhone 16e",
        "iPhone17,1": "iPhone 16 Pro",       "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",           "iPhone17,4": "iPhone 16 Plus",
    ]
}

#Preview {
    NavigationStack {
        AboutView()
            .environment(AppState())
    }
}
