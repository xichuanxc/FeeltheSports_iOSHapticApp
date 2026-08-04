import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                infoCard
                Image("UniLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 188)
                    .opacity(0.75)
                    .padding(.bottom, 8)
            }
            .padding()
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image("HapticIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)

            Text("FeeltheSports")
                .font(.title2.weight(.bold))

            Text("Real-time haptic feedback for tennis match viewing")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
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
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
