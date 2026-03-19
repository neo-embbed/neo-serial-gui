#include "session_bridge.h"

#include <QMetaObject>

SessionBridge *SessionBridge::create(QQmlEngine *qmlEngine, QJSEngine *) {
    static SessionBridge instance;
    instance.pollTimer_.start();  // ensure timer is running
    QJSEngine::setObjectOwnership(&instance, QJSEngine::CppOwnership);
    return &instance;
}

static QString directionToString(neo::Direction dir) {
    switch (dir) {
    case neo::Direction::Rx:  return QStringLiteral("RX");
    case neo::Direction::Tx:  return QStringLiteral("TX");
    case neo::Direction::Sys: return QStringLiteral("SYS");
    }
    return QStringLiteral("???");
}

SessionBridge::SessionBridge(QObject *parent)
    : QObject(parent)
{
    // Transport回调在I/O线程上触发，通过queued信号转发到GUI线程
    session_.onStateChanged([this](neo::TransportState, const std::string &) {
        QMetaObject::invokeMethod(this, &SessionBridge::statusChanged,
                                Qt::QueuedConnection);
    });

    session_.onMessage([this](const neo::Message &msg) {
        QString dir = directionToString(msg.direction);
        QString content = QString::fromStdString(msg.content);
        QMetaObject::invokeMethod(this, [this, dir, content]() {
            emit messageReceived(dir, content);
        }, Qt::QueuedConnection);
    });

    // 定时轮询消息历史，更新日志文本
    pollTimer_.setInterval(50);
    connect(&pollTimer_, &QTimer::timeout, this, &SessionBridge::pollMessages);
    pollTimer_.start();

    refreshPorts();
}

bool SessionBridge::connected() const {
    return session_.status().connected;
}

QString SessionBridge::detail() const {
    return QString::fromStdString(session_.status().detail);
}

QStringList SessionBridge::portList() const {
    return ports_;
}

QString SessionBridge::log() const {
    return log_;
}

void SessionBridge::refreshPorts() {
    auto infos = neo::Session::listPorts();
    QStringList list;
    for (const auto &p : infos)
        list << QString::fromStdString(p.device);
    if (list != ports_) {
        ports_ = list;
        emit portListChanged();
    }
}

bool SessionBridge::connectPort(const QString &port, int baudRate) {
    neo::UartConfig cfg;
    cfg.port = port.toStdString();
    cfg.baudrate = static_cast<uint32_t>(baudRate);

    auto transport = std::make_unique<neo::UartTransport>(cfg);
    bool ok = session_.connect(std::move(transport));
    emit statusChanged();
    return ok;
}

void SessionBridge::disconnectPort() {
    session_.disconnect();
    emit statusChanged();
}

bool SessionBridge::send(const QString &data) {
    bool ok = session_.send(data.toStdString());
    return ok;
}

bool SessionBridge::sendHex(const QString &hexStr) {
    // 解析hex字符串，如 "48 65 6C 6C 6F"
    QString cleaned = hexStr.simplified().remove(' ');
    if (cleaned.size() % 2 != 0)
        return false;

    std::vector<uint8_t> bytes;
    bytes.reserve(cleaned.size() / 2);
    for (int i = 0; i < cleaned.size(); i += 2) {
        bool ok;
        uint8_t byte = cleaned.mid(i, 2).toUInt(&ok, 16);
        if (!ok) return false;
        bytes.push_back(byte);
    }
    return session_.send(bytes.data(), bytes.size());
}

void SessionBridge::clearLog() {
    session_.clearMessages();
    lastMsgId_ = 0;
    log_.clear();
    emit logChanged();
}

void SessionBridge::pollMessages() {
    auto msgs = session_.getMessages(lastMsgId_);
    if (msgs.empty())
        return;

    for (const auto &m : msgs) {
        QString prefix = directionToString(m.direction);
        QString line = QStringLiteral("[%1] %2\n")
                           .arg(prefix, QString::fromStdString(m.content));
        log_.append(line);
        lastMsgId_ = m.id;
    }
    emit logChanged();
}
