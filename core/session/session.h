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
    bool           connected = false;
    TransportState state = TransportState::Closed;
    std::string    detail;
};

class Session {
public:
    Session();
    ~Session();

    Session(const Session&)            = delete;
    Session& operator=(const Session&) = delete;

    // ��ʼ��
    //bool Session::connect(const UartConfig& cfg);
    bool connect(std::unique_ptr<Transport> transport);
    void disconnect();
    SessionStatus status() const;

    // ���ݷ���
    bool send(const uint8_t* data, std::size_t size);
    bool send(const std::string& data);

    // ��Ϣ����
    std::vector<Message> getMessages(uint64_t after_id = 0,
                                    std::size_t limit = 200) const;
    void clearMessages();

    // �ص�ע��
    void onMessage(MessageCallback cb);
    void onStateChanged(StateCallback cb);

    // ���ߺ���
    static std::vector<PortInfo> listPorts();

private:
    void appendMessage(Direction dir,
                    const std::string& content,
                    std::chrono::system_clock::time_point ts);

    std::unique_ptr<Transport> transport_;

    mutable std::mutex status_mutex_;
    SessionStatus      status_{};

    mutable std::mutex  msg_mutex_;
    std::deque<Message> messages_;
    uint64_t            next_id_ = 1;
    static constexpr std::size_t kMaxMessages = 500;

    mutable std::mutex cb_mutex_;
    MessageCallback    user_msg_cb_;
    StateCallback      user_state_cb_;
};

} // namespace neo

#endif // NEO_CORE_SESSION_H
