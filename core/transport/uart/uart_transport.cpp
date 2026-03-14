#include "uart_transport.h"

#include <algorithm>
#include <cstring>

#ifdef _WIN32
// Win32 headers already pulled in via uart_transport.h
#else
#  include <dirent.h>
#  include <errno.h>
#  include <fcntl.h>
#  include <termios.h>
#  include <unistd.h>
#endif

namespace neo {

// ===========================================================================
// Construction / destruction
// ===========================================================================

UartTransport::UartTransport(const UartConfig& config)
    : config_(config) {}

UartTransport::~UartTransport() {
    close();
}

// ===========================================================================
// open
// ===========================================================================

bool UartTransport::open() {
    if (running_.load()) return false;

#ifdef _WIN32
    // ---- Windows ----------------------------------------------------------
    // Prefix with \\.\\ so COM ports > 9 work correctly.
    std::string path = "\\\\.\\" + config_.port;
    handle_ = CreateFileA(
        path.c_str(),
        GENERIC_READ | GENERIC_WRITE,
        0,                          // exclusive access
        nullptr,
        OPEN_EXISTING,
        0,                          // synchronous I/O
        nullptr);

    if (handle_ == INVALID_HANDLE_VALUE) {
        setState(TransportState::Error, "Failed to open " + config_.port);
        return false;
    }

    // -- DCB (baud, data bits, parity, stop bits) ---------------------------
    DCB dcb{};
    dcb.DCBlength = sizeof(DCB);
    if (!GetCommState(handle_, &dcb)) {
        CloseHandle(handle_); handle_ = INVALID_HANDLE_VALUE;
        setState(TransportState::Error, "GetCommState failed");
        return false;
    }

    dcb.BaudRate = config_.baudrate;
    dcb.ByteSize = config_.databits;

    switch (config_.parity) {
        case Parity::None:  dcb.Parity = NOPARITY;    break;
        case Parity::Even:  dcb.Parity = EVENPARITY;   break;
        case Parity::Odd:   dcb.Parity = ODDPARITY;    break;
        case Parity::Mark:  dcb.Parity = MARKPARITY;   break;
        case Parity::Space: dcb.Parity = SPACEPARITY;  break;
    }

    switch (config_.stopbits) {
        case StopBits::One:          dcb.StopBits = ONESTOPBIT;   break;
        case StopBits::OnePointFive: dcb.StopBits = ONE5STOPBITS; break;
        case StopBits::Two:          dcb.StopBits = TWOSTOPBITS;  break;
    }

    dcb.fBinary      = TRUE;
    dcb.fParity      = (config_.parity != Parity::None) ? TRUE : FALSE;
    dcb.fDtrControl  = DTR_CONTROL_ENABLE;
    dcb.fRtsControl  = RTS_CONTROL_ENABLE;
    dcb.fOutxCtsFlow = FALSE;
    dcb.fOutxDsrFlow = FALSE;
    dcb.fOutX        = FALSE;
    dcb.fInX         = FALSE;

    if (!SetCommState(handle_, &dcb)) {
        CloseHandle(handle_); handle_ = INVALID_HANDLE_VALUE;
        setState(TransportState::Error, "SetCommState failed");
        return false;
    }

    // -- Timeouts -----------------------------------------------------------
    COMMTIMEOUTS to{};
    to.ReadIntervalTimeout         = 50;
    to.ReadTotalTimeoutMultiplier  = 0;
    to.ReadTotalTimeoutConstant    = config_.read_timeout_ms;
    to.WriteTotalTimeoutMultiplier = 0;
    to.WriteTotalTimeoutConstant   = config_.write_timeout_ms;

    if (!SetCommTimeouts(handle_, &to)) {
        CloseHandle(handle_); handle_ = INVALID_HANDLE_VALUE;
        setState(TransportState::Error, "SetCommTimeouts failed");
        return false;
    }

    PurgeComm(handle_, PURGE_RXCLEAR | PURGE_TXCLEAR);

#else
    // ---- POSIX ------------------------------------------------------------
    fd_ = ::open(config_.port.c_str(), O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (fd_ < 0) {
        setState(TransportState::Error, "Failed to open " + config_.port);
        return false;
    }

    // clear O_NONBLOCK after open
    int flags = fcntl(fd_, F_GETFL, 0);
    fcntl(fd_, F_SETFL, flags & ~O_NONBLOCK);

    struct termios tty{};
    if (tcgetattr(fd_, &tty) != 0) {
        ::close(fd_); fd_ = -1;
        setState(TransportState::Error, "tcgetattr failed");
        return false;
    }

    // baud
    speed_t speed = B115200;
    switch (config_.baudrate) {
        case 9600:    speed = B9600;   break;
        case 19200:   speed = B19200;  break;
        case 38400:   speed = B38400;  break;
        case 57600:   speed = B57600;  break;
        case 115200:  speed = B115200; break;
#ifdef B230400
        case 230400:  speed = B230400; break;
#endif
#ifdef B460800
        case 460800:  speed = B460800; break;
#endif
#ifdef B921600
        case 921600:  speed = B921600; break;
#endif
        default:      speed = B115200; break;
    }
    cfsetispeed(&tty, speed);
    cfsetospeed(&tty, speed);

    // data bits
    tty.c_cflag &= ~CSIZE;
    switch (config_.databits) {
        case 5: tty.c_cflag |= CS5; break;
        case 6: tty.c_cflag |= CS6; break;
        case 7: tty.c_cflag |= CS7; break;
        default: tty.c_cflag |= CS8; break;
    }

    // parity
    switch (config_.parity) {
        case Parity::Even:
            tty.c_cflag |= PARENB;
            tty.c_cflag &= ~PARODD;
            break;
        case Parity::Odd:
            tty.c_cflag |= PARENB;
            tty.c_cflag |= PARODD;
            break;
        default:
            tty.c_cflag &= ~PARENB;
            break;
    }

    // stop bits
    if (config_.stopbits == StopBits::Two)
        tty.c_cflag |= CSTOPB;
    else
        tty.c_cflag &= ~CSTOPB;

    // raw mode
    tty.c_cflag |= (CLOCAL | CREAD);
    tty.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
    tty.c_iflag &= ~(IXON | IXOFF | IXANY | IGNBRK | BRKINT |
                      PARMRK | ISTRIP | INLCR | IGNCR | ICRNL);
    tty.c_oflag &= ~OPOST;

    // read timeout (VTIME unit = 0.1 s)
    tty.c_cc[VMIN]  = 0;
    tty.c_cc[VTIME] = std::max<cc_t>(1, config_.read_timeout_ms / 100);

    if (tcsetattr(fd_, TCSANOW, &tty) != 0) {
        ::close(fd_); fd_ = -1;
        setState(TransportState::Error, "tcsetattr failed");
        return false;
    }

    tcflush(fd_, TCIOFLUSH);
#endif

    // ---- start I/O threads ------------------------------------------------
    running_.store(true);
    reader_thread_ = std::thread(&UartTransport::readerLoop, this);
    writer_thread_ = std::thread(&UartTransport::writerLoop, this);

    std::string detail = config_.port + " @ " + std::to_string(config_.baudrate);
    setState(TransportState::Open, detail);
    emitMessage(Direction::Sys, "Connected to " + detail);
    return true;
}

// ===========================================================================
// close
// ===========================================================================

void UartTransport::close() {
    if (!running_.exchange(false)) return;

    // wake writer thread
    wq_cv_.notify_all();

    // close handle – unblocks any pending reads/writes
#ifdef _WIN32
    if (handle_ != INVALID_HANDLE_VALUE) {
        CloseHandle(handle_);
        handle_ = INVALID_HANDLE_VALUE;
    }
#else
    if (fd_ >= 0) {
        ::close(fd_);
        fd_ = -1;
    }
#endif

    if (reader_thread_.joinable()) reader_thread_.join();
    if (writer_thread_.joinable()) writer_thread_.join();

    // drain write queue
    {
        std::lock_guard<std::mutex> lk(wq_mutex_);
        std::queue<std::vector<uint8_t>>().swap(wq_);
    }

    setState(TransportState::Closed);
    emitMessage(Direction::Sys, "Disconnected");
}

// ===========================================================================
// write  (queue data for the writer thread)
// ===========================================================================

bool UartTransport::write(const uint8_t* data, std::size_t size) {
    if (!running_.load() || size == 0) return false;

    {
        std::lock_guard<std::mutex> lk(wq_mutex_);
        if (wq_.size() >= kWriteQueueMax) return false;
        wq_.emplace(data, data + size);
    }
    wq_cv_.notify_one();
    return true;
}

// ===========================================================================
// readerLoop  (runs on dedicated thread)
// ===========================================================================

void UartTransport::readerLoop() {
    uint8_t buf[kReadBufSize];

    while (running_.load()) {
#ifdef _WIN32
        DWORD n = 0;
        if (!ReadFile(handle_, buf, sizeof(buf), &n, nullptr)) {
            if (running_.load())
                emitMessage(Direction::Sys,
                            "Read error (code " + std::to_string(GetLastError()) + ")");
            break;
        }
#else
        ssize_t n = ::read(fd_, buf, sizeof(buf));
        if (n < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) continue;
            if (running_.load())
                emitMessage(Direction::Sys,
                            std::string("Read error: ") + strerror(errno));
            break;
        }
#endif
        if (n > 0)
            emitMessage(Direction::Rx,
                        std::string(reinterpret_cast<char*>(buf),
                                    static_cast<std::size_t>(n)));
    }
}

// ===========================================================================
// writerLoop  (runs on dedicated thread)
// ===========================================================================

void UartTransport::writerLoop() {
    while (running_.load()) {
        std::vector<uint8_t> pkt;
        {
            std::unique_lock<std::mutex> lk(wq_mutex_);
            wq_cv_.wait_for(lk, std::chrono::milliseconds(100), [this] {
                return !wq_.empty() || !running_.load();
            });
            if (!running_.load()) break;
            if (wq_.empty()) continue;
            pkt = std::move(wq_.front());
            wq_.pop();
        }

#ifdef _WIN32
        DWORD written = 0;
        if (!WriteFile(handle_, pkt.data(),
                       static_cast<DWORD>(pkt.size()), &written, nullptr)
            || written != static_cast<DWORD>(pkt.size()))
        {
            if (running_.load())
                emitMessage(Direction::Sys,
                            "Write incomplete (" + std::to_string(written) +
                            "/" + std::to_string(pkt.size()) + " bytes)");
        }
#else
        ssize_t written = ::write(fd_, pkt.data(), pkt.size());
        if (written < 0 ||
            static_cast<std::size_t>(written) != pkt.size())
        {
            if (running_.load())
                emitMessage(Direction::Sys,
                            std::string("Write error: ") + strerror(errno));
        }
#endif
    }
}

// ===========================================================================
// listPorts  (static)
// ===========================================================================

std::vector<PortInfo> UartTransport::listPorts() {
    std::vector<PortInfo> ports;

#ifdef _WIN32
    // Read from HKLM\HARDWARE\DEVICEMAP\SERIALCOMM
    HKEY hKey = nullptr;
    if (RegOpenKeyExA(HKEY_LOCAL_MACHINE,
                      "HARDWARE\\DEVICEMAP\\SERIALCOMM",
                      0, KEY_READ, &hKey) != ERROR_SUCCESS)
        return ports;

    char valueName[256];
    char valueData[256];

    for (DWORD idx = 0; ; ++idx) {
        DWORD nameLen = sizeof(valueName);
        DWORD dataLen = sizeof(valueData);
        DWORD type    = 0;

        LONG rc = RegEnumValueA(hKey, idx,
                                valueName, &nameLen,
                                nullptr, &type,
                                reinterpret_cast<BYTE*>(valueData), &dataLen);
        if (rc != ERROR_SUCCESS) break;

        if (type == REG_SZ) {
            PortInfo info;
            info.device      = std::string(valueData, dataLen > 0 ? dataLen - 1 : 0);
            info.description = std::string(valueName, nameLen);
            ports.push_back(std::move(info));
        }
    }
    RegCloseKey(hKey);

#else
    // Scan /dev for common serial device prefixes
    static const char* prefixes[] = {
        "ttyUSB", "ttyACM", "ttyS", "tty.usbserial", "tty.usbmodem"
    };

    DIR* dir = opendir("/dev");
    if (!dir) return ports;

    while (struct dirent* ent = readdir(dir)) {
        std::string name = ent->d_name;
        for (const char* pfx : prefixes) {
            if (name.compare(0, strlen(pfx), pfx) == 0) {
                PortInfo info;
                info.device      = "/dev/" + name;
                info.description = name;
                ports.push_back(std::move(info));
                break;
            }
        }
    }
    closedir(dir);
#endif

    std::sort(ports.begin(), ports.end(),
              [](const PortInfo& a, const PortInfo& b) {
                  return a.device < b.device;
              });
    return ports;
}

} // namespace neo
