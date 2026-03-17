#include "../core/session/session.h"
#include "../core/transport/uart/uart_transport.h"
#include <iostream>
#include <chrono>
#include <iomanip>
#include <vector>

neo::SessionStatus st;
std::vector<neo::Message> msgs;

void onMessageHandler(const neo::Message& msg) {
    //done msg内容测试
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
}
void ConnectedHandler(neo::Session& session) {
    std::cout << "ConnectedHandler called" << std::endl;
    st = session.status();
    //done 测试status获取串口状态
    const char* state_str = "Unknown";
    switch (st.state) {
        case neo::TransportState::Closed:
            state_str = "Closed";
            break;
        case neo::TransportState::Open:
            state_str = "Open";
            break;
        case neo::TransportState::Error:
            state_str = "Error";
            break;
    }
    std::cout << "Connected: " << (st.connected ? "true" : "false")
              << ", State: " << state_str << std::endl;
    if (!st.detail.empty()) {
        std::cout << "Detail: " << st.detail << std::endl;
    }
    //session.onMessage(onMessageHandler);  //done 测试消息回调
}
int main()
{
    auto UartSession = std::make_unique<neo::Session>();
    auto UartTransport = std::make_unique<neo::UartTransport>(neo::UartConfig{
        .port = "COM5",
        .baudrate = 115200
    });
    //done 测试连接成功与失败情况
    if (!UartSession->connect(std::move(UartTransport))) {
        std::cerr << "Serial connection failed" << std::endl;
        return 1;
    }
    else {
        std::cout << "Serial connection successful" << std::endl;
        ConnectedHandler(*UartSession);
    }
    while(1)
    {
        char c;
        std::cin >> c;
        if (c == 'q') {
            //测试获取消息缓存
            msgs = UartSession->getMessages();
            std::cout << msgs.size() << " messages in cache" << std::endl;
        }
    }
    return 0;
}