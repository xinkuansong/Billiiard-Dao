# Audio

> 代码路径：`BilliardTrainer/Core/Audio/`
> 文档最后更新：2026-02-27

## 模块定位

Audio 模块提供音效与震动反馈管理，通过单例 AudioManager 统一管理所有音效播放与震动反馈。它不处理音频文件加载逻辑（当前使用系统音效），仅提供播放接口与设置同步。

## 入口文件

| 文件 | 职责 | 行数 |
|------|------|------|
| `AudioManager.swift` | 音效管理单例，提供音效播放、震动反馈、设置同步能力 | ~290 |

## 核心概念与术语

| 术语 | 含义 |
|------|------|
| AudioManager | 音效管理单例，管理音效播放器缓存、音量、启用状态 |
| SoundType | 音效类型枚举：cueHitSoft/Medium/Hard（击球）、ballCollisionLight/Medium/Hard（球碰撞）、cushionHit（库边）、pocketDrop（进袋）、success/fail/combo（反馈）、countdown/buttonTap（UI） |
| AVAudioSession | AVFoundation 音频会话，配置音频类别与选项 |
| SystemSoundID | AudioToolbox 系统音效 ID，当前使用系统音效作为临时方案 |
| UIImpactFeedbackGenerator | UIKit 震动反馈生成器，提供轻/中/重三种强度 |
| UINotificationFeedbackGenerator | UIKit 通知反馈生成器，提供成功/警告/错误三种类型 |

## 端到端流程

```
AudioManager.shared 初始化 → 配置 AVAudioSession → 预加载音效（当前为空） →
外部调用 playSound/playCueHit/playBallCollision 等 → 
检查 isSoundEnabled → 播放系统音效 → 
检查 isHapticEnabled → 触发震动反馈
```

## 对外能力（Public API）

- `AudioManager.shared`：单例实例
- `playSound(_:)`：播放指定类型音效
- `playCueHit(power:)`：根据力度播放击球音效（soft/medium/hard）
- `playBallCollision(impulse:)`：根据冲量播放球碰撞音效（light/medium/hard）
- `playCushionHit(impulse:)`：播放库边碰撞音效
- `playPocketDrop()`：播放进袋音效
- `playSuccess()` / `playFail()` / `playCombo()`：播放反馈音效
- `syncWithUserSettings(_:)`：从 UserProfile 同步音效/震动设置
- Extension 快捷方法：`playCollision(impulse:)`、`playCushion(impulse:)`、`playStroke(power:)`、`playPocket()`

## 依赖与边界

- **依赖**：Foundation、AVFoundation、AudioToolbox、UIKit
- **被依赖**：BilliardSceneViewModel（通过 Extension 快捷方法调用）、Settings（通过 syncWithUserSettings 同步设置）
- **禁止依赖**：不应依赖 Features 模块的具体实现

## 与其他模块的耦合点

- **Models**：通过 `syncWithUserSettings(_:)` 读取 UserProfile.soundEnabled 与 UserProfile.hapticEnabled
- **Core/Scene**：BilliardSceneViewModel 调用音效播放方法（通过 Extension 快捷方法）
- **Features/Settings**：SettingsView 修改 UserProfile.settings 后，需调用 `syncWithUserSettings` 同步

## 关键数据结构

| 结构/枚举 | 字段/Case | 单位/生命周期 |
|-----------|-----------|---------------|
| AudioManager | audioPlayers: [SoundType: AVAudioPlayer], isSoundEnabled/isHapticEnabled: Bool, volume: Float (0.0-1.0) | 单例，应用生命周期 |
| SoundType | cueHitSoft/Medium/Hard, ballCollisionLight/Medium/Hard, cushionHit, pocketDrop, success, fail, combo, countdown, buttonTap | 枚举 |
| SystemSoundID | 1104/1103/1105/1057/1025/1073/1054/1113 | AudioToolbox 系统音效 ID |

## 最近变更记录

| 日期 | 变更摘要 | 影响面 |
|------|----------|--------|
| 2026-02-27 | 创建模块文档 | 无 |
