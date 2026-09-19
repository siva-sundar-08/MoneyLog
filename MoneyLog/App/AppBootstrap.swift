import Foundation
import Observation
import OSLog

// Handles the first few moments of the app's life: open the database, add the
// starter data if this is a fresh install, create any repeating transactions that
// fell due while the app was closed.
//
// If the database can't be opened we show a screen with a Try again button. The
// easy alternative is to crash, which tells the user nothing and loses nothing
// gracefully.
@MainActor
@Observable
final class AppBootstrap {
    enum State {
        case launching
        case ready(AppContainer)
        case failed(AppError)
    }

    private(set) var state: State = .launching
    private let logger = Logger(subsystem: "com.wedzat.moneylog", category: "Bootstrap")

    // Tests get a throwaway database held in memory, so a test run can never
    // touch — or be confused by — the real data on the device.
    private var storeLocation: PersistenceController.StoreLocation {
        let info = ProcessInfo.processInfo
        let isTesting = info.environment["XCTestConfigurationFilePath"] != nil
        return (isTesting || info.arguments.contains(LaunchArgument.inMemoryStore)) ? .inMemory : .onDisk
    }

    func start() {
        if case .ready = state { return }
        state = .launching
        do {
            let modelContainer = try PersistenceController.makeContainer(location: storeLocation)
            let container = AppContainer(modelContainer: modelContainer)
            try container.prepareForLaunch()
            state = .ready(container)
        } catch let error as AppError {
            logger.error("Launch failed: \(error.localizedDescription, privacy: .public)")
            state = .failed(error)
        } catch {
            state = .failed(.storeUnavailable(underlying: error.localizedDescription))
        }
    }

    // Runs each time the app comes back to the front: catch up on repeating rules.
    func sceneDidBecomeActive() {
        guard case .ready(let container) = state else { return }
        do {
            try container.processRecurring()
        } catch {
            logger.error("Recurring catch-up failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

enum LaunchArgument {
    static let inMemoryStore = "-MoneyLogInMemoryStore"
}
