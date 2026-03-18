#ifndef SESSION_BRIDGE_H
#define SESSION_BRIDGE_H

#include <QObject>
#include <QQmlEngine>
#include <QStringList>
#include <QTimer>

#include "../../core/session/session.h"

class SessionBridge : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool connected READ connected NOTIFY statusChanged)
    Q_PROPERTY(QString detail READ detail NOTIFY statusChanged)
    Q_PROPERTY(QStringList portList READ portList NOTIFY portListChanged)
    Q_PROPERTY(QString log READ log NOTIFY logChanged)

public:
    explicit SessionBridge(QObject *parent = nullptr);
    static SessionBridge *create(QQmlEngine *, QJSEngine *);

    bool connected() const;
    QString detail() const;
    QStringList portList() const;
    QString log() const;

    Q_INVOKABLE void refreshPorts();
    Q_INVOKABLE bool connectPort(const QString &port, int baudRate);
    Q_INVOKABLE void disconnectPort();
    Q_INVOKABLE bool send(const QString &data);
    Q_INVOKABLE bool sendHex(const QString &hexStr);
    Q_INVOKABLE void clearLog();

signals:
    void statusChanged();
    void portListChanged();
    void logChanged();
    void messageReceived(const QString &direction, const QString &content);

private:
    void pollMessages();

    neo::Session session_;
    QStringList ports_;
    QString log_;
    uint64_t lastMsgId_ = 0;
    QTimer pollTimer_;
};

#endif // SESSION_BRIDGE_H
