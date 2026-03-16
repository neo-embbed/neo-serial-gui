# onMessage

## 注册方法

1.Lamda函数
~~~cpp
xxx->onMessage([](const neo::Message& msg){
    //函数内容
});
~~~
2.经典
~~~cpp
void f(const neo::Message& msg){
    //内容
}

xxx->onMessage(f);
~~~

## Message结构体

- msg.id：消息id
- msg.timestamp：处理时的时间戳`std::chrono::system_clock::time_point`
- msg.direction：enum类型：Rx、Tx、Sys
- msg.content：`std::string`