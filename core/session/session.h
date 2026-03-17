#ifndef NEO_CORE_SESSION_H
#define NEO_CORE_SESSION_H

#include "../transport/transport.h"
#include "../transport/uart/uart_transport.h"

#include <chrono>
#include <cstdint>
#include <deque>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

namespace neo {

struct SessionStatus {
    bool        connected = false;
    std::string port;
    int         baudrate  = 0;
};

class Session {
public:
    Session();
    ~Session();

    Session(const Session&)            = delete;
    Session& operator=(const Session&) = delete;

    // 初始化
    bool connect(const UartConfig& cfg);
    void disconnect();
    SessionStatus status() const;

    // 数据发送
    bool send(const uint8_t* data, std::size_t size);
    bool send(const std::string& data);

    // 消息缓存
    std::vector<Message> getMessages(uint64_t after_id = 0,
                                    std::size_t limit = 200) const;
    void clearMessages();

    // 回调注册
    void onMessage(MessageCallback cb);
    void onStateChanged(StateCallback cb);

    // 工具函数
    static std::vector<PortInfo> listPorts();

private:
    void appendMessage(Direction dir,
                    const std::string& content,
                    std::chrono::system_clock::time_point ts);

    std::unique_ptr<UartTransport> transport_;
    UartConfig                     config_{};

    mutable std::mutex status_mutex_;
    SessionStatus      status_{};

    mutable std::mutex  msg_mutex_;
    std::deque<Message> messages_;
    uint64_t            next_id_ = 1;
    static constexpr std::size_t kMaxMessages = 20000;

    mutable std::mutex cb_mutex_;
    MessageCallback    user_msg_cb_;
    StateCallback      user_state_cb_;
};

} // namespace neo

#endif // NEO_CORE_SESSION_H
