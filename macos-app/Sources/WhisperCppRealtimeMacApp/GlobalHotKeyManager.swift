import Carbon
import Foundation

final class GlobalHotKeyManager {
    typealias Handler = () -> Void

    nonisolated(unsafe) fileprivate static var sharedHandlers: [UInt32: Handler] = [:]
    nonisolated(unsafe) private static var isInstalled = false

    private var registeredRefs: [EventHotKeyRef?] = []

    func registerStartStopHotKey(handler: @escaping Handler) {
        installIfNeeded()
        register(
            id: 1,
            keyCode: UInt32(kVK_ANSI_C),
            modifiers: UInt32(controlKey | optionKey),
            handler: handler
        )
    }

    private func register(id: UInt32, keyCode: UInt32, modifiers: UInt32, handler: @escaping Handler) {
        Self.sharedHandlers[id] = handler

        let hotKeyID = EventHotKeyID(signature: OSType(0x41535248), id: id)
        var hotKeyRef: EventHotKeyRef?
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        registeredRefs.append(hotKeyRef)
    }

    private func installIfNeeded() {
        guard !Self.isInstalled else {
            return
        }

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            whisperCppHandleHotKeyEvent,
            1,
            &eventSpec,
            nil,
            nil
        )

        Self.isInstalled = true
    }
}

private let whisperCppHandleHotKeyEvent: EventHandlerUPP = { _, eventRef, _ in
    guard let eventRef else {
        return noErr
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        eventRef,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    if status == noErr, let handler = GlobalHotKeyManager.sharedHandlers[hotKeyID.id] {
        DispatchQueue.main.async {
            handler()
        }
    }

    return noErr
}
