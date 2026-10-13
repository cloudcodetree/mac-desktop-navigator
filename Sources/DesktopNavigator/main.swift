import AppKit

let app = NSApplication.shared
SingleInstance.terminateOlderInstances()
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
