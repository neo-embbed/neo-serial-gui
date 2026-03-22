#include "card_bridge.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QMetaObject>

namespace {

qint64 toTimestampMs(const std::chrono::system_clock::time_point &timestamp) {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
               timestamp.time_since_epoch())
        .count();
}

} // namespace

// ---- Singleton -----------------------------------------------------------

CardBridge *CardBridge::instance_ = nullptr;

CardBridge *CardBridge::create(QQmlEngine *, QJSEngine *jsEngine) {
    if (!instance_)
        instance_ = new CardBridge();
    QJSEngine::setObjectOwnership(instance_, QJSEngine::CppOwnership);
    return instance_;
}

CardBridge &CardBridge::instance() {
    if (!instance_)
        instance_ = new CardBridge();
    return *instance_;
}

CardBridge::CardBridge(QObject *parent)
    : QObject(parent)
{
    instance_ = this;
    valueFlushTimer_.setSingleShot(true);
    valueFlushTimer_.setInterval(kValueFlushIntervalMs);
    connect(&valueFlushTimer_, &QTimer::timeout,
            this, &CardBridge::flushPendingCardValueUpdates);
}

// ---- Properties ----------------------------------------------------------

QString CardBridge::currentName() const { return currentName_; }

void CardBridge::setCurrentName(const QString &name) {
    if (currentName_ != name) {
        currentName_ = name;
        emit currentNameChanged();
    }
}

int CardBridge::cardCount() const {
    return static_cast<int>(cards_.size());
}

QStringList CardBridge::presetNames() const {
    QStringList names;
    for (const auto &p : presets_) {
        if (p.isObject())
            names << p.toObject().value("name").toString();
    }
    return names;
}

// ---- File I/O ------------------------------------------------------------
//
// JSON format (matches reference/monitor_cards.json):
// {
//   "current": { "name": "...", "cards": [...] },
//   "presets": [ { "name": "...", "cards": [...], "saved_at": "..." }, ... ]
// }

bool CardBridge::loadFromFile(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return false;
    }

    QJsonParseError err;
    auto doc = QJsonDocument::fromJson(file.readAll(), &err);
    if (err.error != QJsonParseError::NoError) {
        return false;
    }

    QJsonObject root = doc.object();

    QJsonObject current = root.value("current").toObject();
    setCurrentName(current.value("name").toString());
    cardsFromJson(current.value("cards").toArray());

    presets_ = root.value("presets").toArray();
    emit presetsChanged();

    return true;
}

bool CardBridge::saveToFile(const QString &path) {
    QJsonObject current;
    current["name"]  = currentName_;
    current["cards"] = cardsToJson();

    QJsonObject root;
    root["current"] = current;
    root["presets"] = presets_;

    QFileInfo fi(path);
    QDir().mkpath(fi.absolutePath());

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return false;

    file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    return true;
}

// ---- Card CRUD -----------------------------------------------------------

int CardBridge::addCard(const QString &name, const QString &pattern,
                        const QString &type, const QString &unit,
                        const QString &color) {
    neo::CardConfig cfg;
    cfg.name    = name.toStdString();
    cfg.pattern = pattern.toStdString();
    cfg.type    = (type == "boolean") ? neo::CardType::Boolean
                                      : neo::CardType::Numeric;
    cfg.unit    = unit.toStdString();
    cfg.color   = color.toStdString();
    cfg.enabled = true;

    CardEntry entry;
    entry.id        = nextCardId();
    entry.card      = std::make_unique<neo::ParameterCard>(cfg);
    entry.createdAt = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);

    wireCallback(entry);
    cards_.push_back(std::move(entry));
    emit cardsChanged();
    return cards_.back().id;
}

void CardBridge::removeCard(int index) {
    if (index < 0 || index >= static_cast<int>(cards_.size()))
        return;
    pendingValueUpdates_.remove(cards_[index].id);
    cards_.erase(cards_.begin() + index);
    emit cardsChanged();
}

