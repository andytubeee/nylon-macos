import Foundation

enum NylonSocketError: Error {
    case needsAdmin // nylon's socket is root only
}

// The peers nylon reports over its IPC socket, the channel `nylon status` uses. Blocking.
// nil when no socket in `dir` answers, i.e. nylon isn't running.
func fetchPeers(in dir: String) throws -> [String: Peer]? {
    try fetchReply(in: dir).flatMap(readPeers)
}

// nylon's raw reply to a status request. The socket is named after nylon's interface, utunN on macOS, so try every
// socket in `dir`; a plain WireGuard one doesn't understand the request and is skipped.
func fetchReply(in dir: String) throws -> Data? {
    var denied = false
    for name in (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [] where name.hasSuffix(".sock") {
        do {
            if let reply = try ask("\(dir)/\(name)"), readPeers(reply) != nil { return reply }
        } catch NylonSocketError.needsAdmin {
            denied = true
        }
    }
    if denied { throw NylonSocketError.needsAdmin }
    return nil
}

// Sends nylon's status request and reads its one-line reply. nil when the socket doesn't answer within 2 s.
private func ask(_ path: String) throws -> Data? {
    guard var addr = unixAddress(path) else { return nil }
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return nil }
    defer { close(fd) }
    let connected = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
    if connected != 0 {
        if errno == EACCES { throw NylonSocketError.needsAdmin }
        return nil
    }
    var timeout = timeval(tv_sec: 2, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

    let request = Array("get=nylon\n{\"status\":{}}\n".utf8)
    guard write(fd, request, request.count) == request.count else { return nil }
    var reply = Data()
    var buffer = [UInt8](repeating: 0, count: 65536)
    while !reply.contains(UInt8(ascii: "\n")) {
        let n = read(fd, &buffer, buffer.count)
        guard n > 0 else { return nil }
        reply.append(contentsOf: buffer[..<n])
    }
    return reply
}

func unixAddress(_ path: String) -> sockaddr_un? {
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    guard path.utf8.count < MemoryLayout.size(ofValue: addr.sun_path) else { return nil }
    withUnsafeMutableBytes(of: &addr.sun_path) { buf in
        for (i, byte) in path.utf8.enumerated() { buf[i] = byte }
    }
    return addr
}
