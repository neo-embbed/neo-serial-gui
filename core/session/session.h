#include "../transport/transport.h"     
#include "../transport/uart/uart_transport.h"
#include <string>
#include <mutex>

namespace neo {

struct SessionStatus {
    bool connected = false;
    std::string port;
    int baudrate = 0;
};

class Session {
public:
    Session() = default;
    ~Session() = default;
    //Session(const SessionUart&)            = delete;
    //Session& operator=(const SessionUart&) = delete;

    //连接管理
    SessionStatus status() const {
        std::lock_guard<std::mutex> lk(mutex_);
        return status_;
    }
    bool connect(const UartConfig& cfg);
    void disconnect();

    //数据发送
    bool send(const uint8_t* data, std::size_t size);
    bool send(const std::string& data);

};//*class Session
} //*namespace neo
