import Foundation
import Security
import Testing
@testable import NylonApp

// Serves `reply` (or hangs up, when nil) to each connection on a Unix socket at `path`, like nylon's IPC socket.
// Returns the listening socket for stop(_:).
private func serve(_ path: String, reply: String?) -> Int32 {
    let fd = listenUnix(path)
    Thread.detachNewThread {
        while true {
            let conn = accept(fd, nil, nil)
            guard conn >= 0 else { return }
            if let reply {
                var request = [UInt8](repeating: 0, count: 64)
                var got = 0 // read both request lines before answering
                while got < 23 { let n = read(conn, &request, 64); if n <= 0 { break }; got += n }
                let bytes = Array((reply + "\n").utf8)
                _ = write(conn, bytes, bytes.count)
            }
            close(conn)
        }
    }
    return fd
}

private func listenUnix(_ path: String) -> Int32 {
    var addr = unixAddress(path)!
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    _ = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
    listen(fd, 8)
    return fd
}

// Ends a serve(_:reply:) server: shutdown wakes its blocked accept(), which then fails and the thread returns.
private func stop(_ fd: Int32) {
    shutdown(fd, SHUT_RDWR)
    close(fd)
}

// a short folder: a Unix socket path must fit in 104 bytes
private func socketDir() throws -> String {
    signal(SIGPIPE, SIG_IGN) // as the app does at launch
    let dir = "/tmp/nylon-test-\(UUID().uuidString.prefix(8))"
    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    return dir
}

@Test func findsNylonAmongSockets() throws {
    let dir = try socketDir()
    defer { try? FileManager.default.removeItem(atPath: dir) }
    let other = serve("\(dir)/utun3.sock", reply: nil) // another WireGuard: hangs up on get=nylon
    let nylon = serve("\(dir)/utun7.sock", reply: statusReply.replacingOccurrences(of: "\n", with: ""))
    defer { stop(other); stop(nylon) }
    #expect(try fetchPeers(in: dir)?["bob"] == Peer(metric: 12034, handshake: 1790376629))
}

@Test func notRunningWithoutSockets() throws {
    let dir = try socketDir()
    defer { try? FileManager.default.removeItem(atPath: dir) }
    #expect(try fetchPeers(in: dir) == nil)
    #expect(try fetchPeers(in: "\(dir)/missing") == nil)
}

@Test(.enabled(if: getuid() != 0)) func needsAdminForRootOnlySocket() throws {
    let dir = try socketDir()
    defer { try? FileManager.default.removeItem(atPath: dir) }
    let nylon = serve("\(dir)/utun7.sock", reply: statusReply.replacingOccurrences(of: "\n", with: ""))
    defer { stop(nylon) }
    chmod("\(dir)/utun7.sock", 0) // like nylon's socket to anyone but root
    #expect(throws: NylonSocketError.needsAdmin) { try fetchPeers(in: dir) }
}

// The helper over a real XPC connection: it passes on nylon's status reply
@Test func helperPassesOnStatus() throws {
    let dir = try socketDir()
    defer { try? FileManager.default.removeItem(atPath: dir) }
    let nylon = serve("\(dir)/utun7.sock", reply: statusReply.replacingOccurrences(of: "\n", with: ""))
    defer { stop(nylon) }
    let listener = NSXPCListener.anonymous()
    let service = HelperService(nylonDir: dir)
    listener.delegate = service
    listener.resume()
    let connection = NSXPCConnection(listenerEndpoint: listener.endpoint)
    connection.remoteObjectInterface = NSXPCInterface(with: NylonHelper.self)
    connection.resume()
    defer { connection.invalidate(); listener.invalidate() }
    #expect(try helperStatus(connection).flatMap(readPeers)?["bob"] == Peer(metric: 12034, handshake: 1790376629))
}

// The helper only lets in this same binary; the requirement must parse, and this binary must meet it
@Test func helperRequirementMatchesThisBinary() throws {
    let text = try #require(sameBinaryRequirement())
    var requirement: SecRequirement?
    #expect(SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess)
    var me: SecCode?
    SecCodeCopySelf([], &me)
    #expect(SecCodeCheckValidity(try #require(me), [], requirement) == errSecSuccess)
}

// A helper that can't be reached throws, so the app offers access again instead of saying nylon is down
@Test func unreachableHelperThrows() {
    let connection = NSXPCConnection(machServiceName: "com.encodeous.nylon-macos.no-such-helper")
    connection.remoteObjectInterface = NSXPCInterface(with: NylonHelper.self)
    connection.resume()
    defer { connection.invalidate() }
    #expect(throws: (any Error).self) { try helperStatus(connection) }
}
