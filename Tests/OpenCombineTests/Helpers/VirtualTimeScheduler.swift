//
//  VirtualTimeScheduler.swift
//  OpenCombineTests
//
//  Created by Евгений Богомолов on 14/09/2019.
//

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
protocol CancellableTokenProtocol: Cancellable {

    init(_ scheduler: VirtualTimeScheduler)

    var isCancelled: Bool { get }
}

@available(macOS 10.15, iOS 13.0, *)
final class VirtualTimeScheduler: Scheduler {

    struct SchedulerTimeType: Strideable,
                              Comparable,
                              Hashable,
                              SchedulerTimeIntervalConvertible
    {

        struct Stride: ExpressibleByFloatLiteral,
                       Comparable,
                       SignedNumeric,
                       SchedulerTimeIntervalConvertible
        {
            var magnitude: Int64

            fileprivate init(magnitude: Int64) {
                self.magnitude = magnitude
            }

            init(integerLiteral value: Int) {
                self = .seconds(value)
            }

            init(floatLiteral value: Double) {
                self = .seconds(value)
            }

            init?<Source: BinaryInteger>(exactly source: Source) {
                guard let magnitude = Int64(exactly: source) else {
                    return nil
                }
                self.init(magnitude: magnitude)
            }

            static func < (lhs: Stride, rhs: Stride) -> Bool {
                return lhs.magnitude < rhs.magnitude
            }

            static func * (lhs: Stride, rhs: Stride) -> Stride {
                return Stride(magnitude: lhs.magnitude * rhs.magnitude)
            }

            static func + (lhs: Stride, rhs: Stride) -> Stride {
                return Stride(magnitude: lhs.magnitude + rhs.magnitude)
            }

            static func - (lhs: Stride, rhs: Stride) -> Stride {
                return Stride(magnitude: lhs.magnitude - rhs.magnitude)
            }

            static func -= (lhs: inout Stride, rhs: Stride) {
                lhs.magnitude -= rhs.magnitude
            }

            static func *= (lhs: inout Stride, rhs: Stride) {
                lhs.magnitude *= rhs.magnitude
            }

            static func += (lhs: inout Stride, rhs: Stride) {
                lhs.magnitude += rhs.magnitude
            }

            static func seconds(_ value: Int) -> Stride {
                return Stride(magnitude: Int64(value) * 1_000_000_000)
            }

            static func seconds(_ value: Double) -> Stride {
                return Stride(magnitude: Int64(value * 1_000_000_000))
            }

            static func milliseconds(_ value: Int) -> Stride {
                return Stride(magnitude: Int64(value) * 1_000_000)
            }

            static func microseconds(_ value: Int) -> Stride {
                return Stride(magnitude: Int64(value) * 1_000)
            }

            static func nanoseconds(_ value: Int) -> Stride {
                return Stride(magnitude: Int64(value))
            }
        }

        /// Time in virtual nanoseconds
        let time: UInt64

        private init(nanoseconds time: UInt64) {
            self.time = time
        }

        static func == (lhs: SchedulerTimeType, rhs: SchedulerTimeType) -> Bool {
            return lhs.time == rhs.time
        }

        static func < (lhs: SchedulerTimeType, rhs: SchedulerTimeType) -> Bool {
            return lhs.time < rhs.time
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(time)
        }

        func distance(to other: SchedulerTimeType) -> Stride {
            if self > other {
                return Stride(magnitude: -Int64(time - other.time))
            } else {
                return Stride(magnitude: Int64(other.time - time))
            }
        }

        func advanced(by stride: Stride) -> SchedulerTimeType {
            return stride.magnitude < 0
                ? SchedulerTimeType(nanoseconds: time - UInt64(-stride.magnitude))
                : SchedulerTimeType(nanoseconds: time + UInt64(stride.magnitude))
        }

        static func + (lhs: SchedulerTimeType, rhs: Stride) -> SchedulerTimeType {
            return lhs.advanced(by: rhs)
        }

        static let beginningOfTime = SchedulerTimeType(nanoseconds: 0)

        static func seconds(_ value: Int) -> SchedulerTimeType {
            precondition(value >= 0, "value must not be negative")
            return .init(nanoseconds: UInt64(value) * 1_000_000_000)
        }

        static func seconds(_ value: Double) -> SchedulerTimeType {
            precondition(value >= 0, "value must not be negative")
            return .init(nanoseconds: UInt64(value * 1_000_000_000))
        }

        static func milliseconds(_ value: Int) -> SchedulerTimeType {
            precondition(value >= 0, "value must not be negative")
            return .init(nanoseconds: UInt64(value) * 1_000_000)
        }

        static func microseconds(_ value: Int) -> SchedulerTimeType {
            precondition(value >= 0, "value must not be negative")
            return .init(nanoseconds: UInt64(value) * 1_000)
        }

        static func nanoseconds(_ value: Int) -> SchedulerTimeType {
            precondition(value >= 0, "value must not be negative")
            return .init(nanoseconds: UInt64(value))
        }
    }

    enum SchedulerOptions: Equatable, CustomStringConvertible {
        case nontrivialOptions

        var description: String {
            switch self {
            case .nontrivialOptions:
                return ".nontrivialOptions"
            }
        }
    }

    final class CancellableToken: CancellableTokenProtocol {

        weak var scheduler: VirtualTimeScheduler?

        private(set) var isCancelled = false

        init(_ scheduler: VirtualTimeScheduler) {
            self.scheduler = scheduler
        }

        deinit {
            scheduler?.cancellableTokenDeinitCount += 1
        }

