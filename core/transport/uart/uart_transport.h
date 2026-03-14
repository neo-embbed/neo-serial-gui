#ifndef NEO_CORE_UART_TRANSPORT_H
#define NEO_CORE_UART_TRANSPORT_H

#include "../transport.h"

#include <atomic>
#include <condition_variable>
#include <mutex>
#include <queue>
#include <string>
#include <thread>
#include <vector>

#ifdef _WIN32
#include <windows.h>
#endif

namespace neo {

enum class Parity   { None, Even, Odd, Mark, Space };
enum class StopBits { One, OnePointFive, Two };

struct UartConfig {
    std::string port;                          // "COM3" / "/dev/ttyUSB0"
    uint32_t    baudrate        = 115200;
    uint8_t     databits        = 8;           // 5 / 6 / 7 / 8
    Parity      parity          = Parity::None;
    StopBits    stopbits        = StopBits::One;
    uint32_t    read_timeout_ms = 100;
    uint32_t    write_timeout_ms= 100;
};

struct PortInfo {
    std::string device;       // "COM3"
    std::string description;  // "USB Serial Port (COM3)"
};

// ---------------------------------------------------------------------------
// UartTransport – serial port transport (Win32 / POSIX).
// ---------------------------------------------------------------------------
class UartTransport : public Transport {
public:
    explicit UartTransport(const UartConfig& config);
    ~UartTransport() override;

    bool open()  override;
    void close() override;

    using Transport::write;                    // unhide convenience overloads
    bool write(const uint8_t* data, std::size_t size) override;

    const UartConfig& config() const { return config_; }

    // Enumerate available serial ports (thread-safe, no instance needed).
    static std::vector<PortInfo> listPorts();

    static constexpr std::size_t kWriteQueueMax = 1024;
    static constexpr std::size_t kReadBufSize   = 256;

private:
    void readerLoop();
    void writerLoop();

    UartConfig config_;

    std::atomic<bool> running_{false};
    std::thread       reader_thread_;
    std::thread       writer_thread_;

    // write queue
    std::mutex              wq_mutex_;
    std::condition_variable wq_cv_;
    std::queue<std::vector<uint8_t>> wq_;

    // platform handle
#ifdef _WIN32
    HANDLE handle_ = INVALID_HANDLE_VALUE;
#else
    int fd_ = -1;
#endif
};

} // namespace neo

#endif // NEO_CORE_UART_TRANSPORT_H
