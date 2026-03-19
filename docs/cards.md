# 监测卡片使用文档

监测卡片系统提供基于正则表达式的串口数据实时参数提取功能，支持数值型和布尔型两种卡片，每张卡片独立维护匹配历史。

## 架构分层

```
┌─────────────────────────────────────────────────┐
│  QML (Main.qml)                                 │
│  卡片 UI 渲染、用户交互                            │
├─────────────────────────────────────────────────┤
│  CardBridge (card_bridge.h)                     │
│  QML 单例，JSON 持久化，预设管理，类型转换           │
├─────────────────────────────────────────────────┤
│  neo::ParameterCard (core/parameter/)           │
│  纯 C++ 正则引擎 + 滚动历史，线程安全              │
└─────────────────────────────────────────────────┘
```

---

## Core 层：neo::ParameterCard

头文件：`core/parameter/parameter_card.h`

### 数据类型

#### CardType

```cpp
enum class CardType { Numeric, Boolean };
```

#### CardConfig

卡片配置，纯数据结构，可序列化。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `name` | `std::string` | - | 卡片显示名称 |
| `pattern` | `std::string` | - | 正则表达式（布尔型含映射后缀） |
| `type` | `CardType` | `Numeric` | 卡片类型 |
| `unit` | `std::string` | `""` | 单位（仅数值型有意义） |
| `color` | `std::string` | `""` | 十六进制颜色，如 `"#0e7a68"` |
| `enabled` | `bool` | `true` | 启用开关 |

#### CardValue

单次匹配结果，存储于历史记录中。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `uint64_t` | 自增 ID |
| `timestamp` | `system_clock::time_point` | 匹配时间戳 |
| `numeric` | `double` | 提取的数值（数值型卡片） |
| `boolean` | `bool` | 映射结果（布尔型卡片） |
| `matched` | `bool` | 是否成功映射到 true/false 值表 |
| `raw` | `std::string` | 捕获组的原始字符串 |

#### 回调类型

```cpp
using CardValueCallback = std::function<void(const CardValue&)>;
```

### 正则匹配规则

#### 数值型 (Numeric)

`pattern` 为标准正则表达式，优先取**捕获组 1** 的内容作为数值，无捕获组则取整条匹配结果，通过 `std::stod` 转换为 `double`。

示例：

| pattern | 输入 | 提取值 |
|---------|------|--------|
| `T1[:=]\s*([-+]?\d+(?:\.\d+)?)` | `T1=25.3` | `25.3` |
| `cockpit_setting: ([0-9]+)` | `cockpit_setting: 22` | `22.0` |
| `T21: 0x([0-9A-Fa-f]+)` | `T21: 0x1A3F` | `6719.0`（十六进制按字符串转换，注意此处为十进制解析） |

#### 布尔型 (Boolean)

`pattern` 格式为 `<正则>; true=<值1|值2>; false=<值3|值4>`，其中 `true=` / `false=` 部分可选。

匹配流程：
1. 用分号前的正则部分进行匹配，取捕获组 1
2. 将捕获内容（不区分大小写）与值映射表比对
3. 命中 `true` 表 → `boolean=true, matched=true`
4. 命中 `false` 表 → `boolean=false, matched=true`
5. 都未命中 → `matched=false`（对应 UI 上的「不匹配」警示）

**默认映射**（未指定 `true=`/`false=` 时）：

| 布尔值 | 候选值 |
|--------|--------|
| `TRUE` | `ON`、`TRUE`、`1`、`YES` |
| `FALSE` | `OFF`、`FALSE`、`0`、`NO` |

多个候选值用 `|` 或 `,` 分隔。

示例：

| pattern | 输入 | 结果 |
|---------|------|------|
| `ALARM=(ON\|OFF); true=ON; false=OFF` | `ALARM=ON` | `boolean=true, matched=true` |
| `PowerOn_flag set to:\s*([01])\b` | `PowerOn_flag set to: 1` | `boolean=true, matched=true`（使用默认映射） |
| `DCDC on (success\|fail); true=success; false=fail` | `DCDC on success` | `boolean=true, matched=true` |

### API

#### 构造 / 析构

```cpp
explicit ParameterCard(const CardConfig& config);  // 构造时编译正则
~ParameterCard();                                   // 不可拷贝
```