        func cancel() {
            isCancelled = true
        }
    }

    final class NoopCancellableToken: CancellableTokenProtocol {

        weak var scheduler: VirtualTimeScheduler?

        init(_ scheduler: VirtualTimeScheduler) {
            self.scheduler = scheduler
        }

        deinit {
            scheduler?.cancellableTokenDeinitCount += 1
        }

        var isCancelled: Bool { return false }

        func cancel() {}
    }

    enum Event: Equatable, CustomStringConvertible {
        case now
        case minimumTolerance
        case schedule(options: SchedulerOptions?)
        case scheduleAfterDate(SchedulerTimeType,
                               tolerance: SchedulerTimeType.Stride,
                               options: SchedulerOptions?)
        case scheduleAfterDateWithInterval(SchedulerTimeType,
                                           interval: SchedulerTimeType.Stride,
                                           tolerance: SchedulerTimeType.Stride,
                                           options: SchedulerOptions?)

        var description: String {

            func describeOptions(_ options: SchedulerOptions?) -> String {
                return options.map(String.init(describing:)) ?? "nil"
            }

            func describeDate(_ date: SchedulerTimeType) -> String {
                return ".nanoseconds(\(date.time)"
            }

            func describeStride(_ stride: SchedulerTimeType.Stride) -> String {
                return ".nanoseconds(\(stride.magnitude))"
            }

            switch self {
            case .now:
                return ".now"
            case .minimumTolerance:
                return ".minimumTolerance"
            case let .schedule(options):
                return ".schedule(options: \(describeOptions(options)))"
            case let .scheduleAfterDate(date, tolerance, options):
                return """
                .scheduleAfterDate(\(describeDate(date)), \
                tolerance: \(describeStride(tolerance)), \
                options: \(describeOptions(options)))
                """
            case let .scheduleAfterDateWithInterval(date, interval, tolerance, options):
                return """
                .scheduleAfterDateWithInterval(\(describeDate(date))), \
                interval: \(describeStride(interval)), \
                tolerance: \(describeStride(tolerance)), \
                options: \(describeOptions(options)))
                """
            }
        }
    }

    private(set) var history = [Event]()

    /// All private methods should reference this property instead of `now`
    /// to prevent polluting the scheduler history. Accessing `now` creates an entry
    /// in the `history` array.
    private var _now = SchedulerTimeType.beginningOfTime

    private var workQueue = FairPriorityQueue<SchedulerTimeType, () -> Void>()

    private let cancellableTokenType: CancellableTokenProtocol.Type

    fileprivate(set) var cancellableTokenDeinitCount = 0

    init(cancellableTokenType: CancellableTokenProtocol.Type = CancellableToken.self) {
        self.cancellableTokenType = cancellableTokenType
    }

    var scheduledDates: [SchedulerTimeType] {
        return workQueue.map { $0.0 }
    }

    var now: SchedulerTimeType {
        history.append(.now)
        return _now
    }

    var minimumTolerance: SchedulerTimeType.Stride {
        history.append(.minimumTolerance)
        return .nanoseconds(7)
    }

    func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {
        history.append(.schedule(options: options))
        workQueue.insert(action, priority: _now)
    }

    func schedule(after date: SchedulerTimeType,
                  tolerance: SchedulerTimeType.Stride,
                  options: SchedulerOptions?,
                  _ action: @escaping () -> Void) {
        history.append(.scheduleAfterDate(date, tolerance: tolerance, options: options))
        workQueue.insert(action, priority: date)
    }

    func schedule(after date: SchedulerTimeType,
                  interval: SchedulerTimeType.Stride,
                  tolerance: SchedulerTimeType.Stride,
                  options: SchedulerOptions?,
                  _ action: @escaping () -> Void) -> Cancellable {
        history.append(.scheduleAfterDateWithInterval(date,
                                                      interval: interval,
                                                      tolerance: tolerance,
                                                      options: options))
        let cancellableToken = cancellableTokenType.init(self)
        repeatedlyExecute(after: date,
                          interval: interval,
                          cancellableToken: cancellableToken,
                          action: action)
        return cancellableToken
    }

    private func repeatedlyExecute(after date: SchedulerTimeType,
                                   interval: SchedulerTimeType.Stride,
                                   cancellableToken: CancellableTokenProtocol,
                                   action: @escaping () -> Void) {
        let enqueuedAction: () -> Void = { [unowned self] in
            if cancellableToken.isCancelled { return }
            action()
            self.repeatedlyExecute(after: date + interval,
                                   interval: interval,
                                   cancellableToken: cancellableToken,
                                   action: action)
        }
        workQueue.insert(enqueuedAction, priority: date)
    }

    /// Sets `now` to the provided value. Useful for testing that an entity that
    /// uses the scheduler doesn't rely on clock monotonicity.
    ///
    /// - Note: The actions that were already executed will not be executed again.
    ///   This function does **not** provide time machine-like functionality.
    func rewind(to time: SchedulerTimeType) {
        if time > _now {
            while let (nextActionTime, action) = workQueue.min(), nextActionTime <= time {
                workQueue.extractMin()
                _now = max(nextActionTime, _now)
                action()
            }
        }
        _now = time
    }

    func executeScheduledActions(until deadline: SchedulerTimeType? = nil) {
        precondition(deadline.map { $0 >= _now } ?? true)
        while let (nextActionTime, action) = workQueue.min(),
              deadline.map({ nextActionTime <= $0 }) ?? true
        {
            workQueue.extractMin()
            _now = max(nextActionTime, _now)
            action()
        }
    }
}
