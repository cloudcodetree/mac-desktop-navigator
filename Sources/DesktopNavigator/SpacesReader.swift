import Foundation

struct SpaceInfo {
    let id: CGSSpaceID
    let uuid: String
    let type: Int  // 0 = user desktop, 4 = fullscreen app
}

struct DisplayInfo {
    let identifier: String   // "Main" or display UUID
    let spaces: [SpaceInfo]
}

enum SpacesReader {
    static func read() -> [DisplayInfo] {
        let raw = CGSCopyManagedDisplaySpaces(CGSMainConnectionID()) as? [[String: Any]] ?? []
        return raw.compactMap { entry in
            guard let spacesRaw = entry["Spaces"] as? [[String: Any]] else { return nil }
            let id = (entry["Display Identifier"] as? String) ?? "Main"
            let spaces: [SpaceInfo] = spacesRaw.compactMap { s in
                let sid = (s["ManagedSpaceID"] as? NSNumber)?.uint64Value
                       ?? (s["id64"] as? NSNumber)?.uint64Value
                guard let sid else { return nil }
                let uuid = (s["uuid"] as? String) ?? ""
                let type = (s["type"] as? NSNumber)?.intValue ?? 0
                return SpaceInfo(id: sid, uuid: uuid, type: type)
            }
            return DisplayInfo(identifier: id, spaces: spaces)
        }
    }
}
