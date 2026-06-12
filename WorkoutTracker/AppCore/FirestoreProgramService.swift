//
//  FirestoreProgramService.swift
//  WorkoutTracker
//
//  Single source of truth for Firestore reads/writes.
//
//  UGC writes (sharing workouts, reporting) go through anonymous Firebase Auth.
//  Uploaded workouts start in status="pending" and are moderated server-side
//  by Cloud Function `moderateSharedWorkout`. The client polls status for ~20s.
//

import Foundation
internal import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Observation
import OSLog

@Observable
@MainActor
final class FirestoreProgramService {
    static let shared = FirestoreProgramService()

    // MARK: - State for UI
    var legendaryRoutines: [LegendaryRoutine] = []
    var explorePrograms: [WorkoutProgramDefinition] = []
    var isLoading = false

    private let db = Firestore.firestore()
    private let log = Logger(subsystem: "com.borisdev.WorkoutTracker", category: "Firestore")

    private init() {}

    // MARK: - Catalog (legendary_routines + explore_programs)
    func fetchAllPrograms() async {
        isLoading = true

        do {
            // 1) Legendary routines
            let legendarySnapshot = try await db.collection("legendary_routines").getDocuments()
            var fetchedLegendary: [LegendaryRoutine] = []
            for doc in legendarySnapshot.documents {
                do {
                    let fb = try doc.data(as: FBLegendaryRoutine.self)
                    let routine = LegendaryRoutine(
                        title: fb.title ?? "Unknown Title",
                        eraTitle: fb.eraTitle ?? "Unknown Era",
                        shortVibe: fb.shortVibe ?? "",
                        loreDescription: fb.loreDescription ?? "",
                        gradientColors: (fb.hexColors ?? []).compactMap { Color(hex: $0) },
                        difficulty: ProgramLevel(rawValue: fb.difficulty ?? "") ?? .intermediate,
                        estimatedMinutes: fb.estimatedMinutes ?? 0,
                        benefits: fb.benefits ?? [],
                        exercises: (fb.exercises ?? []).map { $0.toDTO() }
                    )
                    fetchedLegendary.append(routine)
                } catch {
                    print("❌ Error decoding FBLegendaryRoutine for doc \(doc.documentID): \(error)")
                }
            }

            // 2) Explore programs
            let programsSnapshot = try await db.collection("explore_programs").getDocuments()
            var fetchedPrograms: [WorkoutProgramDefinition] = []
            for doc in programsSnapshot.documents {
                do {
                    let fb = try doc.data(as: FBWorkoutProgram.self)
                    let prog = WorkoutProgramDefinition(
                        title: fb.title ?? "Unknown Program",
                        description: fb.descriptionText ?? "",
                        level: ProgramLevel(rawValue: fb.level ?? "") ?? .intermediate,
                        goal: ProgramGoal(rawValue: fb.goal ?? "") ?? .buildMuscle,
                        equipment: ProgramEquipment(rawValue: fb.equipment ?? "") ?? .fullGym,
                        gradientColors: (fb.hexColors ?? []).compactMap { Color(hex: $0) },
                        isSingleRoutine: fb.isSingleRoutine ?? false,
                        routines: (fb.routines ?? []).map { $0.toDTO() }
                    )
                    fetchedPrograms.append(prog)
                } catch {
                    print("❌ Error decoding FBWorkoutProgram for doc \(doc.documentID): \(error)")
                }
            }

            self.legendaryRoutines = fetchedLegendary
            self.explorePrograms = fetchedPrograms
            log.info("☁️ Catalog loaded: \(fetchedLegendary.count) legendary, \(fetchedPrograms.count) explore")
        } catch {
            log.error("☁️ Catalog load failed: \(error.localizedDescription, privacy: .public)")
        }

        isLoading = false
    }

    // MARK: - UGC: Upload shared preset