#### feed

```cpp
bool feed(const std::string& line);
```

喂入一行串口数据，执行正则匹配。匹配成功返回 `true`，结果自动存入历史并触发回调。未启用 (`enabled=false`) 或正则编译失败时直接返回 `false`。

#### config / updateConfig

```cpp
const CardConfig& config() const;
void updateConfig(const CardConfig& config);
```

`updateConfig` 会重新编译正则，**不清除**已有历史数据。

#### currentValue / hasValue

```cpp
CardValue currentValue() const;
bool      hasValue() const;
```

获取最近一次匹配值。未曾匹配过时 `hasValue()` 返回 `false`。

#### getHistory / clearHistory

```cpp
std::vector<CardValue> getHistory(uint64_t after_id = 0, std::size_t limit = 200) const;
void clearHistory();
```

- `getHistory`：获取 `id > after_id` 的历史记录，最多返回 `limit` 条，支持增量拉取。
- `clearHistory`：清空历史，ID 重置为 1，`hasValue()` 恢复为 `false`。
- 内部最多保留 **5000** 条记录（`kMaxHistory`），超出后自动丢弃最旧的。

#### onValueChanged

```cpp
void onValueChanged(CardValueCallback cb);
```

注册回调，每次 `feed` 匹配成功后触发。回调在调用 `feed` 的线程上**同步**执行。

### Core 层使用示例

```cpp
#include "core/parameter/parameter_card.h"
#include <iostream>

int main() {
    // 数值型卡片
    neo::CardConfig cfg;
    cfg.name    = "驾驶舱温度";
    cfg.pattern = "T21: ADC=0x[0-9A-Fa-f]+, Volt=[0-9.]+V, Temp=([-+]?[0-9]+\\.[0-9]+)°C";
    cfg.type    = neo::CardType::Numeric;
    cfg.unit    = "°C";

    neo::ParameterCard card(cfg);

    card.onValueChanged([](const neo::CardValue& v) {
        std::cout << "温度: " << v.numeric << " (raw: " << v.raw << ")" << std::endl;
    });

    card.feed("T21: ADC=0x0A3F, Volt=1.23V, Temp=25.80°C");
    // 输出: 温度: 25.8 (raw: 25.80)

    // 布尔型卡片
    neo::CardConfig boolCfg;
    boolCfg.name    = "DCDC状态";
    boolCfg.pattern = "DCDC on (success|fail); true=success; false=fail";
    boolCfg.type    = neo::CardType::Boolean;

    neo::ParameterCard boolCard(boolCfg);
    boolCard.feed("DCDC on success");

    auto val = boolCard.currentValue();
    std::cout << "DCDC: " << (val.boolean ? "OK" : "FAIL")
              << ", matched: " << val.matched << std::endl;
    // 输出: DCDC: OK, matched: 1

    // 增量拉取历史
    card.feed("T21: ADC=0x0B00, Volt=1.30V, Temp=26.50°C");
    auto history = card.getHistory(0);  // 获取全部
    std::cout << "历史记录: " << history.size() << " 条" << std::endl;

    return 0;
}
```

---

## Bridge 层：CardBridge

头文件：`gui/neo-serial-gui/card_bridge.h`

QML 单例，封装卡片集合管理、JSON 持久化和预设系统。

### QML 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `currentName` | `QString` | 当前配置名称（可读写） |
| `cardCount` | `int` | 当前卡片数量（只读） |
| `presetNames` | `QStringList` | 所有预设名称列表（只读） |

### QML 信号

| 信号 | 参数 | 说明 |
|------|------|------|
| `currentNameChanged` | - | 配置名称变更 |
| `cardsChanged` | - | 卡片列表变更（增删改、加载） |
| `presetsChanged` | - | 预设列表变更 |
| `cardValueUpdated` | `int cardId, QVariantMap value` | 某张卡片产生新匹配值 |

`cardValueUpdated` 的 `value` 结构：

| 键 | 类型 | 说明 |
|----|------|------|
| `id` | `int` | 值自增 ID |
| `numeric` | `double` | 数值 |
| `boolean` | `bool` | 布尔值 |
| `matched` | `bool` | 是否命中映射 |
| `raw` | `QString` | 原始捕获字符串 |

