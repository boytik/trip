
import Foundation

// MARK: - Trip Archetype

/// The kind of journey — determines the base template of items.
enum JourneyArchetype: String, Codable, CaseIterable, Identifiable {
    case urbanExplorer   = "urban_explorer"    // City
    case coastalBreeze   = "coastal_breeze"    // Sea / Beach
    case alpineAscent    = "alpine_ascent"     // Mountains / Hiking
    case frostExpedition = "frost_expedition"  // Winter / Cold

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .urbanExplorer:   return "City Explorer"
        case .coastalBreeze:   return "Coastal Breeze"
        case .alpineAscent:    return "Alpine Ascent"
        case .frostExpedition: return "Frost Expedition"
        }
    }

    var icon: String {
        switch self {
        case .urbanExplorer:   return "building.2.fill"
        case .coastalBreeze:   return "sun.and.horizon.fill"
        case .alpineAscent:    return "mountain.2.fill"
        case .frostExpedition: return "snowflake"
        }
    }

    var tagline: String {
        switch self {
        case .urbanExplorer:   return "Streets, cafes & culture"
        case .coastalBreeze:   return "Sun, sand & serenity"
        case .alpineAscent:    return "Trails, peaks & fresh air"
        case .frostExpedition: return "Snow, warmth & adventure"
        }
    }
}

// MARK: - Packing Session (the core entity)

/// A single packing session — one trip, one checklist, one mission.
struct PackingHeartbeat: Codable, Identifiable {
    let id: UUID
    var title: String
    var archetype: JourneyArchetype
    var departureEpoch: Date
    var createdEpoch: Date
    var isArchived: Bool

    /// Active conditions toggled for this session.
    var activeConditionIDs: Set<UUID>

    /// Sections within this session.
    var organs: [PackingOrgan]

    /// Notification schedule preferences.
    var reminderPlan: ReminderLifeline

    /// Cached progress (updated on every toggle).
    var vitalSigns: SessionVitalSigns

    init(
        title: String,
        archetype: JourneyArchetype,
        departureEpoch: Date,
        organs: [PackingOrgan] = [],
        activeConditionIDs: Set<UUID> = []
    ) {
        self.id = UUID()
        self.title = title
        self.archetype = archetype
        self.departureEpoch = departureEpoch
        self.createdEpoch = Date()
        self.isArchived = false
        self.activeConditionIDs = activeConditionIDs
        self.organs = organs
        self.reminderPlan = ReminderLifeline()
        self.vitalSigns = SessionVitalSigns()
    }
}

// MARK: - Section (Organ)

/// A logical grouping of items — like "organs" of the packing body.
/// Documents, Clothing, Footwear, Hygiene, First-Aid, Gadgets, Misc.
struct PackingOrgan: Codable, Identifiable {
    let id: UUID
    var designation: OrganDesignation
    var customName: String?
    var sortIndex: Int
    var isCollapsed: Bool
    var cells: [PackingCell]

    /// Per-section progress cache.
    var organVitals: OrganVitalSigns

    init(
        designation: OrganDesignation,
        sortIndex: Int,
        cells: [PackingCell] = []
    ) {
        self.id = UUID()
        self.designation = designation
        self.customName = nil
        self.sortIndex = sortIndex
        self.isCollapsed = false
        self.cells = cells
        self.organVitals = OrganVitalSigns()
    }

    var displayName: String {
        customName ?? designation.displayName
    }
}

/// Built-in section types.
enum OrganDesignation: String, Codable, CaseIterable, Identifiable {
    case documents  = "documents"
    case clothing   = "clothing"
    case footwear   = "footwear"
    case hygiene    = "hygiene"
    case firstAid   = "first_aid"
    case gadgets    = "gadgets"
    case provisions = "provisions"
    case custom     = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .documents:  return "Documents"
        case .clothing:   return "Clothing"
        case .footwear:   return "Footwear"
        case .hygiene:    return "Hygiene"
        case .firstAid:   return "First Aid"
        case .gadgets:    return "Gadgets"
        case .provisions: return "Provisions"
        case .custom:     return "Other"
        }
    }

    var icon: String {
        switch self {
        case .documents:  return "doc.text.fill"
        case .clothing:   return "tshirt.fill"
        case .footwear:   return "shoe.fill"
        case .hygiene:    return "drop.fill"
        case .firstAid:   return "cross.case.fill"
        case .gadgets:    return "bolt.fill"
        case .provisions: return "bag.fill"
        case .custom:     return "square.grid.2x2.fill"
        }
    }
}

// MARK: - Item (Cell)

