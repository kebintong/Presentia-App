import SwiftUI
import Supabase

// Column names must match supabase/migrations/0001_presentia.sql in the Presentia repo.
struct SchoolClass: Decodable, Identifiable, Hashable {
    let id: UUID
    let name: String
}

struct Student: Decodable, Identifiable {
    let id: UUID
    let name: String
    let studentNumber: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case studentNumber = "student_no"
    }
}

private struct ClassStudent: Decodable {
    let studentId: UUID

    enum CodingKeys: String, CodingKey {
        case studentId = "student_id"
    }
}

struct ClassesView: View {
    @State private var classes: [SchoolClass] = []
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List(classes) { schoolClass in
                NavigationLink(schoolClass.name) { StudentsView(schoolClass: schoolClass) }
                    .foregroundStyle(Color.ink)
                    .listRowBackground(Color.surface)
            }
            .presentiaList()
            .overlay { if let error { Text(error).foregroundStyle(Color.danger).padding() } }
            .navigationTitle("Classes")
            .toolbar {
                Button("Sign out") { Task { try? await supabase.auth.signOut() } }
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        do {
            classes = try await supabase.from("classes")
                .select("id, name")
                .eq("deleted", value: false)
                .order("name")
                .execute().value
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct StudentsView: View {
    let schoolClass: SchoolClass
    @State private var students: [Student] = []
    @State private var error: String?

    var body: some View {
        List(students) { student in
            VStack(alignment: .leading) {
                Text(student.name).foregroundStyle(Color.ink)
                Text(student.studentNumber).font(.caption.monospaced()).foregroundStyle(Color.muted)
            }
            .listRowBackground(Color.surface)
        }
        .presentiaList()
        .overlay { if let error { Text(error).foregroundStyle(Color.danger).padding() } }
        .navigationTitle(schoolClass.name)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            let links: [ClassStudent] = try await supabase.from("class_students")
                .select("student_id")
                .eq("class_id", value: schoolClass.id.uuidString)
                .eq("deleted", value: false)
                .execute().value
            // shortcut: ids go in the URL, fine for a class of a few hundred; switch to an embedded select if classes get huge.
            students = try await supabase.from("students")
                .select("id, name, student_no")
                .in("id", values: links.map(\.studentId.uuidString))
                .eq("deleted", value: false)
                .order("name")
                .execute().value
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
