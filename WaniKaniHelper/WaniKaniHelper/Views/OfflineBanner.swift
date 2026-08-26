// This view is a dismissable banner shown at the top of HomeView when a network request fails.
// Displays an offline warning message with a wifi-slash icon and an X button to dismiss it.
import SwiftUI

struct OfflineBanner: View {
    let message: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 13, weight: .semibold))
            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.orange)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
    }
}