/// A single item in the checklist — the smallest "cell" of the packing organism.
struct PackingCell: Codable, Identifiable {
    let id: UUID
    var name: String
    var quantity: Int
    var isPacked: Bool
    var packedEpoch: Date?
    var isCritical: Bool
    var note: String?

    /// Where this item came from.
    var origin: CellOrigin

    /// IDs of rules that added or modified this item.
    var ruleLineage: [UUID]

    /// Human-readable reason text (e.g. "Added by rule: Rain expected").
    var reasonPulse: String?

    init(
        name: String,
        quantity: Int = 1,
        isCritical: Bool = false,
        origin: CellOrigin = .userAdded,
        note: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.isPacked = false
        self.packedEpoch = nil
        self.isCritical = isCritical
        self.note = note
        self.origin = origin
        self.ruleLineage = []
        self.reasonPulse = nil
    }
}

/// How the item entered the session.
enum CellOrigin: String, Codable {
    case templateSeeded = "template"   // From base template
    case ruleInjected   = "rule"       // Added by a condition rule
    case userAdded      = "user"       // Manually added by user
}

// MARK: - Condition (Trigger)

/// A contextual toggle that activates dependency rules.
/// "Rain expected", "Trekking", "With children", etc.
struct ConditionTrigger: Codable, Identifiable {
    let id: UUID
    var name: String
    var icon: String
    var explanation: String
    var isBuiltIn: Bool

    /// How many rules reference this condition.
    var ruleCount: Int

    init(
        name: String,
        icon: String = "bolt.circle",
        explanation: String = "",
        isBuiltIn: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.explanation = explanation
        self.isBuiltIn = isBuiltIn
        self.ruleCount = 0
    }
}

// MARK: - Rule (Dependency Nerve)

/// A single "if condition → then action" rule.
struct DependencyNerve: Codable, Identifiable {
    let id: UUID
    var conditionID: UUID
    var action: NerveAction
    var targetItemName: String
    var targetOrgan: OrganDesignation
    var removalPolicy: NerveRemovalPolicy
    var priority: Int  // 1 (lowest) … 5 (highest)
    var reasonText: String

    /// Which trip archetypes this rule applies to (empty = all).
    var archetypeMask: Set<String>

    init(
        conditionID: UUID,
        action: NerveAction,
        targetItemName: String,
        targetOrgan: OrganDesignation,
        removalPolicy: NerveRemovalPolicy = .removeIfNotPacked,
        priority: Int = 3,
        reasonText: String = ""
    ) {
        self.id = UUID()
        self.conditionID = conditionID
        self.action = action
        self.targetItemName = targetItemName
        self.targetOrgan = targetOrgan
        self.removalPolicy = removalPolicy
        self.priority = min(max(priority, 1), 5)
        self.reasonText = reasonText
        self.archetypeMask = []
    }
}

/// What the rule does when triggered.
enum NerveAction: String, Codable {
    case addItem       = "add_item"
    case makeCritical  = "make_critical"
    case appendNote    = "append_note"

    var displayName: String {
        switch self {
        case .addItem:      return "Add Item"
        case .makeCritical: return "Mark Critical"
        case .appendNote:   return "Add Note"
        }
    }
}

/// What happens when the condition is turned off.
enum NerveRemovalPolicy: String, Codable {
    case removeIfNotPacked = "remove_if_not_packed"
    case alwaysKeep        = "always_keep"
    case archive           = "archive"

    var displayName: String {
        switch self {
        case .removeIfNotPacked: return "Remove if unpacked"
        case .alwaysKeep:        return "Always keep"
        case .archive:           return "Archive"
        }
    }
}

// MARK: - Vital Signs (Progress Caches)

/// Cached progress for the entire session — avoids recomputation.
struct SessionVitalSigns: Codable {
    var totalCells: Int = 0
    var packedCells: Int = 0
    var criticalRemaining: Int = 0
    var ruleAddedCount: Int = 0

    var remainingCells: Int { max(totalCells - packedCells, 0) }

    var progressFraction: Double {
        guard totalCells > 0 else { return 0 }
        return Double(packedCells) / Double(totalCells)
    }

    var progressPercent: Int {
        Int(progressFraction * 100)
    }
}

/// Cached progress for a single section.
struct OrganVitalSigns: Codable {
    var totalCells: Int = 0
    var packedCells: Int = 0
    var criticalRemaining: Int = 0

    var isComplete: Bool { totalCells > 0 && packedCells == totalCells }

    var progressFraction: Double {
        guard totalCells > 0 else { return 0 }
        return Double(packedCells) / Double(totalCells)
    }
}

// MARK: - Reminder Lifeline

