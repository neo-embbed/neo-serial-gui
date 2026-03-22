#include "session_bridge.h"
#include "card_bridge.h"

#include <QDebug>
#include <QMetaObject>
#include <QVariantMap>

SessionBridge *SessionBridge::create(QQmlEngine *qmlEngine, QJSEngine *) {
    static SessionBridge instance;
    instance.pollTimer_.start();
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
    session_.onStateChanged([this](neo::TransportState, const std::string &) {
        QMetaObject::invokeMethod(this, &SessionBridge::statusChanged,
                                  Qt::QueuedConnection);
    });

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
    return session_.send(data.toStdString());
}

bool SessionBridge::sendHex(const QString &hexStr) {
    QString cleaned = hexStr.simplified().remove(' ');
    if (cleaned.size() % 2 != 0)
        return false;

    std::vector<uint8_t> bytes;
    bytes.reserve(cleaned.size() / 2);
    for (int i = 0; i < cleaned.size(); i += 2) {
        bool ok;
        uint8_t byte = cleaned.mid(i, 2).toUInt(&ok, 16);
        if (!ok)
            return false;
        bytes.push_back(byte);
    }
    return session_.send(bytes.data(), bytes.size());
}

void SessionBridge::clearLog() {
    session_.clearMessages();
    lastMsgId_ = 0;
    log_.clear();
    logLineCount_ = 0;
    emit logChanged();
    emit logCleared();
    emit logRebuilt();
}

void SessionBridge::pollMessages() {
    auto msgs = session_.getMessages(lastMsgId_);
    if (msgs.empty())
        return;

    QVariantList batch;
    batch.reserve(static_cast<qsizetype>(msgs.size()));

    for (const auto &m : msgs) {
        QString prefix = directionToString(m.direction);
        QString content = QString::fromStdString(m.content);
        QString line = QStringLiteral("[%1] %2\n").arg(prefix, content);

        if (m.direction == neo::Direction::Rx)
            CardBridge::instance().feed(content);

        log_.append(line);
        ++logLineCount_;
        lastMsgId_ = m.id;

        QVariantMap item;
        item.insert(QStringLiteral("line"), line);
        batch.append(item);

    }

    emit logChanged();
    emit messagesReceived(batch);
    if (trimLogIfNeeded())
        emit logRebuilt();
}

bool SessionBridge::trimLogIfNeeded() {
    if (logLineCount_ <= kMaxLogLines)
        return false;

    qsizetype linesToTrim = logLineCount_ - kMaxLogLines;
    qsizetype cutPos = 0;
    while (linesToTrim > 0) {
        cutPos = log_.indexOf('\n', cutPos);
        if (cutPos < 0) {
            log_.clear();
            logLineCount_ = 0;
            return true;
        }
        ++cutPos;
        --linesToTrim;
    }

    if (cutPos > 0)
        log_ = log_.mid(cutPos);   // mid() allocates a fresh buffer; remove() keeps the old one
    logLineCount_ = kMaxLogLines;
    emit logChanged();
    return true;
}