    /// Uploads a shared workout preset. The doc starts as `status="pending"`
    /// and is moderated server-side. This method waits up to ~20s for moderation
    /// to finish and returns a result. If moderation does not finish in time,
    /// it returns `.pending` — the UI should tell the user it will be reviewed.
    func uploadSharedPreset(_ presetDTO: WorkoutPresetDTO) async throws -> SharedWorkoutUploadResult {
        // Guideline 1.2 (UGC) — single, mandatory enforcement point:
        // nothing may be written to `shared_workouts` without explicit
        // Community Guidelines / EULA acceptance. The UI gate is a convenience;
        // THIS is the guarantee that no code path can bypass consent.
        guard UGCConsent.hasAccepted else {
            throw SharedWorkoutError.consentRequired
        }

        // Ensure we have an anonymous user before writing.
        let user = try await AnonymousAuthBootstrap.shared.ensureSignedIn()

        // Encode the preset into a JSON dictionary.
        guard let jsonData = try? JSONEncoder().encode(presetDTO),
              var dict = (try? JSONSerialization.jsonObject(with: jsonData)) as? [String: Any] else {
            throw SharedWorkoutError.encodingFailed
        }

        // Derive moderator-visible title from the preset name.
        let rawTitle = (dict["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !rawTitle.isEmpty else { throw SharedWorkoutError.emptyTitle }
        let title = String(rawTitle.prefix(200)) 

        // Validate exercises shape (rules also validate this server-side).
        let exercises = dict["exercises"] as? [Any] ?? []
        guard !exercises.isEmpty else { throw SharedWorkoutError.emptyExercises }
        guard exercises.count <= 200 else { throw SharedWorkoutError.tooManyExercises }

        // Required server-validated fields (must match firestore.rules).
        dict["title"] = title
        dict["description"] = ""
        dict["creatorUid"] = user.uid
        dict["status"] = "pending"
        dict["reportCount"] = 0
        dict["moderationReason"] = ""
        dict["createdAt"] = FieldValue.serverTimestamp()
        dict["language"] = Locale.current.language.languageCode?.identifier ?? "en"

        let document = db.collection("shared_workouts").document()
        log.info("Uploading shared workout id=\(document.documentID, privacy: .public) by uid=\(user.uid, privacy: .private)")

        try await document.setData(dict)

        // Poll moderation status (rejected/approved within ~20s most of the time).
        let outcome = try await pollModerationStatus(documentId: document.documentID)
        log.info("Moderation outcome for \(document.documentID, privacy: .public): \(outcome.status, privacy: .public)")

        switch outcome.status {
        case "approved":
            return .approved(id: document.documentID)
        case "rejected", "blocked":
            // Soft delete on client — server may also auto-delete later.
            try? await document.delete()
            throw SharedWorkoutError.moderationRejected(reason: outcome.reason ?? "The content violates community guidelines.")
        default:
            return .pending(id: document.documentID)
        }
    }

    /// Polls a shared_workouts document for non-pending status with a timeout.
    private func pollModerationStatus(documentId: String,
                                      timeout: TimeInterval = 20,
                                      interval: TimeInterval = 1.5) async throws -> (status: String, reason: String?) {
        let start = Date()
        let docRef = db.collection("shared_workouts").document(documentId)

        while Date().timeIntervalSince(start) < timeout {
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            do {
                let snapshot = try await docRef.getDocument()
                guard let data = snapshot.data() else { continue }
                let status = (data["status"] as? String) ?? "pending"
                if status != "pending" {
                    let reason = data["moderationReason"] as? String
                    return (status: status, reason: reason)
                }
            } catch {
                // Permission errors will fire if the rejected doc gets deleted; treat as pending.
                log.debug("Poll error (ignored): \(error.localizedDescription, privacy: .public)")
            }
        }
        return (status: "pending", reason: nil)
    }

    // MARK: - UGC: Download shared preset

    /// Downloads a shared preset by ID. Throws if creator is blocked locally
    /// or if Firestore rules reject the read (e.g. status != approved).
    func downloadSharedPreset(id: String) async throws -> WorkoutPresetDTO {
        // Ensure auth (rules require request.auth for reads on UGC).
        _ = try await AnonymousAuthBootstrap.shared.ensureSignedIn()

        let snapshot = try await db.collection("shared_workouts").document(id).getDocument()
        guard let data = snapshot.data() else {
            throw SharedWorkoutError.notFound
        }

        // Local block check
        if let creatorUid = data["creatorUid"] as? String,
           await BlockedUsersStore.shared.isBlocked(uid: creatorUid) {
            throw SharedWorkoutError.blocked
        }

        // Status check (defensive — rules already enforce approved-only reads for non-owners)
        let status = (data["status"] as? String) ?? "pending"
        switch status {
        case "approved":
            break
        case "pending":
            throw SharedWorkoutError.stillModerating
        case "rejected", "blocked":
            throw SharedWorkoutError.moderationRejected(reason: data["moderationReason"] as? String ?? "")
        default:
            throw SharedWorkoutError.notFound
        }

        // Strip server-only / non-codable fields before decoding into WorkoutPresetDTO.
        var cleaned = data
        cleaned.removeValue(forKey: "creatorUid")
        cleaned.removeValue(forKey: "status")
        cleaned.removeValue(forKey: "reportCount")
        cleaned.removeValue(forKey: "moderationReason")
        cleaned.removeValue(forKey: "createdAt")    // Timestamp can't be JSON-serialized
        cleaned.removeValue(forKey: "moderatedAt")  // ditto
        cleaned.removeValue(forKey: "language")
        cleaned.removeValue(forKey: "title")
        cleaned.removeValue(forKey: "description")

        guard let jsonData = try? JSONSerialization.data(withJSONObject: cleaned),
              let fbPresetDTO = try? JSONDecoder().decode(FBWorkoutPresetDTO.self, from: jsonData) else {
            throw SharedWorkoutError.decodingFailed
        }

        return fbPresetDTO.toDTO()
    }

    /// Returns (presetDTO, creatorUid) so callers can attach the creator UID to UI
    /// for "Report this workout" / "Block this user" actions on the import screen.
    func downloadSharedPresetWithCreator(id: String) async throws -> (preset: WorkoutPresetDTO, creatorUid: String) {
        _ = try await AnonymousAuthBootstrap.shared.ensureSignedIn()

        let snapshot = try await db.collection("shared_workouts").document(id).getDocument()
        guard let data = snapshot.data(),
              let creatorUid = data["creatorUid"] as? String else {
            throw SharedWorkoutError.notFound
        }

        if await BlockedUsersStore.shared.isBlocked(uid: creatorUid) {
            throw SharedWorkoutError.blocked
        }

        let status = (data["status"] as? String) ?? "pending"
        guard status == "approved" else {
            switch status {
            case "pending":
                throw SharedWorkoutError.stillModerating
            case "rejected", "blocked":
                throw SharedWorkoutError.moderationRejected(reason: data["moderationReason"] as? String ?? "")
            default:
                throw SharedWorkoutError.notFound
            }
        }

        var cleaned = data
        ["creatorUid","status","reportCount","moderationReason","createdAt","moderatedAt","language","title","description"]
            .forEach { cleaned.removeValue(forKey: $0) }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: cleaned),
              let fbPresetDTO = try? JSONDecoder().decode(FBWorkoutPresetDTO.self, from: jsonData) else {
            throw SharedWorkoutError.decodingFailed
        }
        return (fbPresetDTO.toDTO(), creatorUid)
    }

    // MARK: - UGC: Reports

    /// Files a report against a shared workout. Triggers Cloud Function
    /// `onReportCreated`, which increments reportCount and auto-blocks at 3.
    func reportWorkout(id: String, reason: String, details: String) async throws {
        let user = try await AnonymousAuthBootstrap.shared.ensureSignedIn()

        let validReasons: Set<String> = ["spam", "hate", "harassment", "sexual", "violence", "dangerous", "other"]
        guard validReasons.contains(reason) else {
            throw SharedWorkoutError.invalidReason
        }

        let trimmedDetails = String(details.prefix(500))
        log.info("Filing report workoutId=\(id, privacy: .public) reason=\(reason, privacy: .public)")

        try await db.collection("reports").addDocument(data: [
            "workoutId": id,
            "reporterUid": user.uid,
            "reason": reason,
            "details": trimmedDetails,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp()
        ])
    }
}

// MARK: - Result + Error types

enum SharedWorkoutUploadResult {
    case approved(id: String)
    case pending(id: String)
}

enum SharedWorkoutError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case emptyTitle
    case emptyExercises
    case tooManyExercises
    case moderationRejected(reason: String)
    case stillModerating
    case blocked
    case notFound
    case invalidReason
    case consentRequired

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to prepare workout for download."
        case .decodingFailed:
            return "Unable to parse training data."
        case .emptyTitle:
            return "The workout must have a name."
        case .emptyExercises:
            return "The workout must contain at least one exercise."
        case .invalidReason:
            return "Incorrect reason for complaint."
        case .consentRequired:
            return NSLocalizedString(
                "You must accept the Community Guidelines before sharing content.",
                comment: "Shown if a share is attempted without UGC consent"
            )
        case .tooManyExercises:
            return "Too many exercises (max 200)."
        case .moderationRejected(let reason):
            return reason.isEmpty
                ? "The training was rejected by moderation."
                : "The training was rejected by moderation: \(reason)"
        case .stillModerating:
            return "This workout is still being moderated. Try opening the link in a minute."
        case .blocked:
            return "The author of this workout has been blocked."
        case .notFound:
            return "The workout was not found or is no longer available."
        }
    }
}
