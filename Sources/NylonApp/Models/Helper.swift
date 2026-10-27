import Foundation
import Security
import ServiceManagement

// nylon's IPC socket is root only, so a launch daemon registered with SMAppService reads it for the app.
// The daemon is this same binary run with `--xpc-helper` (see Packaging/com.encodeous.nylon-macos.helper.plist).
let helperFlag = "--xpc-helper"
let helperService = "com.encodeous.nylon-macos.helper" // its launchd label and Mach service
let helperDaemon = SMAppService.daemon(plistName: "\(helperService).plist")

@objc protocol NylonHelper {
    func status(reply: @escaping (Data?) -> Void) // nylon's raw status reply; nil when nylon doesn't answer
}

// The helper's main, started by launchd as root. Exits if it can't tell who's calling.
func runHelper() -> Never {
    guard let requirement = sameBinaryRequirement() else { exit(1) }
    let listener = NSXPCListener(machServiceName: helperService)
    listener.setConnectionCodeSigningRequirement(requirement) // only the app, which is this same binary, may connect
    let exported = HelperService(nylonDir: "/var/run/wireguard")
    listener.delegate = exported
    listener.resume()
    dispatchMain()
}

// Serves status and nothing else, so a caller can't reach nylon's other IPC commands through it.
final class HelperService: NSObject, NSXPCListenerDelegate, NylonHelper {
    let nylonDir: String
    init(nylonDir: String) { self.nylonDir = nylonDir }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: NylonHelper.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func status(reply: @escaping (Data?) -> Void) {
        reply(try? fetchReply(in: nylonDir))
    }
}

// A code signing requirement only this exact binary meets: its code directory hash. It doesn't depend on who signed
// the app (a Developer ID, a self-signed certificate or an ad hoc signature).
func sameBinaryRequirement() -> String? {
    var code: SecCode?
    var staticCode: SecStaticCode?
    var info: CFDictionary?
    guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
          SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
          SecCodeCopySigningInformation(staticCode, [], &info) == errSecSuccess,
          let hash = (info as? [String: Any])?[kSecCodeInfoUnique as String] as? Data else { return nil }
    return "cdhash H\"" + hash.map { String(format: "%02x", $0) }.joined() + "\""
}

// The app's side: asks the helper for nylon's status. Blocking. Throws when the helper can't be reached, so that
// doesn't read as nylon being down.
func helperStatus(_ connection: NSXPCConnection) throws -> Data? {
    var reply: Data?
    var failure: Error?
    // a synchronous proxy runs the reply before the call returns, or the error handler instead
    (connection.synchronousRemoteObjectProxyWithErrorHandler { failure = $0 } as? NylonHelper)?.status { reply = $0 }
    if let failure { throw failure }
    return reply
}