/// Notification schedule for a session — 24h / 6h / 2h toggles.
struct ReminderLifeline: Codable {
    var is24HoursEnabled: Bool = true
    var is6HoursEnabled: Bool = true
    var is2HoursEnabled: Bool = true
    var quietHoursStart: Int = 23  // 11 PM
    var quietHoursEnd: Int = 7     // 7 AM
}

// MARK: - Filter Mode

/// Active filter on the items list.
enum VitalFilter: String, CaseIterable, Identifiable {
    case all           = "all"
    case unpacked      = "unpacked"
    case packed        = "packed"
    case critical      = "critical"
    case ruleInjected  = "rule_added"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:          return "All"
        case .unpacked:     return "Remaining"
        case .packed:       return "Packed"
        case .critical:     return "Critical"
        case .ruleInjected: return "Smart"
        }
    }

    var icon: String {
        switch self {
        case .all:          return "square.grid.2x2"
        case .unpacked:     return "circle.dashed"
        case .packed:       return "checkmark.circle.fill"
        case .critical:     return "exclamationmark.triangle.fill"
        case .ruleInjected: return "bolt.badge.clock.fill"
        }
    }
}

// MARK: - User Profile (Settings)

/// Lightweight user profile for gamification / personalization.
struct VitalIdentity: Codable {
    var avatarEmoji: String = "🧳"
    var displayName: String = "Traveler"
    var totalSessionsCreated: Int = 0
    var totalItemsPacked: Int = 0
    var perfectPackStreak: Int = 0   // Sessions completed at 100%
    var longestStreak: Int = 0

    /// Gamification level based on total items packed.
    var vitalLevel: Int {
        switch totalItemsPacked {
        case 0..<25:     return 1
        case 25..<100:   return 2
        case 100..<300:  return 3
        case 300..<750:  return 4
        case 750..<1500: return 5
        default:         return 6
        }
    }

    var levelTitle: String {
        switch vitalLevel {
        case 1: return "Novice Packer"
        case 2: return "Organized Scout"
        case 3: return "Seasoned Nomad"
        case 4: return "Master Voyager"
        case 5: return "Legendary Pathfinder"
        default: return "Vital Sage"
        }
    }

    var levelIcon: String {
        switch vitalLevel {
        case 1: return "leaf"
        case 2: return "star"
        case 3: return "flame"
        case 4: return "crown"
        case 5: return "bolt.shield"
        default: return "sparkles"
        }
    }
}

// MARK: - Onboarding State

/// Tracks whether the user has completed onboarding.
struct OnboardingVitals: Codable {
    var hasCompletedOnboarding: Bool = false
    var lastOnboardingStep: Int = 0
}

// MARK: - Statistics Snapshot

/// Aggregate stats for the Settings / Stats screen.
struct VitalStatistics: Codable {
    var totalTrips: Int = 0
    var totalItemsEverPacked: Int = 0
    var averagePackingPercent: Double = 0
    var mostUsedArchetype: String? = nil
    var conditionsUsedCount: Int = 0
    var perfectTrips: Int = 0  // Completed at 100%
    var criticalItemsSaved: Int = 0  // Critical items that were packed

    var formattedAveragePercent: String {
        "\(Int(averagePackingPercent))%"
    }
}

// MARK: - Share Payload

/// Lightweight model for "share my packing list" functionality.
struct VitalSharePayload {
    let sessionTitle: String
    let archetype: String
    let departureDate: String
    let sections: [(name: String, items: [String])]

    func asPlainText() -> String {
        var lines: [String] = []
        lines.append("🧳 \(sessionTitle)")
        lines.append("Type: \(archetype)")
        lines.append("Departure: \(departureDate)")
        lines.append("---")

        for section in sections {
            lines.append("\n📦 \(section.name)")
            for item in section.items {
                lines.append("  • \(item)")
            }
        }

        lines.append("\n— Packed with c13")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Undo Action Capsule

/// Payload for undoing a delete-item action.
struct DeleteItemUndoPayload: Codable {
    let sessionID: UUID
    let organID: UUID
    let cell: PackingCell
}

/// Stores the last undoable action for quick reversal.
struct UndoCapsule: Codable {
    let actionType: UndoActionType
    let timestamp: Date
    let payload: Data  // JSON-encoded snapshot (e.g. DeleteItemUndoPayload)

    enum UndoActionType: String, Codable {
        case togglePacked       = "toggle_packed"
        case bulkMarkSection    = "bulk_mark_section"
        case deleteItem         = "delete_item"
        case toggleCondition    = "toggle_condition"
        case resetSection       = "reset_section"
    }
}