void CardBridge::updateCard(int index, const QVariantMap &props) {
    if (index < 0 || index >= static_cast<int>(cards_.size()))
        return;

    auto &entry = cards_[index];
    neo::CardConfig cfg = entry.card->config();

    if (props.contains("name"))    cfg.name    = props["name"].toString().toStdString();
    if (props.contains("pattern")) cfg.pattern = props["pattern"].toString().toStdString();
    if (props.contains("type"))    cfg.type    = (props["type"].toString() == "boolean")
                                                  ? neo::CardType::Boolean
                                                  : neo::CardType::Numeric;
    if (props.contains("unit"))    cfg.unit    = props["unit"].toString().toStdString();
    if (props.contains("color"))   cfg.color   = props["color"].toString().toStdString();
    if (props.contains("enabled")) cfg.enabled = props["enabled"].toBool();

    entry.card->updateConfig(cfg);
    emit cardsChanged();
}

QVariantMap CardBridge::cardAt(int index) const {
    QVariantMap vm;
    if (index < 0 || index >= static_cast<int>(cards_.size()))
        return vm;

    const auto &entry = cards_[index];
    const auto &cfg   = entry.card->config();

    vm["id"]         = entry.id;
    vm["name"]       = QString::fromStdString(cfg.name);
    vm["pattern"]    = QString::fromStdString(cfg.pattern);
    vm["type"]       = (cfg.type == neo::CardType::Boolean) ? "boolean" : "numeric";
    vm["unit"]       = QString::fromStdString(cfg.unit);
    vm["color"]      = QString::fromStdString(cfg.color);
    vm["enabled"]    = cfg.enabled;
    vm["created_at"] = entry.createdAt;
    return vm;
}

// ---- Presets -------------------------------------------------------------

void CardBridge::savePreset(const QString &name) {
    QJsonArray updated;
    for (const auto &p : presets_) {
        if (p.isObject() && p.toObject().value("name").toString() != name)
            updated.append(p);
    }

    QJsonObject preset;
    preset["name"]     = name;
    preset["cards"]    = cardsToJson();
    preset["saved_at"] = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
    updated.append(preset);

    presets_ = updated;
    emit presetsChanged();
}

void CardBridge::loadPreset(const QString &name) {
    for (const auto &p : presets_) {
        if (!p.isObject())
            continue;
        QJsonObject obj = p.toObject();
        if (obj.value("name").toString() == name) {
            setCurrentName(name);
            cardsFromJson(obj.value("cards").toArray());
            return;
        }
    }
}

void CardBridge::deletePreset(const QString &name) {
    QJsonArray updated;
    for (const auto &p : presets_) {
        if (p.isObject() && p.toObject().value("name").toString() != name)
            updated.append(p);
    }
    presets_ = updated;
    emit presetsChanged();
}

// ---- Feed ----------------------------------------------------------------

void CardBridge::feed(const QString &line) {
    std::string str = line.toStdString();
    for (auto &entry : cards_) {
        entry.card->feed(str);
    }
}

// ---- Card values for QML -------------------------------------------------

QVariantMap CardBridge::cardValue(int index) const {
    QVariantMap vm;
    if (index < 0 || index >= static_cast<int>(cards_.size()))
        return vm;

    const auto &entry = cards_[index];
    if (!entry.card->hasValue())
        return vm;

    auto v = entry.card->currentValue();
    const auto &cfg = entry.card->config();

    vm["id"]           = static_cast<int>(v.id);
    vm["numeric"]      = v.numeric;
    vm["boolean"]      = v.boolean;
    vm["matched"]      = v.matched;
    vm["raw"]          = QString::fromStdString(v.raw);
    vm["timestamp_ms"] = toTimestampMs(v.timestamp);
    vm["type"]         = (cfg.type == neo::CardType::Boolean) ? "boolean" : "numeric";
    return vm;
}

QVariantList CardBridge::cardHistory(int index, int afterId, int limit) const {
    QVariantList list;
    if (index < 0 || index >= static_cast<int>(cards_.size()))
        return list;

    auto history = cards_[index].card->getHistory(
        static_cast<uint64_t>(afterId),
        static_cast<std::size_t>(limit));

    for (const auto &v : history) {
        QVariantMap vm;
        vm["id"]           = static_cast<int>(v.id);
        vm["numeric"]      = v.numeric;
        vm["boolean"]      = v.boolean;
        vm["matched"]      = v.matched;
        vm["raw"]          = QString::fromStdString(v.raw);
        vm["timestamp_ms"] = toTimestampMs(v.timestamp);
        list.append(vm);
    }
    return list;
}

