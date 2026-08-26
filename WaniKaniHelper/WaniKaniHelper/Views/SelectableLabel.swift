// A UIViewRepresentable wrapper around UITextView that enables full system text selection,
// including the Translate, Look Up, and Copy actions from the iOS context menu.
// Used in place of SwiftUI Text views wherever selectable Japanese text needs to be displayed.
import SwiftUI
import UIKit

struct SelectableLabel: UIViewRepresentable {
    let text: String
    let font: UIFont
    let color: UIColor

    func makeUIView(context: Context) -> UITextView {
        let v = UITextView()
        v.isEditable = false
        v.isSelectable = true
        v.isScrollEnabled = false
        v.backgroundColor = .clear
        v.textContainerInset = .zero
        v.textContainer.lineFragmentPadding = 0
        v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return v
    }

    func updateUIView(_ v: UITextView, context: Context) {
        v.text = text
        v.font = font
        v.textColor = color
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.window?.bounds.width ?? 390
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }
}
