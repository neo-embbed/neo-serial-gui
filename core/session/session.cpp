#include "session.h"

namespace neo {

Session::Session() = default;

Session::~Session() {
    disconnect();
}
//LEGACY: 参数类型是cfg，在构造函数内部创建UartTransport实例，更新的版本直接传实例
/*
bool Session::connect(const UartConfig& cfg) {
    if (transport_) {
        disconnect();
    }
    
    config_ = cfg;
    {
        std::lock_guard<std::mutex> lk(status_mutex_);
        status_.port      = cfg.port;
        status_.baudrate  = static_cast<int>(cfg.baudrate);
        status_.connected = false;
    }

    transport_ = std::make_unique<UartTransport>(cfg);

    transport_->onMessage([this](const Message& msg) {
        appendMessage(msg.direction, msg.content, msg.timestamp);
    });

    transport_->onStateChanged([this](TransportState s, const std::string& detail) {
        {
            std::lock_guard<std::mutex> lk(status_mutex_);
            status_.connected = (s == TransportState::Open);
        }

        StateCallback cb;
        {
            std::lock_guard<std::mutex> lk(cb_mutex_);
            cb = user_state_cb_;
        }
        if (cb) cb(s, detail);
    });

    bool ok = transport_->open();
    if (!ok) {
        std::lock_guard<std::mutex> lk(status_mutex_);
        status_.connected = false;
    }
    return ok;
}
    */

bool Session::connect(std::unique_ptr<Transport> transport) {
    if (transport_) {
        disconnect();
    }
    
    transport_ = std::move(transport);
    if (!transport_) return false;

    transport_->onMessage([this](const Message& msg) {
        appendMessage(msg.direction, msg.content, msg.timestamp);
    });

    transport_->onStateChanged([this](TransportState s, const std::string& detail) {
        {
            std::lock_guard<std::mutex> lk(status_mutex_);
            status_.connected = (s == TransportState::Open);
        }

        StateCallback cb;
        {
            std::lock_guard<std::mutex> lk(cb_mutex_);
            cb = user_state_cb_;
        }
        if (cb) cb(s, detail);
    });

    bool ok = transport_->open();
    if (!ok) {
        std::lock_guard<std::mutex> lk(status_mutex_);
        status_.connected = false;
    }
    return ok;
}

void Session::disconnect() {
    if (!transport_) return;

    transport_->close();
    transport_.reset();

    std::lock_guard<std::mutex> lk(status_mutex_);
    status_.connected = false;
    status_.port.clear();
    status_.baudrate = 0;
}

SessionStatus Session::status() const {
    std::lock_guard<std::mutex> lk(status_mutex_);
    return status_;
}

bool Session::send(const uint8_t* data, std::size_t size) {
    if (!transport_) return false;

    if (!transport_->write(data, size)) {
        return false;
    }

    appendMessage(Direction::Tx,
                std::string(reinterpret_cast<const char*>(data), size),
                std::chrono::system_clock::now());
    return true;
}

bool Session::send(const std::string& data) {
    return send(reinterpret_cast<const uint8_t*>(data.data()), data.size());
}

std::vector<Message> Session::getMessages(uint64_t after_id,
                                        std::size_t limit) const {
    std::lock_guard<std::mutex> lk(msg_mutex_);
    std::vector<Message> result;
    result.reserve(limit);

    for (const auto& m : messages_) {
        if (m.id <= after_id) continue;
        result.push_back(m);
        if (result.size() >= limit) break;
    }

    return result;
}

void Session::clearMessages() {
    std::lock_guard<std::mutex> lk(msg_mutex_);
    messages_.clear();
    next_id_ = 1;
}

void Session::onMessage(MessageCallback cb) {
    std::lock_guard<std::mutex> lk(cb_mutex_);
    user_msg_cb_ = std::move(cb);
}

void Session::onStateChanged(StateCallback cb) {
    std::lock_guard<std::mutex> lk(cb_mutex_);
    user_state_cb_ = std::move(cb);
}

std::vector<PortInfo> Session::listPorts() {
    return UartTransport::listPorts();
}

void Session::appendMessage(Direction dir,
                            const std::string& content,
                            std::chrono::system_clock::time_point ts) {
    Message msg;
    msg.timestamp = ts;
    msg.direction = dir;
    msg.content   = content;

    {
        std::lock_guard<std::mutex> lk(msg_mutex_);
        msg.id = next_id_++;
        messages_.push_back(msg);

        while (messages_.size() > kMaxMessages) {
            messages_.pop_front();
        }
    }

    MessageCallback cb;
    {
        std::lock_guard<std::mutex> lk(cb_mutex_);
        cb = user_msg_cb_;
    }
    if (cb) cb(msg);
}

} // namespace neo