void CardBridge::clearCardHistory(int index) {
    if (index < 0 || index >= static_cast<int>(cards_.size()))
        return;
    cards_[index].card->clearHistory();
    pendingValueUpdates_.remove(cards_[index].id);
}

// ---- Internal helpers ----------------------------------------------------

neo::CardConfig CardBridge::configFromJson(const QJsonObject &obj) {
    neo::CardConfig cfg;
    cfg.name    = obj.value("name").toString().toStdString();
    cfg.pattern = obj.value("pattern").toString().toStdString();
    cfg.type    = (obj.value("type").toString() == "boolean")
                  ? neo::CardType::Boolean : neo::CardType::Numeric;
    cfg.unit    = obj.value("unit").toString().toStdString();
    cfg.color   = obj.value("color").toString().toStdString();
    cfg.enabled = obj.value("enabled").toBool(true);
    return cfg;
}

QJsonObject CardBridge::configToJson(const CardEntry &entry) {
    const auto &cfg = entry.card->config();
    QJsonObject obj;
    obj["id"]         = entry.id;
    obj["name"]       = QString::fromStdString(cfg.name);
    obj["pattern"]    = QString::fromStdString(cfg.pattern);
    obj["type"]       = (cfg.type == neo::CardType::Boolean) ? "boolean" : "numeric";
    obj["enabled"]    = cfg.enabled;
    obj["unit"]       = QString::fromStdString(cfg.unit);
    obj["color"]      = QString::fromStdString(cfg.color);
    obj["created_at"] = entry.createdAt;
    return obj;
}

QJsonArray CardBridge::cardsToJson() const {
    QJsonArray arr;
    for (const auto &entry : cards_)
        arr.append(configToJson(entry));
    return arr;
}

void CardBridge::cardsFromJson(const QJsonArray &arr) {
    cards_.clear();
    pendingValueUpdates_.clear();

    for (const auto &val : arr) {
        if (!val.isObject())
            continue;
        QJsonObject obj = val.toObject();

        CardEntry entry;
        entry.id        = obj.value("id").toInt();
        entry.card      = std::make_unique<neo::ParameterCard>(configFromJson(obj));
        entry.createdAt = obj.value("created_at").toString();

        wireCallback(entry);
        cards_.push_back(std::move(entry));
    }
    emit cardsChanged();
}

void CardBridge::wireCallback(CardEntry &entry) {
    int cardId = entry.id;
    entry.card->onValueChanged([this, cardId](const neo::CardValue &v) {
        QVariantMap vm;
        vm["id"]           = static_cast<int>(v.id);
        vm["numeric"]      = v.numeric;
        vm["boolean"]      = v.boolean;
        vm["matched"]      = v.matched;
        vm["raw"]          = QString::fromStdString(v.raw);
        vm["timestamp_ms"] = toTimestampMs(v.timestamp);
        QMetaObject::invokeMethod(this, [this, cardId, vm]() {
            queueCardValueUpdate(cardId, vm);
        }, Qt::QueuedConnection);
    });
}

void CardBridge::queueCardValueUpdate(int cardId, QVariantMap value) {
    pendingValueUpdates_.insert(cardId, value);
    if (!valueFlushTimer_.isActive())
        valueFlushTimer_.start();
}

void CardBridge::flushPendingCardValueUpdates() {
    if (pendingValueUpdates_.isEmpty())
        return;

    const auto updates = pendingValueUpdates_;
    pendingValueUpdates_.clear();

    for (auto it = updates.cbegin(); it != updates.cend(); ++it)
        emit cardValueUpdated(it.key(), it.value());
}

int CardBridge::nextCardId() const {
    int maxId = 0;
    for (const auto &e : cards_)
        if (e.id > maxId)
            maxId = e.id;
    return maxId + 1;
}
