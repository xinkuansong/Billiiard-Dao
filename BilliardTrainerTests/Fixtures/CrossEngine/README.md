# Cross-Engine Fixtures

该目录用于 Swift 物理引擎与 pooltool 的输入/输出对比。

## 文件约定

- `case-*.input.json`: 测试输入（统一场景定义）
- `case-*.swift-output.json`: Swift 引擎输出（可由测试或脚本生成）
- `case-*.pooltool-output.json`: pooltool 输出（由 Python 导出脚本生成）
- `case-*.diff.json`: 对比结果（可选产物）

## 输入格式（case-*.input.json）

```json
{
  "metadata": {
    "id": "s1-center-straight",
    "description": "Center straight shot"
  },
  "simulation": {
    "maxEvents": 1200,
    "maxTime": 10.0
  },
  "balls": [
    {
      "id": "cueBall",
      "position": [0.0, 0.828575, 0.4],
      "velocity": [0.0, 0.0, -3.0],
      "angularVelocity": [0.0, 0.0, 0.0],
      "state": "sliding"
    }
  ]
}
```

`state` 支持值：

- `stationary`
- `spinning`
- `sliding`
- `rolling`
- `pocketed`

