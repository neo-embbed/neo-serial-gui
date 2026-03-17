#include "../core/session/session.h"
//#include "../core/transport/uart/uart_transport.h"
#include <iostream>
#include <chrono>
#include <iomanip>

neo::SessionStatus st;

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
    std::cout << "Port: " << st.port << ", Baudrate: " << st.baudrate << std::endl;
    session.onMessage(onMessageHandler);
}

int main()
{
    auto UartSession = std::make_unique<neo::Session>();
    //done cfg测试用例
    neo::UartConfig cfg;
    cfg.port     = "COM5";
    cfg.baudrate = 115200;
    //done 测试连接成功与失败情况
    if (!UartSession->connect(cfg)) {
        std::cerr << "Serial connection failed" << std::endl;
        return 1;
    }
    else {
        std::cout << "Serial connection successful" << std::endl;
        ConnectedHandler(*UartSession);
    }
    while(1)
    {

    }
    return 0;
}