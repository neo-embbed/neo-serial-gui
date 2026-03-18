# Session 使用文档

`neo::Session` 是对串口传输层的上层封装，提供连接管理、数据收发、消息记录和回调通知功能。所有公共方法均为线程安全。

头文件：`core/session/session.h`

## 数据类型

### SessionStatus

连接状态信息。

| 字段 | 类型 | 说明 |
|------|------|------|
| `connected` | `bool` | 是否已连接 |
| `state` | `TransportState` | 传输层状态（`Closed`/`Open`/`Error`） |
| `detail` | `std::string` | 状态附加信息（如错误详情） |

### UartConfig（定义于 transport 层）

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `port` | `std::string` | - | 端口名 |
| `baudrate` | `uint32_t` | `115200` | 波特率 |
| `databits` | `uint8_t` | `8` | 数据位 |
| `parity` | `Parity` | `None` | 校验位 |
| `stopbits` | `StopBits` | `One` | 停止位 |
| `read_timeout_ms` | `uint32_t` | `100` | 读超时（ms） |
| `write_timeout_ms` | `uint32_t` | `100` | 写超时（ms） |

### Message（定义于 transport 层）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `uint64_t` | 消息自增 ID |
| `timestamp` | `system_clock::time_point` | 时间戳 |
| `direction` | `Direction` | `Rx` / `Tx` / `Sys` |
| `content` | `std::string` | 消息内容 |

### 回调类型

```cpp
using MessageCallback = std::function<void(const Message& msg)>;
using StateCallback   = std::function<void(TransportState state, const std::string& detail)>;
```

## API

### 构造 / 析构

```cpp
Session();   // 默认构造，不可拷贝
~Session();  // 析构时自动调用 disconnect()
```

### connect / disconnect

```cpp
bool connect(std::unique_ptr<Transport> transport);   // 连接串口，成功返回 true
void disconnect();                      // 断开连接并释放资源
```

- `connect` 会自动断开已有连接后再重新连接。
- 析构函数会自动调用 `disconnect()`，无需手动断开。

### status

```cpp
SessionStatus status() const;
```

返回当前连接状态的快照。

### send

```cpp
bool send(const uint8_t* data, std::size_t size);
bool send(const std::string& data);
```

发送数据，发送成功后自动记录为 `Tx` 消息。未连接时返回 `false`。

### getMessages / clearMessages

```cpp
std::vector<Message> getMessages(uint64_t after_id = 0, std::size_t limit = 200) const;
void clearMessages();
```

- `getMessages`：获取 `id > after_id` 的消息，最多返回 `limit` 条。可用于增量拉取。
- `clearMessages`：清空所有消息记录，ID 重置为 1。
- 内部最多保留 20000 条消息，超出后自动丢弃最旧的。

### onMessage / onStateChanged

```cpp
void onMessage(MessageCallback cb);
void onStateChanged(StateCallback cb);
```

注册回调函数。回调在内部 I/O 线程触发，应保持轻量，**不要在回调中调用 `disconnect()`**。

### listPorts

```cpp
static std::vector<PortInfo> listPorts();
```

枚举系统可用串口，静态方法，无需实例。

## 使用示例

```cpp
#include "core/session/session.h"
#include <iostream>
#include <chrono>
#include <iomanip>

// 消息回调
void onMessage(const neo::Message& msg) {
    auto t = std::chrono::system_clock::to_time_t(msg.timestamp);
    const char* tag = (msg.direction == neo::Direction::Rx) ? "[Rx]"
                    : (msg.direction == neo::Direction::Tx) ? "[Tx]"
                    : "[Sys]";
    std::cout << std::put_time(std::localtime(&t), "%H:%M:%S")
              << tag << " " << msg.content << std::endl;
}

int main() {
    // 1. 枚举可用串口
    for (auto& p : neo::Session::listPorts()) {
        std::cout << p.device << " - " << p.description << std::endl;
    }

    // 2. 创建会话并连接
    auto session = std::make_unique<neo::Session>();

    neo::UartConfig cfg;
    cfg.port     = "COM5";
    cfg.baudrate = 115200;

    if (!session->connect(cfg)) {
        std::cerr << "连接失败" << std::endl;
        return 1;
    }

    // 3. 查询连接状态
    auto st = session->status();
    std::cout << "已连接: " << (st.connected ? "true" : "false") << std::endl;

    // 4. 注册消息回调（在 I/O 线程触发）
    session->onMessage(onMessage);

    // 5. 发送数据
    session->send("Hello Device\n");

    // 6. 保持主线程运行，等待接收
    std::cout << "按 Enter 退出..." << std::endl;
    std::cin.get();

    // 7. 增量拉取消息记录
    auto msgs = session->getMessages(0, 100);
    std::cout << "共 " << msgs.size() << " 条消息" << std::endl;

    // 8. 断开（也可以不调用，析构时自动断开）
    session->disconnect();
    return 0;
}
```

## 注意事项

- Session **不可拷贝**，使用 `std::unique_ptr` 或直接栈上构造。
- 回调在 I/O 线程触发，不要在回调中执行阻塞操作或调用 `disconnect()`。
- `connect()` 后主线程需要保持运行（如事件循环或 `std::cin.get()`），否则程序退出会立即析构并断开连接。
- `getMessages` 支持增量拉取：记录上次拉取到的最大 `id`，下次传入即可只获取新消息。
