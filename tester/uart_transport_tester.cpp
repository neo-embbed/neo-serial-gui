//#include "../core/transport/transport.h"
#include "../core/transport/uart/uart_transport.h"
#include <iostream>
#include <chrono>
#include <iomanip>

int main() {
    // ---- 第 1 步 初始化串口 ----
    std::cout << "running" << std::endl;
    neo::UartConfig cfg;
    cfg.port     = "COM5";
    cfg.baudrate = 115200;
    auto uart = std::make_unique<neo::UartTransport>(cfg);
    // ---- 第 2 步 注册消息回调 ----
    // 当 uart 收到消息时会触发该回调
    uart->onMessage([](const neo::Message& msg) {
        // 根据消息方向分别处理“接收/发送/系统”消息
        auto t = std::chrono::system_clock::to_time_t(msg.timestamp);
        switch (msg.direction) {
            case neo::Direction::Rx:
                std::cout << std::put_time(std::localtime(&t), "%H:%M:%S") << "[Rx] " << msg.content << std::endl;
                break;
            case neo::Direction::Tx:
                std::cout << std::put_time(std::localtime(&t), "%H:%M:%S") << "[Tx] " << msg.content << std::endl;
                break;
            case neo::Direction::Sys:
                std::cout << std::put_time(std::localtime(&t), "%H:%M:%S") << "[Sys] " << msg.content << std::endl;
                break;
        }
    });

    // ---- 第 3 步 注册状态回调 ----
    uart->onStateChanged([](neo::TransportState state, const std::string& detail) {
        if (state == neo::TransportState::Open)
            std::cout << "串口已打开: " << detail << std::endl;
        else if (state == neo::TransportState::Error)
            std::cout << "串口错误: " << detail << std::endl;
    });

    // ---- 第 4 步 打开串口 ----
    if (!uart->open()) {
        std::cerr << "打开串口失败" << std::endl;
        return 1;
    }
    // open() 会启动读线程 readerLoop：
    //   - 持续读取串口数据
    //   - 收到数据后触发 onMessage 回调
    //   - 无需手动轮询

    // ---- 第 5 步 发送指令 ----
    std::string cmd = "AT+RST\r\n";
    uart->write(cmd);
    uart->emitMessage(neo::Direction::Tx, cmd);

    // ---- 主线程等待一段时间，方便观察回调输出 ----
    std::this_thread::sleep_for(std::chrono::seconds(100));

    // ---- 第 6 步 关闭串口 ----
    uart->close();
    return 0;
}
