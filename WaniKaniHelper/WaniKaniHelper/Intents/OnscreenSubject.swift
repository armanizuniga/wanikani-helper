// Tells Siri which kanji/vocab item is on screen, so "explain this word" or "say this" resolves
// to it (on-screen awareness). This is passive metadata: nothing is sent anywhere until the user
// invokes Siri themselves. Applied to review/practice cards, lessons and the item detail sheet.
import AppIntents
import SwiftUI

extension View {
    func onscreenSubject(_ subject: CachedSubject?) -> some View {
        // Radicals aren't SubjectEntities (see SubjectEntity.swift), so there's nothing to point at.
        let id = subject.flatMap { $0.subjectType == .radical ? nil : $0.id }
        return userActivity("ArmaniZuniga.WaniKaniHelper.viewingSubject", isActive: id != nil) { activity in
            guard let id, let subject else { return }
            activity.title = subject.characters ?? subject.slug
            activity.appEntityIdentifier = EntityIdentifier(for: SubjectEntity.self, identifier: id)
        }
    }
}
