import Foundation
import Darwin
import BrainstormCore

final class LibraryLock {
    private let descriptor: Int32
    init(root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let path = root.appendingPathComponent(".library.lock").path
        let opened = open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard opened >= 0 else { throw BrainstormError.storage("Cannot open the library lock.") }
        guard flock(opened, LOCK_EX | LOCK_NB) == 0 else {
            close(opened)
            throw BrainstormError.storage("This library is already open in another instance of Brainstorm. Close that instance before opening this one.")
        }
        descriptor = opened
    }
    deinit { flock(descriptor, LOCK_UN); close(descriptor) }
}
