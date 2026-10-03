import SmartTubeIOSCore
import SwiftUI

private enum PlayerVideoInfoLayout {
    static let minimumTapHeight: CGFloat = 48
    static let cornerRadius: CGFloat = 12
}

/// The avatar, channel name, affordance and empty space are all one tap target.
struct PlayerUploaderRow: View {
    let video: Video
    var foreground: Color = .primary
    let onSelect: () -> Void

    private var canOpenChannel: Bool { video.channelId?.isEmpty == false }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: AppSymbol.personCircle)
                    .font(.title2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(video.channelTitle.isEmpty ? "Uploader" : video.channelTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if canOpenChannel {
                        Text("View channel")
                            .font(.caption)
                            .foregroundStyle(foreground.opacity(0.75))
                    }
                }
                Spacer(minLength: 8)
                if canOpenChannel {
                    Image(systemName: AppSymbol.chevronRight)
                        .font(.caption.weight(.semibold))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: PlayerVideoInfoLayout.minimumTapHeight, alignment: .leading)
            .background(foreground.opacity(0.1), in: RoundedRectangle(cornerRadius: PlayerVideoInfoLayout.cornerRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canOpenChannel)
        .accessibilityLabel(video.channelTitle.isEmpty ? "Uploader" : video.channelTitle)
        .accessibilityHint(canOpenChannel ? "Open uploader’s channel" : "Channel unavailable")
        .accessibilityIdentifier(AccessibilityID.Player.channel)
    }
}

struct PlayerPublicationInfo: View {
    let video: Video
    var foreground: Color = .secondary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Label {
                if let date = video.publicationLabel {
                    if video.isUpcoming {
                        Text("Scheduled: \(date)")
                    } else {
                        Text("Uploaded: \(date)")
                    }
                } else {
                    Text("Upload date unavailable")
                }
            } icon: {
                Image(systemName: AppSymbol.calendar)
            }
            .accessibilityIdentifier(AccessibilityID.Player.publicationDate)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let views = video.viewCount {
                Text("\(views.formatted()) views")
                    .accessibilityIdentifier(AccessibilityID.Player.viewCount)
            }
        }
        .font(.caption)
        .foregroundStyle(foreground)
    }
}