### 文件 I/O

```js
CardBridge.loadFromFile("path/to/monitor_cards.json")  // → bool
CardBridge.saveToFile("path/to/monitor_cards.json")    // → bool
```

JSON 格式与 `reference/monitor_cards.json` 完全一致：

```json
{
  "current": {
    "name": "配置名称",
    "cards": [
      {
        "id": 1,
        "name": "温度监测",
        "pattern": "T1[:=]\\s*([-+]?\\d+(?:\\.\\d+)?)",
        "type": "numeric",
        "enabled": true,
        "unit": "℃",
        "color": "#0e7a68",
        "created_at": "2026-03-13T10:30:00.000Z"
      }
    ]
  },
  "presets": [
    {
      "name": "预设名称",
      "cards": [ ... ],
      "saved_at": "2026-03-13T14:42:37.761Z"
    }
  ]
}
```

### 卡片 CRUD

```js
// 新建卡片，返回分配的 id
var id = CardBridge.addCard("温度", "T1[:=]\\s*([-+]?\\d+(?:\\.\\d+)?)", "numeric", "℃", "#0e7a68")

// 删除第 0 张卡片
CardBridge.removeCard(0)

// 更新卡片属性（只需传入要修改的字段）
CardBridge.updateCard(0, { "enabled": false, "color": "#ff0000" })

// 获取卡片配置
var info = CardBridge.cardAt(0)
// → { id, name, pattern, type, unit, color, enabled, created_at }
```

### 预设管理

```js
// 将当前卡片列表保存为预设（同名覆盖）
CardBridge.savePreset("冷媒传感器")

// 加载预设（替换当前所有卡片）
CardBridge.loadPreset("冷媒传感器")

// 删除预设
CardBridge.deletePreset("冷媒传感器")

// 获取所有预设名称
var names = CardBridge.presetNames  // → ["冷媒传感器", "default", ...]
```

### 数据喂入

```js
CardBridge.feed("T1=25.3")  // 对所有启用的卡片执行正则匹配
```

推荐在 C++ 侧的 `SessionBridge::pollMessages()` 中自动喂入：

```cpp
for (const auto &m : msgs) {
    // ... 现有 log 逻辑 ...
    if (m.direction == neo::Direction::Rx)
        CardBridge::create(nullptr, nullptr)->feed(
            QString::fromStdString(m.content));
}
```

### 读取卡片值

```js
// 当前值
var val = CardBridge.cardValue(0)
// → { id, numeric, boolean, matched, raw, type }

// 历史记录（增量拉取）
var history = CardBridge.cardHistory(0, lastId, 100)
// → [ { id, numeric, boolean, matched, raw }, ... ]

// 清除某张卡片的历史
CardBridge.clearCardHistory(0)
```

### QML 使用示例

```qml
import neo_serial_gui

// 启动时加载配置
Component.onCompleted: {
    CardBridge.loadFromFile("data/monitor_cards.json")
}

// 监听值更新
Connections {
    target: CardBridge
    function onCardValueUpdated(cardId, value) {
        console.log("Card", cardId, "→", value.raw)
    }
}

// 渲染卡片列表
Repeater {
    model: CardBridge.cardCount
    delegate: Rectangle {
        property var info: CardBridge.cardAt(index)
        property var val:  CardBridge.cardValue(index)
        color: info.color
        Label { text: info.name + ": " + (info.type === "numeric"
                    ? val.numeric + " " + info.unit
                    : val.boolean) }
    }
}
```

---

## 注意事项

- `ParameterCard` **不可拷贝**，使用 `std::unique_ptr` 管理。
- `onValueChanged` 回调在调用 `feed` 的线程上同步执行，保持轻量。`CardBridge` 已通过 `QueuedConnection` 将信号转发到 GUI 线程。
- `updateConfig` 会重新编译正则但**不清除**历史数据；如需重置请手动调用 `clearHistory`。
- `feed` 会遍历所有卡片，单行数据可同时被多张卡片匹配。
- 正则编译失败时 `feed` 静默返回 `false`，不会抛出异常。
- 历史上限：Core 层 5000 条/卡片。超出自动淘汰最旧记录，增量拉取不受影响。
