import ServiceManagement

enum LoginItemState: Equatable, Sendable {
    case enabled
    case requiresApproval
    case disabled
    case unavailable(String)
}

@MainActor
protocol LoginItemServicing {
    var state: LoginItemState { get }
    func setEnabled(_ enabled: Bool) throws
}

@MainActor
struct LoginItemService: LoginItemServicing {
    var state: LoginItemState {
        switch SMAppService.mainApp.status {
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notRegistered, .notFound:
            .disabled
        @unknown default:
            .unavailable("Unknown login item state")
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
