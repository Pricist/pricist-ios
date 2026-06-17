import Foundation

/// Thread-safe, persistent event queue.
///
/// Pricist's ingest accepts one event per request, so a flush drains up to
/// `maxBatchSize` events and POSTs them sequentially. Successfully-sent events
/// are removed; a retryable failure (network/5xx/429) stops the cycle and
/// leaves the remaining events for the next flush; a permanent failure
/// (4xx/auth/encoding) drops the offending event so it can't wedge the queue.
final class EventQueue {

    private var events: [PricistEvent] = []
    private let lock = NSLock()
    private let persistenceKey = "com.pricist.events"
    private var isFlushing = false
    private let maxPersistedEvents = 1000

    init() {
        loadPersistedEvents()
    }

    /// Append an event. Returns the new queue size.
    @discardableResult
    func enqueue(_ event: PricistEvent) -> Int {
        lock.lock()
        defer { lock.unlock() }

        events.append(event)
        // Bound unbounded offline growth: drop the oldest beyond the cap.
        if events.count > maxPersistedEvents {
            events.removeFirst(events.count - maxPersistedEvents)
        }
        persistEvents()
        return events.count
    }

    /// Current queue count.
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return events.count
    }

    /// Drop every queued event from memory and storage. Used when the user
    /// revokes consent.
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        events.removeAll()
        UserDefaults.standard.removeObject(forKey: persistenceKey)
    }

    /// Flush up to `maxBatchSize` events, one request each.
    func flush(using client: NetworkClient, configuration: PricistConfiguration) {
        lock.lock()
        if isFlushing {
            lock.unlock()
            return
        }
        let batch = Array(events.prefix(configuration.maxBatchSize))
        guard !batch.isEmpty else {
            lock.unlock()
            return
        }
        isFlushing = true
        lock.unlock()

        Logger.debug("Flushing up to \(batch.count) events")
        sendNext(batch, index: 0, using: client, configuration: configuration)
    }

    // MARK: - Sequential send

    private func sendNext(
        _ batch: [PricistEvent],
        index: Int,
        using client: NetworkClient,
        configuration: PricistConfiguration
    ) {
        guard index < batch.count else {
            finishFlush()
            return
        }

        let event = batch[index]
        client.sendEvent(event, configuration: configuration) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.remove(ids: [event.eventId])
                self.sendNext(batch, index: index + 1, using: client, configuration: configuration)
            case .failure(let error) where !error.isRetryable:
                Logger.error("Dropping event \(event.eventName) — permanent failure: \(error)")
                self.remove(ids: [event.eventId])
                self.sendNext(batch, index: index + 1, using: client, configuration: configuration)
            case .failure(let error):
                Logger.warning("Flush paused — retryable failure: \(error). \(batch.count - index) event(s) kept.")
                self.finishFlush()
            }
        }
    }

    private func finishFlush() {
        lock.lock()
        isFlushing = false
        lock.unlock()
    }

    private func remove(ids: Set<String>) {
        lock.lock()
        defer { lock.unlock() }
        events.removeAll { ids.contains($0.eventId) }
        persistEvents()
    }

    // MARK: - Persistence

    private func persistEvents() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }

    private func loadPersistedEvents() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let persisted = try? JSONDecoder().decode([PricistEvent].self, from: data) else {
            return
        }
        events = persisted
        Logger.debug("Loaded \(events.count) persisted events")
    }
}
