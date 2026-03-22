#ifndef CARD_BRIDGE_H
#define CARD_BRIDGE_H

#include <QObject>
#include <QQmlEngine>
#include <QJsonArray>
#include <QJsonObject>
#include <QHash>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

#include "../../core/parameter/parameter_card.h"

#include <memory>
#include <vector>

class CardBridge : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString currentName READ currentName WRITE setCurrentName NOTIFY currentNameChanged)
    Q_PROPERTY(int cardCount READ cardCount NOTIFY cardsChanged)
    Q_PROPERTY(QStringList presetNames READ presetNames NOTIFY presetsChanged)

public:
    explicit CardBridge(QObject *parent = nullptr);
    static CardBridge *create(QQmlEngine *, QJSEngine *);
    static CardBridge &instance();

    QString     currentName() const;
    void        setCurrentName(const QString &name);
    int         cardCount() const;
    QStringList presetNames() const;

    // ---- File I/O (JSON format matching reference/monitor_cards.json) ----
    Q_INVOKABLE bool loadFromFile(const QString &path);
    Q_INVOKABLE bool saveToFile(const QString &path);

    // ---- Card CRUD ----
    Q_INVOKABLE int  addCard(const QString &name, const QString &pattern,
                             const QString &type, const QString &unit,
                             const QString &color);
    Q_INVOKABLE void removeCard(int index);
    Q_INVOKABLE void updateCard(int index, const QVariantMap &props);
    Q_INVOKABLE QVariantMap cardAt(int index) const;

    // ---- Preset management ----
    Q_INVOKABLE void savePreset(const QString &name);
    Q_INVOKABLE void loadPreset(const QString &name);
    Q_INVOKABLE void deletePreset(const QString &name);

    // ---- Serial data feed (call from SessionBridge::pollMessages) ----
    Q_INVOKABLE void feed(const QString &line);

    // ---- Card values for QML ----
    Q_INVOKABLE QVariantMap  cardValue(int index) const;
    Q_INVOKABLE QVariantList cardHistory(int index, int afterId = 0, int limit = 200) const;
    Q_INVOKABLE void         clearCardHistory(int index);

signals:
    void currentNameChanged();
    void cardsChanged();
    void presetsChanged();
    void cardValueUpdated(int cardId, const QVariantMap &value);

private:
    struct CardEntry {
        int id = 0;
        std::unique_ptr<neo::ParameterCard> card;
        QString createdAt;
    };

    static neo::CardConfig configFromJson(const QJsonObject &obj);
    static QJsonObject     configToJson(const CardEntry &entry);

    QJsonArray cardsToJson() const;
    void       cardsFromJson(const QJsonArray &arr);
    void       wireCallback(CardEntry &entry);
    void       queueCardValueUpdate(int cardId, QVariantMap value);
    void       flushPendingCardValueUpdates();
    int        nextCardId() const;

    static CardBridge *instance_;

    QString                 currentName_;
    std::vector<CardEntry>  cards_;
    QJsonArray              presets_;
    QHash<int, QVariantMap> pendingValueUpdates_;
    QTimer                  valueFlushTimer_;

    static constexpr int kValueFlushIntervalMs = 50;
};

#endif // CARD_BRIDGE_H
