#ifndef NEO_CORE_TRANSPORT_H
#define NEO_CORE_TRANSPORT_H

#include <chrono>
#include <cstdint>
#include <functional>
#include <mutex>
#include <string>
#include <vector>

namespace neo {

enum class TransportState {
    Closed,
    Open,
    Error
};

enum class Direction {
    Rx,  // received from device
    Tx,  // sent to device
    Sys  // system / diagnostic
};

struct Message {
    uint64_t id;
    std::chrono::system_clock::time_point timestamp;
    Direction direction;
    std::string content;
};

using StateCallback   = std::function<void(TransportState state, const std::string& detail)>;
using MessageCallback = std::function<void(const Message& msg)>;

// ---------------------------------------------------------------------------
// Transport – abstract base for all byte-stream transports.
//
// Threading contract:
//   * open() / close() must be called from the same (owner) thread.
//   * write() is thread-safe and may be called from any thread.
//   * Callbacks fire on internal I/O threads – keep them lightweight.
//     Do NOT call close() from inside a callback (deadlock risk).
// ---------------------------------------------------------------------------
class Transport {
public:
    virtual ~Transport() = default;

    Transport(const Transport&)            = delete;
    Transport& operator=(const Transport&) = delete;

    // --- core interface (implemented by each transport) --------------------
    virtual bool open()  = 0;
    virtual void close() = 0;
    virtual bool write(const uint8_t* data, std::size_t size) = 0;

    // convenience overloads
    bool write(const std::vector<uint8_t>& data) {
        return write(data.data(), data.size());
    }
    bool write(const std::string& text) {
        return write(reinterpret_cast<const uint8_t*>(text.data()), text.size());
    }

    // --- state query -------------------------------------------------------
    TransportState state() const {
        std::lock_guard<std::mutex> lk(mutex_);
        return state_;
    }

    // --- callbacks ---------------------------------------------------------
    void onStateChanged(StateCallback cb) {
        std::lock_guard<std::mutex> lk(mutex_);
        state_cb_ = std::move(cb);
    }

    void onMessage(MessageCallback cb) {
        std::lock_guard<std::mutex> lk(mutex_);
        msg_cb_ = std::move(cb);
    }

    // Emit an application-level message (Tx / Sys).
    // Rx messages are emitted internally by the reader thread.
    uint64_t emitMessage(Direction dir, const std::string& content) {
        Message msg;
        msg.timestamp = std::chrono::system_clock::now();
        msg.direction = dir;
        msg.content   = content;

        MessageCallback cb;
        {
            std::lock_guard<std::mutex> lk(mutex_);
            msg.id = next_id_++;
            cb     = msg_cb_;
        }
        if (cb) cb(msg);
        return msg.id;
    }

protected:
    Transport() = default;

    void setState(TransportState s, const std::string& detail = "") {
        StateCallback cb;
        {
            std::lock_guard<std::mutex> lk(mutex_);
            state_ = s;
            cb     = state_cb_;
        }
        if (cb) cb(s, detail);
    }

    mutable std::mutex mutex_;

private:
    TransportState  state_    {TransportState::Closed};
    StateCallback   state_cb_;
    MessageCallback msg_cb_;
    uint64_t        next_id_  {1};
};

} // namespace neo

#endif // NEO_CORE_TRANSPORT_H
