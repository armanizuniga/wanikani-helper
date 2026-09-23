// A UIViewRepresentable wrapper around UITextView that enables full system text selection,
// including the Translate, Look Up, and Copy actions from the iOS context menu.
// Used in place of SwiftUI Text views wherever selectable Japanese text needs to be displayed.
// Optionally highlights characters (unknown kanji in example sentences) as tappable links.
import SwiftUI
import UIKit

struct SelectableLabel: UIViewRepresentable {
    let text: String
    let font: UIFont
    let color: UIColor
    /// Characters drawn as gold, underlined, tappable links. Tapping one calls `onTapHighlight`.
    var highlighted: [Character] = []
    var onTapHighlight: ((Character) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UITextView {
        let v = UITextView()
        v.isEditable = false
        v.isSelectable = true
        v.isScrollEnabled = false
        v.backgroundColor = .clear
        v.textContainerInset = .zero
        v.textContainer.lineFragmentPadding = 0
        v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        v.delegate = context.coordinator
        v.linkTextAttributes = [
            .foregroundColor: UIColor(named: "WKGold") ?? .systemOrange,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
        return v
    }

    func updateUIView(_ v: UITextView, context: Context) {
        context.coordinator.highlighted = highlighted
        context.coordinator.onTap = onTapHighlight

        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: color]
        )
        // The link value is the character's index in `highlighted`, so the coordinator can map a
        // tap back without percent-encoding kanji into a URL.
        for index in text.indices {
            guard let slot = highlighted.firstIndex(of: text[index]),
                  let url = URL(string: "wkkanji://\(slot)") else { continue }
            attributed.addAttribute(.link, value: url, range: NSRange(index...index, in: text))
        }
        v.attributedText = attributed
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.window?.bounds.width ?? 390
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var highlighted: [Character] = []
        var onTap: ((Character) -> Void)?

        func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
            guard case .link(let url) = textItem.content, url.scheme == "wkkanji",
                  let slot = url.host.flatMap(Int.init), highlighted.indices.contains(slot),
                  let onTap else { return defaultAction }
            let kanji = highlighted[slot]
            return UIAction { _ in onTap(kanji) }
        }

        // No link preview/menu on long-press for our in-app links; plain text selection still works.
        func textView(_ textView: UITextView, menuConfigurationFor textItem: UITextItem, defaultMenu: UIMenu) -> UITextItem.MenuConfiguration? {
            if case .link(let url) = textItem.content, url.scheme == "wkkanji" { return nil }
            return .init(menu: defaultMenu)
        }
    }
}
