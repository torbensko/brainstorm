import Foundation

public actor LibraryStore {
    private let db: SQLiteConnection
    public init(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        db = try SQLiteConnection(url: url)
        let version = try db.execute("PRAGMA user_version").first?.int("user_version") ?? 0
        guard version <= 3 else { throw BrainstormError.storage("This library needs a newer version of Brainstorm.") }
        if version == 0 {
            try db.transaction {
                for statement in Self.schema { try db.execute(statement) }
                try db.execute("PRAGMA user_version = 1")
            }
        }
        if version < 2 {
            try db.transaction {
                try db.execute("ALTER TABLE projects ADD COLUMN title_mode TEXT NOT NULL DEFAULT 'custom' CHECK(title_mode IN ('automatic','custom'))")
                for row in try db.execute("SELECT id,title,prompt FROM projects") {
                    let id = try row.id("id")
                    let first = try db.execute("SELECT prompt FROM batches WHERE project_id=? ORDER BY created_at,rowid LIMIT 1", [.id(id)]).first
                    let expected = PromptBuilder.title(from: try first?.string("prompt") ?? row.string("prompt"))
                    let title = try row.string("title")
                    // Legacy autosave could freeze a title at the first character. Preserve other renamed titles.
                    if title == "Untitled concept" || title == expected ||
                        (title.count == 1 && expected.lowercased().hasPrefix(title.lowercased())) {
                        try db.execute("UPDATE projects SET title=?,title_mode='automatic' WHERE id=?", [.text(expected), .id(id)])
                    }
                }
                try db.execute("PRAGMA user_version = 2")
            }
        }
        if version < 3 {
            try db.transaction {
                try db.execute("ALTER TABLE projects ADD COLUMN suggested_title TEXT")
                try db.execute("UPDATE projects SET title='New conversation' WHERE title_mode='automatic' AND title='Untitled concept' AND trim(prompt)='' AND NOT EXISTS (SELECT 1 FROM batches WHERE project_id=projects.id)")
                try db.execute("PRAGMA user_version = 3")
            }
        }
    }

    public func snapshot() throws -> LibrarySnapshot {
        let projects = try db.execute("SELECT * FROM projects ORDER BY updated_at DESC, created_at DESC").map(project)
        let batches = try db.execute("SELECT * FROM batches ORDER BY created_at, rowid").map(batch)
        let assets = try db.execute("SELECT * FROM assets ORDER BY created_at").map(asset)
        return LibrarySnapshot(projects: projects, batches: batches, assets: assets)
    }

    /// Keep one unused draft. Any history, image, reference, or intentional name makes it nonempty.
    public func consolidateEmptyDrafts(preferredID: UUID? = nil) throws -> Project? {
        try db.transaction {
            let drafts = try db.execute("""
                SELECT * FROM projects WHERE title_mode='automatic' AND suggested_title IS NULL
                AND parent_asset_id IS NULL
                AND NOT EXISTS (SELECT 1 FROM batches WHERE project_id=projects.id)
                AND NOT EXISTS (SELECT 1 FROM assets WHERE project_id=projects.id)
                AND NOT EXISTS (SELECT 1 FROM project_references WHERE project_id=projects.id)
                ORDER BY updated_at DESC, created_at DESC
                """).map(project).filter { $0.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            guard let retained = drafts.first(where: { $0.id == preferredID }) ?? drafts.first else { return nil }
            for draft in drafts where draft.id != retained.id {
                try db.execute("DELETE FROM projects WHERE id=?", [.id(draft.id)])
            }
            return retained
        }
    }

    public func saveProject(_ value: Project) throws {
        try db.transaction {
            try db.execute("""
                INSERT INTO projects(id,title,title_mode,prompt,parent_asset_id,created_at,updated_at) VALUES(?,?,?,?,?,?,?)
                ON CONFLICT(id) DO UPDATE SET title=excluded.title,title_mode=excluded.title_mode,prompt=excluded.prompt,
                parent_asset_id=excluded.parent_asset_id,updated_at=excluded.updated_at
                """, [.id(value.id), .text(value.title), .text(value.titleMode.rawValue), .text(value.prompt), .optionalID(value.parentAssetID),
                        .number(value.createdAt.timeIntervalSince1970), .number(value.updatedAt.timeIntervalSince1970)])
            try validateAssets(value.referenceIDs + [value.parentAssetID].compactMap { $0 }, projectID: value.id)
            try db.execute("DELETE FROM project_references WHERE project_id=?", [.id(value.id)])
            for (position, id) in value.referenceIDs.enumerated() {
                try db.execute("INSERT INTO project_references VALUES(?,?,?)", [.id(value.id), .id(id), .number(Double(position))])
            }
        }
    }

    public func addAsset(_ value: Asset) throws {
        try addAssetRow(value)
    }

    /// Separate from draft saves so an in-flight autosave cannot replace a generated name.
    public func suggestTitle(_ title: String, for projectID: UUID) throws {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 80, !title.contains(where: \.isNewline) else {
            throw BrainstormError.invalid("The service returned an invalid conversation name.")
        }
        try db.execute("UPDATE projects SET suggested_title=? WHERE id=? AND title_mode='automatic' AND suggested_title IS NULL",
                       [.text(title), .id(projectID)])
    }

    public func addBatch(_ value: GenerationBatch) throws {
        try value.settings.validate()
        guard (1...16).contains(value.jobs.count), Set(value.jobs.map(\.id)).count == value.jobs.count,
              value.jobs.allSatisfy({ $0.batchID == value.id && $0.status == .queued }) else {
            throw BrainstormError.invalid("A generation set needs 1–16 distinct queued images.")
        }
        guard value.referenceIDs.count <= value.settings.provider.maximumReferences,
              Set(value.referenceIDs).count == value.referenceIDs.count else {
            throw BrainstormError.invalid("Too many or duplicate reference images.")
        }
        if let parent = value.parentAssetID, value.referenceIDs.first != parent {
            throw BrainstormError.invalid("The selected image must be the first reference.")
        }
        try db.transaction {
            try validateAssets(value.referenceIDs, projectID: value.projectID)
            try db.execute("INSERT INTO batches VALUES(?,?,?,?,?,?,?,?,?,?,?)", [
                .id(value.id), .id(value.projectID), .text(value.prompt), .text(value.resolvedPrompt), .optionalID(value.parentAssetID),
                .text(value.settings.provider.rawValue), .text(value.settings.model), .text(value.settings.shape.rawValue),
                .text(value.settings.quality.rawValue), .number(value.createdAt.timeIntervalSince1970), .number(Double(value.jobs.count))
            ])
            for (position, id) in value.referenceIDs.enumerated() {
                try db.execute("INSERT INTO batch_references VALUES(?,?,?)", [.id(value.id), .id(id), .number(Double(position))])
            }
            for job in value.jobs {
                try db.execute("INSERT INTO jobs(id,batch_id,position,status,attempts) VALUES(?,?,?,?,0)", [
                    .id(job.id), .id(value.id), .number(Double(job.position)), .text(job.status.rawValue)
                ])
            }
            try db.execute("UPDATE projects SET updated_at=? WHERE id=?", [.number(Date.now.timeIntervalSince1970), .id(value.projectID)])
        }
    }

    public func nextQueued(excluding ids: Set<UUID>) throws -> (GenerationBatch, GenerationJob)? {
        for row in try db.execute("SELECT jobs.* FROM jobs JOIN batches ON batches.id=jobs.batch_id WHERE status='queued' ORDER BY batches.created_at,jobs.position") {
            let candidate = try job(row)
            if !ids.contains(candidate.id), let batch = try batch(id: candidate.batchID) { return (batch, candidate) }
        }
        return nil
    }

    public func batch(id: UUID) throws -> GenerationBatch? {
        try db.execute("SELECT * FROM batches WHERE id=?", [.id(id)]).first.map(batch)
    }

    public func assets(ids: [UUID]) throws -> [Asset] {
        try ids.map { id in
            guard let row = try db.execute("SELECT * FROM assets WHERE id=?", [.id(id)]).first else {
                throw BrainstormError.storage("A reference image is missing from the library.")
            }
            return try asset(row)
        }
    }

    @discardableResult
    public func startJob(_ id: UUID) throws -> Bool {
        !((try db.execute("UPDATE jobs SET status='running',error=NULL,attempts=attempts+1 WHERE id=? AND status='queued' RETURNING id", [.id(id)])).isEmpty)
    }

    public func recordRetry(_ id: UUID) throws {
        try db.execute("UPDATE jobs SET attempts=attempts+1 WHERE id=? AND status='running'", [.id(id)])
    }

    public func finishJob(_ id: UUID, asset value: Asset, result: ImageOutput) throws -> Bool {
        try db.transaction {
            guard let row = try db.execute("SELECT status FROM jobs WHERE id=?", [.id(id)]).first,
                  try row.string("status") == JobStatus.running.rawValue else { return false }
            try addAssetRow(value)
            try db.execute("UPDATE jobs SET status='succeeded',asset_id=?,error=NULL,request_id=?,input_tokens=?,output_tokens=? WHERE id=?", [
                .id(value.id), .optionalText(result.requestID), .optionalInt(result.inputTokens), .optionalInt(result.outputTokens), .id(id)
            ])
            return true
        }
    }

    public func failJob(_ id: UUID, message: String) throws {
        try db.execute("UPDATE jobs SET status='failed',error=? WHERE id=? AND status='running'", [.text(message), .id(id)])
    }

    public func cancelJob(_ id: UUID) throws {
        try db.execute("UPDATE jobs SET status='cancelled',error=NULL WHERE id=? AND status IN ('queued','running')", [.id(id)])
    }

    public func retryJob(_ id: UUID) throws {
        try db.execute("UPDATE jobs SET status='queued',error=NULL WHERE id=? AND status IN ('failed','cancelled','interrupted')", [.id(id)])
    }

    public func recoverInterrupted() throws {
        try db.execute("UPDATE jobs SET status='interrupted',error='The app closed before this request finished. Retry when ready.' WHERE status IN ('queued','running')")
    }

    public func deleteProject(_ id: UUID) throws {
        try db.execute("DELETE FROM projects WHERE id=?", [.id(id)])
    }

    private func addAssetRow(_ value: Asset) throws {
        try db.execute("INSERT INTO assets VALUES(?,?,?,?,?,?,?,?,?)", [
            .id(value.id), .id(value.projectID), .text(value.name), .text(value.filename), .text(value.thumbnailFilename),
            .text(value.mimeType), .number(Double(value.width)), .number(Double(value.height)), .number(value.createdAt.timeIntervalSince1970)
        ])
    }
    private func validateAssets(_ ids: [UUID], projectID: UUID) throws {
        for id in ids {
            guard let row = try db.execute("SELECT project_id FROM assets WHERE id=?", [.id(id)]).first,
                  try row.id("project_id") == projectID else {
                throw BrainstormError.invalid("Reference images must belong to this concept.")
            }
        }
    }
    private func project(_ row: SQLRow) throws -> Project {
        let id = try row.id("id")
        guard let titleMode = ProjectTitleMode(rawValue: try row.string("title_mode")) else { throw BrainstormError.storage("Unknown conversation title mode.") }
        let references = try db.execute("SELECT asset_id FROM project_references WHERE project_id=? ORDER BY position", [.id(id)]).map { try $0.id("asset_id") }
        return try Project(id: id, title: row.string("title"), titleMode: titleMode, prompt: row.string("prompt"), parentAssetID: row.optionalID("parent_asset_id"),
                           referenceIDs: references, createdAt: row.date("created_at"), updatedAt: row.date("updated_at"),
                           suggestedTitle: row.optionalString("suggested_title"))
    }
    private func asset(_ row: SQLRow) throws -> Asset {
        try Asset(id: row.id("id"), projectID: row.id("project_id"), name: row.string("name"), filename: row.string("filename"),
                  thumbnailFilename: row.string("thumbnail"), mimeType: row.string("mime_type"), width: row.int("width"),
                  height: row.int("height"), createdAt: row.date("created_at"))
    }
    private func job(_ row: SQLRow) throws -> GenerationJob {
        guard let status = JobStatus(rawValue: try row.string("status")) else { throw BrainstormError.storage("Unknown generation status.") }
        return try GenerationJob(id: row.id("id"), batchID: row.id("batch_id"), position: row.int("position"), status: status,
                                 assetID: row.optionalID("asset_id"), error: row.optionalString("error"), attempts: row.int("attempts"),
                                 requestID: row.optionalString("request_id"), inputTokens: row.optionalInt("input_tokens"), outputTokens: row.optionalInt("output_tokens"))
    }
    private func batch(_ row: SQLRow) throws -> GenerationBatch {
        let id = try row.id("id")
        guard let provider = ProviderID(rawValue: try row.string("provider")),
              let shape = ImageShape(rawValue: try row.string("shape")),
              let quality = ImageQuality(rawValue: try row.string("quality")) else { throw BrainstormError.storage("Unknown generation settings.") }
        let references = try db.execute("SELECT asset_id FROM batch_references WHERE batch_id=? ORDER BY position", [.id(id)]).map { try $0.id("asset_id") }
        let jobs = try db.execute("SELECT * FROM jobs WHERE batch_id=? ORDER BY position", [.id(id)]).map(job)
        return try GenerationBatch(id: id, projectID: row.id("project_id"), prompt: row.string("prompt"), resolvedPrompt: row.string("resolved_prompt"),
                                   parentAssetID: row.optionalID("parent_asset_id"), referenceIDs: references,
                                   settings: GenerationSettings(provider: provider, model: row.string("model"), shape: shape, quality: quality),
                                   createdAt: row.date("created_at"), jobs: jobs)
    }

    private static let schema = [
        """
        CREATE TABLE projects(id TEXT PRIMARY KEY,title TEXT NOT NULL,prompt TEXT NOT NULL,
        parent_asset_id TEXT REFERENCES assets(id) ON DELETE SET NULL,created_at REAL NOT NULL,updated_at REAL NOT NULL)
        """,
        """
        CREATE TABLE assets(id TEXT PRIMARY KEY,project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        name TEXT NOT NULL,filename TEXT NOT NULL,thumbnail TEXT NOT NULL,mime_type TEXT NOT NULL,
        width INTEGER NOT NULL,height INTEGER NOT NULL,created_at REAL NOT NULL)
        """,
        """
        CREATE TABLE batches(id TEXT PRIMARY KEY,project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        prompt TEXT NOT NULL,resolved_prompt TEXT NOT NULL,parent_asset_id TEXT REFERENCES assets(id),
        provider TEXT NOT NULL,model TEXT NOT NULL,shape TEXT NOT NULL,quality TEXT NOT NULL,created_at REAL NOT NULL,count INTEGER NOT NULL)
        """,
        """
        CREATE TABLE jobs(id TEXT PRIMARY KEY,batch_id TEXT NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,status TEXT NOT NULL,asset_id TEXT REFERENCES assets(id),error TEXT,attempts INTEGER NOT NULL,
        request_id TEXT,input_tokens INTEGER,output_tokens INTEGER,UNIQUE(batch_id,position))
        """,
        """
        CREATE TABLE project_references(project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        asset_id TEXT NOT NULL REFERENCES assets(id),position INTEGER NOT NULL,PRIMARY KEY(project_id,asset_id))
        """,
        """
        CREATE TABLE batch_references(batch_id TEXT NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
        asset_id TEXT NOT NULL REFERENCES assets(id),position INTEGER NOT NULL,PRIMARY KEY(batch_id,asset_id))
        """,
        "CREATE INDEX jobs_status ON jobs(status)",
        "CREATE INDEX batches_project ON batches(project_id)",
        "CREATE INDEX assets_project ON assets(project_id)"
    ]
}
