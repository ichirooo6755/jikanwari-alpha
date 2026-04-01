import Foundation
import SwiftUI
import SwiftData

// MARK: - App Mode

enum AppMode: String, CaseIterable {
    case registration = "registration"
    case reference = "reference"

    var displayName: String {
        switch self {
        case .registration: return "履修登録"
        case .reference:    return "参照"
        }
    }

    var icon: String {
        switch self {
        case .registration: return "pencil.circle.fill"
        case .reference:    return "eye.circle.fill"
        }
    }
}

// MARK: - Conflict Info

struct ConflictInfo: Identifiable {
    let id = UUID()
    let day: Int
    let period: Int
    let courses: [Course]
}

// MARK: - Reference Panel Content

enum ReferencePanelContent {
    case none
    case pdf(URL)
    case web(URL)
    case image(UIImage)
}

// MARK: - TimetableViewModel

@Observable
final class TimetableViewModel {

    var mode: AppMode = .registration
    var selectedSemester: Semester?
    var selectedCourses: Set<UUID> = []
    var isReferencePanelVisible: Bool = false
    var referencePanelContent: ReferencePanelContent = .none
    var showConflictAlert: Bool = false
    var conflicts: [ConflictInfo] = []
    var showFinalizeConfirm: Bool = false
    var searchText: String = ""

    // MARK: - Computed

    var isRegistrationMode: Bool { mode == .registration }

    var filteredCandidates: [Course] {
        guard let semester = selectedSemester else { return [] }
        let unplaced = semester.courses.filter { course in
            course.slots.isEmpty
        }
        if searchText.isEmpty { return unplaced.sorted { $0.priority < $1.priority } }
        return unplaced.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.instructor.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.priority < $1.priority }
    }

    var allCourses: [Course] {
        selectedSemester?.courses ?? []
    }

    // MARK: - Slot Queries

    func courses(day: Int, period: Int) -> [Course] {
        guard let semester = selectedSemester else { return [] }
        return semester.courses
            .filter { course in
                course.slots.contains { $0.day == day && $0.period == period }
            }
            .sorted { a, b in
                let slotA = a.slots.first { $0.day == day && $0.period == period }
                let slotB = b.slots.first { $0.day == day && $0.period == period }
                return (slotA?.priorityInSlot ?? 0) < (slotB?.priorityInSlot ?? 0)
            }
    }

    func isLocked(course: Course, day: Int, period: Int) -> Bool {
        return course.isLocked
    }

    // MARK: - Course Assignment

    func assignCourse(_ course: Course, day: Int, period: Int, context: ModelContext) {
        // すでにそのコマにいたら何もしない
        if course.slots.contains(where: { $0.day == day && $0.period == period }) { return }

        let existing = courses(day: day, period: period)
        let priority = existing.count

        let slot = TimeSlot(day: day, period: period, priorityInSlot: priority)
        context.insert(slot)
        course.slots.append(slot)

        try? context.save()
    }

    func removeCourse(_ course: Course, day: Int, period: Int, context: ModelContext) {
        guard !course.isLocked else { return }
        guard let slot = course.slots.first(where: { $0.day == day && $0.period == period }) else { return }
        course.slots.removeAll { $0.id == slot.id }
        context.delete(slot)
        try? context.save()
    }

    func moveCourse(_ course: Course, fromDay: Int, fromPeriod: Int,
                    toDay: Int, toPeriod: Int, context: ModelContext) {
        guard !course.isLocked else { return }
        removeCourse(course, day: fromDay, period: fromPeriod, context: context)
        assignCourse(course, day: toDay, period: toPeriod, context: context)
    }

    func toggleLock(course: Course, context: ModelContext) {
        course.isLocked.toggle()
        try? context.save()
    }

    func setPriority(_ priority: Int, for course: Course, day: Int, period: Int, context: ModelContext) {
        guard let slot = course.slots.first(where: { $0.day == day && $0.period == period }) else { return }
        slot.priorityInSlot = priority
        try? context.save()
    }

    // MARK: - Batch Color

    func setBatchColor(_ hex: String, context: ModelContext) {
        let targets = allCourses.filter { selectedCourses.contains($0.id) }
        for course in targets { course.colorHex = hex }
        try? context.save()
        selectedCourses.removeAll()
    }

    func toggleCourseSelection(_ courseId: UUID) {
        if selectedCourses.contains(courseId) {
            selectedCourses.remove(courseId)
        } else {
            selectedCourses.insert(courseId)
        }
    }

    // MARK: - Finalize & Conflict Check

    func checkConflicts() -> [ConflictInfo] {
        var result: [ConflictInfo] = []
        for day in 0..<6 {
            for period in 1...5 {
                let coursesInSlot = courses(day: day, period: period)
                if coursesInSlot.count > 1 {
                    result.append(ConflictInfo(day: day, period: period, courses: coursesInSlot))
                }
            }
        }
        return result
    }

    func finalizeRegistration(context: ModelContext) {
        let detected = checkConflicts()
        if detected.isEmpty {
            // 競合なし → そのまま確定
            showFinalizeConfirm = true
        } else {
            conflicts = detected
            showConflictAlert = true
        }
    }

    // MARK: - Semester Management

    func addSemester(name: String, context: ModelContext) -> Semester {
        let semester = Semester(name: name)
        context.insert(semester)
        try? context.save()
        selectedSemester = semester
        return semester
    }

    func deleteSemester(_ semester: Semester, context: ModelContext) {
        context.delete(semester)
        try? context.save()
    }

    // MARK: - Auto Semester Detection

    /// 現在の日付から学期名を返す（1〜5月: 春学期、6〜12月: 秋学期）
    static func currentSemesterName() -> String {
        let now = Date()
        let year = Calendar.current.component(.year, from: now)
        let month = Calendar.current.component(.month, from: now)
        let term = month <= 5 ? "春学期" : "秋学期"
        return "\(year)年 \(term)"
    }

    /// 起動時に現在学期を自動選択（なければ作成して選択）
    func autoSelectCurrentSemester(allSemesters: [Semester], context: ModelContext) {
        guard selectedSemester == nil else { return }
        let name = Self.currentSemesterName()
        if let existing = allSemesters.first(where: { $0.name == name }) {
            selectedSemester = existing
        } else {
            let new = Semester(name: name)
            new.isActive = true
            context.insert(new)
            try? context.save()
            selectedSemester = new
        }
    }

    // MARK: - Course CRUD

    func addCourse(name: String, subtitle: String, credits: Int, instructor: String,
                   colorHex: String, context: ModelContext) -> Course? {
        guard let semester = selectedSemester else { return nil }
        let course = Course(
            name: name, subtitle: subtitle, credits: credits,
            instructor: instructor, colorHex: colorHex,
            priority: semester.courses.count
        )
        context.insert(course)
        semester.courses.append(course)
        try? context.save()
        return course
    }

    func deleteCourse(_ course: Course, context: ModelContext) {
        if let semester = selectedSemester {
            semester.courses.removeAll { $0.id == course.id }
        }
        context.delete(course)
        try? context.save()
    }

    // MARK: - Reference Panel

    func openReferencePanel(content: ReferencePanelContent) {
        referencePanelContent = content
        isReferencePanelVisible = true
    }

    func closeReferencePanel() {
        isReferencePanelVisible = false
        referencePanelContent = .none
    }
}
