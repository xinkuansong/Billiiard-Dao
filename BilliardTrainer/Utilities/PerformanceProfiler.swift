//
//  PerformanceProfiler.swift
//  BilliardTrainer
//
//  轻量级性能插桩工具——仅在 DEBUG 构建下生效，Release 下零开销。
//
//  使用方式：
//    PerformanceProfiler.begin("simulate")
//    engine.simulate(...)
//    PerformanceProfiler.end("simulate")
//
//    // 单次函数计时快捷方式
//    let result = PerformanceProfiler.measure("findNextEvent") { findNextEvent() }
//
//    // 读取报告
//    PerformanceProfiler.printReport()
//    PerformanceProfiler.reset()
//

import Foundation
import QuartzCore

// MARK: - PerformanceProfiler

final class PerformanceProfiler {

    // MARK: - Types

    struct SectionStats {
        let label: String
        var callCount: Int = 0
        var totalMs: Double = 0
        var minMs: Double = .infinity
        var maxMs: Double = 0
        var lastMs: Double = 0

        var avgMs: Double { callCount > 0 ? totalMs / Double(callCount) : 0 }

        mutating func record(_ ms: Double) {
            callCount += 1
            totalMs += ms
            lastMs = ms
            if ms < minMs { minMs = ms }
            if ms > maxMs { maxMs = ms }
        }
    }

    // MARK: - Singleton

    static let shared = PerformanceProfiler()
    private init() {}

    // MARK: - State

    private var pendingStarts: [String: CFTimeInterval] = [:]
    private var stats: [String: SectionStats] = [:]
    private let lock = NSLock()

    // MARK: - Public API

    /// 开始计时
    static func begin(_ label: String) {
#if DEBUG
        shared.lock.lock()
        shared.pendingStarts[label] = CACurrentMediaTime()
        shared.lock.unlock()
#endif
    }

    /// 结束计时并记录
    @discardableResult
    static func end(_ label: String) -> Double {
#if DEBUG
        let endTime = CACurrentMediaTime()
        shared.lock.lock()
        defer { shared.lock.unlock() }
        guard let startTime = shared.pendingStarts.removeValue(forKey: label) else { return 0 }
        let ms = (endTime - startTime) * 1000.0
        if shared.stats[label] == nil {
            shared.stats[label] = SectionStats(label: label)
        }
        shared.stats[label]!.record(ms)
        return ms
#else
        return 0
#endif
    }

    /// 对一个返回值的闭包进行计时
    @discardableResult
    static func measure<T>(_ label: String, block: () -> T) -> T {
#if DEBUG
        begin(label)
        let result = block()
        end(label)
        return result
#else
        return block()
#endif
    }

    /// 对一个无返回值的闭包进行计时
    static func measure(_ label: String, block: () -> Void) {
#if DEBUG
        begin(label)
        block()
        end(label)
#else
        block()
#endif
    }

    // MARK: - Reporting

    /// 打印所有已收集区段的统计报告
    static func printReport(tag: String = "PerformanceProfiler") {
#if DEBUG
        shared.lock.lock()
        let snapshot = shared.stats
        shared.lock.unlock()

        guard !snapshot.isEmpty else {
            print("[\(tag)] 暂无统计数据")
            return
        }

        let sorted = snapshot.values.sorted { $0.label < $1.label }
        let header = String(
            format: "  %-40@ %6@ %9@ %9@ %9@ %9@",
            "区段" as NSString,
            "次数" as NSString,
            "总计ms" as NSString,
            "均值ms" as NSString,
            "最小ms" as NSString,
            "最大ms" as NSString
        )
        print("[\(tag)] ========== 性能报告 ==========")
        print(header)
        print("  " + String(repeating: "-", count: 88))
        for s in sorted {
            let minStr: String = s.minMs == .infinity ? "  —" : String(format: "%.2f", s.minMs)
            let row = String(
                format: "  %-40@ %6d %9.2f %9.2f %9@ %9.2f",
                s.label as NSString,
                s.callCount,
                s.totalMs,
                s.avgMs,
                minStr as NSString,
                s.maxMs
            )
            print(row)
        }
        print("[\(tag)] ================================")
#endif
    }

    /// 获取某区段最近一次耗时（ms），供实时 HUD 展示
    static func lastMs(for label: String) -> Double {
#if DEBUG
        shared.lock.lock()
        defer { shared.lock.unlock() }
        return shared.stats[label]?.lastMs ?? 0
#else
        return 0
#endif
    }

    /// 获取某区段调用次数
    static func callCount(for label: String) -> Int {
#if DEBUG
        shared.lock.lock()
        defer { shared.lock.unlock() }
        return shared.stats[label]?.callCount ?? 0
#else
        return 0
#endif
    }

    /// 重置所有统计数据
    static func reset() {
#if DEBUG
        shared.lock.lock()
        shared.stats.removeAll()
        shared.pendingStarts.removeAll()
        shared.lock.unlock()
        print("[PerformanceProfiler] 统计数据已重置")
#endif
    }
}

// MARK: - ProfilerLabels

/// 统一管理所有插桩标签，避免字符串拼写错误
enum ProfilerLabel {
    // 物理模拟
    static let simulate         = "Physics.simulate"
    static let findNextEvent    = "Physics.findNextEvent"
    static let ballBallDetect   = "Physics.ballBall.detect"
    static let cushionDetect    = "Physics.cushion.detect"
    static let evolveAllBalls   = "Physics.evolveAllBalls"
    static let resolveEvent     = "Physics.resolveEvent"

    // 渲染 / 回放
    static let renderUpdate     = "Render.renderUpdate"
    static let playbackFrame    = "Render.playbackFrame"
    static let stateAt          = "Render.stateAt"
    static let aimLineUpdate    = "Render.aimLineUpdate"
    static let trajectoryPreview = "Render.trajectoryPreview"
    static let cueStickUpdate   = "Render.cueStickUpdate"

    // 击球流程
    static let executeStroke    = "Shot.executeStroke"
    static let buildEngine      = "Shot.buildEngine"
    static let applyResult      = "Shot.applyResult"
}
