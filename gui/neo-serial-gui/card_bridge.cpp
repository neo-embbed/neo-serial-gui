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
        if (p.isObject()) {
            const QJsonObject obj = p.toObject();
            names << obj.value("name").toString(
                defaultPresetName(obj.value("slot").toInt(names.size() + 1)));
        }
    }
    return names;
}

QVariantList CardBridge::presetSlots() const {
    QVariantList result;
    for (int slot = 1; slot <= kPresetSlotCount; ++slot)
        result.append(presetSlot(slot));
    return result;
}

int CardBridge::currentPresetSlot() const {
    return currentPresetSlot_;
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
    setCurrentPresetSlot(current.value("preset_slot").toInt(-1));
    cardsFromJson(current.value("cards").toArray());

    presets_ = root.value("presets").toArray();
    normalizePresets();
    emit presetsChanged();

    return true;
}

bool CardBridge::saveToFile(const QString &path) {
    normalizePresets();

    QJsonObject current;
    current["name"]        = currentName_;
    current["cards"]       = cardsToJson();
    current["preset_slot"] = currentPresetSlot_;

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
    entry.kind      = QStringLiteral("monitor");
    entry.id        = nextCardId();
    entry.card      = std::make_unique<neo::ParameterCard>(cfg);
    entry.createdAt = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);

    wireCallback(entry);
    cards_.push_back(std::move(entry));
    emit cardsChanged();
    return cards_.back().id;
}

int CardBridge::addControlCard(const QString &name, const QString &sendText,
                               const QString &color) {
    CardEntry entry;
    entry.kind      = QStringLiteral("control");
    entry.id        = nextCardId();
    entry.sendText  = sendText;
    entry.createdAt = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);

    neo::CardConfig cfg;
    cfg.name    = name.toStdString();
    cfg.pattern = "";
    cfg.type    = neo::CardType::Numeric;
    cfg.unit    = "";
    cfg.color   = color.isEmpty() ? std::string("#0e7a68") : color.toStdString();
    cfg.enabled = true;
    entry.card  = std::make_unique<neo::ParameterCard>(cfg);

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
    if (props.contains("kind"))
        entry.kind = props["kind"].toString();

    if (entry.kind == QStringLiteral("control")) {
        neo::CardConfig cfg = entry.card ? entry.card->config() : neo::CardConfig{};
        if (props.contains("name"))    cfg.name    = props["name"].toString().toStdString();
        if (props.contains("color"))   cfg.color   = props["color"].toString().toStdString();
        if (props.contains("enabled")) cfg.enabled = props["enabled"].toBool();
        if (props.contains("send_text")) entry.sendText = props["send_text"].toString();

        if (!entry.card)
            entry.card = std::make_unique<neo::ParameterCard>(cfg);
        else
            entry.card->updateConfig(cfg);

        emit cardsChanged();
        return;
    }

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
    vm["kind"]       = entry.kind;
    vm["name"]       = QString::fromStdString(cfg.name);
    vm["pattern"]    = QString::fromStdString(cfg.pattern);
    vm["type"]       = (cfg.type == neo::CardType::Boolean) ? "boolean" : "numeric";
    vm["unit"]       = QString::fromStdString(cfg.unit);
    vm["color"]      = QString::fromStdString(cfg.color);
    vm["enabled"]    = cfg.enabled;
    vm["send_text"]  = entry.sendText;
    vm["created_at"] = entry.createdAt;
    return vm;
}

// ---- Presets -------------------------------------------------------------

void CardBridge::savePreset(const QString &name) {
    for (int slot = 1; slot <= kPresetSlotCount; ++slot) {
        const QVariantMap info = presetSlot(slot);
        if (info.value("name").toString() == name) {
            savePresetSlot(slot);
            return;
        }
    }

    const int slot = qBound(1, presets_.size() + 1, kPresetSlotCount);
    updatePresetSlotMeta(slot, name, QString());
    savePresetSlot(slot);
}

void CardBridge::loadPreset(const QString &name) {
    for (int slot = 1; slot <= kPresetSlotCount; ++slot) {
        const QVariantMap info = presetSlot(slot);
        if (info.value("name").toString() == name) {
            loadPresetSlot(slot);
            return;
        }
    }
}

void CardBridge::deletePreset(const QString &name) {
    for (int slot = 1; slot <= kPresetSlotCount; ++slot) {
        const QVariantMap info = presetSlot(slot);
        if (info.value("name").toString() != name)
            continue;

        const int index = presetSlotToIndex(slot);
        if (index < 0)
            return;

        QJsonObject preset = normalizedPresetObject(presets_.at(index).toObject(), slot);
        preset["cards"] = QJsonArray();
        preset["saved_at"] = QString();
        presets_[index] = preset;
        if (currentPresetSlot_ == slot)
            setCurrentPresetSlot(-1);
        emit presetsChanged();
        return;
    }
}

QVariantMap CardBridge::presetSlot(int slot) const {
    QVariantMap vm;
    const int index = presetSlotToIndex(slot);
    if (index < 0)
        return vm;

    const QJsonObject preset = (index < presets_.size() && presets_.at(index).isObject())
        ? normalizedPresetObject(presets_.at(index).toObject(), slot)
        : normalizedPresetObject(QJsonObject(), slot);
    const QJsonArray cards = preset.value("cards").toArray();

    vm["slot"] = slot;
    vm["name"] = preset.value("name").toString(defaultPresetName(slot));
    vm["note"] = preset.value("note").toString();
    vm["saved_at"] = preset.value("saved_at").toString();
    vm["hasCards"] = !cards.isEmpty() || !preset.value("saved_at").toString().isEmpty();
    vm["isCurrent"] = (currentPresetSlot_ == slot);
    vm["layout"] = preset.value("layout").toObject().toVariantMap();
    return vm;
}

bool CardBridge::savePresetSlot(int slot, const QVariantMap &layout) {
    normalizePresets();
    const int index = presetSlotToIndex(slot);
    if (index < 0)
        return false;

    QJsonObject preset = normalizedPresetObject(presets_.at(index).toObject(), slot);
    preset["cards"] = cardsToJson();
    preset["layout"] = QJsonObject::fromVariantMap(layout);
    preset["saved_at"] = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
    presets_[index] = preset;

    setCurrentName(preset.value("name").toString(defaultPresetName(slot)));
    setCurrentPresetSlot(slot);
    emit presetsChanged();
    return true;
}

bool CardBridge::loadPresetSlot(int slot) {
    const int index = presetSlotToIndex(slot);
    if (index < 0)
        return false;

    const QJsonObject preset = normalizedPresetObject(presets_.at(index).toObject(), slot);
    const QString savedAt = preset.value("saved_at").toString();
    const QJsonArray cards = preset.value("cards").toArray();
    if (savedAt.isEmpty() && cards.isEmpty()
        && preset.value("layout").toObject().isEmpty())
        return false;

    setCurrentName(preset.value("name").toString(defaultPresetName(slot)));
    setCurrentPresetSlot(slot);
    cardsFromJson(cards);
    return true;
}

bool CardBridge::updatePresetSlotMeta(int slot, const QString &name,
                                      const QString &note) {
    normalizePresets();
    const int index = presetSlotToIndex(slot);
    if (index < 0)
        return false;

    QJsonObject preset = normalizedPresetObject(presets_.at(index).toObject(), slot);
    const QString trimmedName = name.trimmed();
    preset["name"] = trimmedName.isEmpty() ? defaultPresetName(slot) : trimmedName;
    preset["note"] = note.trimmed();
    presets_[index] = preset;

    if (currentPresetSlot_ == slot)
        setCurrentName(preset.value("name").toString(defaultPresetName(slot)));
    emit presetsChanged();
    return true;
}

// ---- Feed ----------------------------------------------------------------

void CardBridge::feed(const QString &line) {
    std::string str = line.toStdString();
    for (auto &entry : cards_) {
        if (entry.kind != QStringLiteral("monitor") || !entry.card)
            continue;
        entry.card->feed(str);
    }
}

// ---- Card values for QML -------------------------------------------------

QVariantMap CardBridge::cardValue(int index) const {
    QVariantMap vm;
    if (index < 0 || index >= static_cast<int>(cards_.size()))
        return vm;

    const auto &entry = cards_[index];
    if (entry.kind != QStringLiteral("monitor") || !entry.card)
        return vm;
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
    if (cards_[index].kind != QStringLiteral("monitor") || !cards_[index].card)
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
    if (cards_[index].kind != QStringLiteral("monitor") || !cards_[index].card)
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
    obj["kind"]       = entry.kind;
    obj["name"]       = QString::fromStdString(cfg.name);
    obj["pattern"]    = QString::fromStdString(cfg.pattern);
    obj["type"]       = (cfg.type == neo::CardType::Boolean) ? "boolean" : "numeric";
    obj["enabled"]    = cfg.enabled;
    obj["unit"]       = QString::fromStdString(cfg.unit);
    obj["color"]      = QString::fromStdString(cfg.color);
    obj["send_text"]  = entry.sendText;
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
        entry.kind      = obj.value("kind").toString(QStringLiteral("monitor"));
        entry.id        = obj.value("id").toInt();
        entry.sendText  = obj.value("send_text").toString();
        entry.createdAt = obj.value("created_at").toString();
        entry.card      = std::make_unique<neo::ParameterCard>(configFromJson(obj));

        if (entry.kind == QStringLiteral("monitor"))
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

void CardBridge::setCurrentPresetSlot(int slot) {
    const int normalized = (slot >= 1 && slot <= kPresetSlotCount) ? slot : -1;
    if (currentPresetSlot_ == normalized)
        return;
    currentPresetSlot_ = normalized;
    emit currentPresetSlotChanged();
    emit presetsChanged();
}

int CardBridge::presetSlotToIndex(int slot) {
    if (slot < 1 || slot > kPresetSlotCount)
        return -1;
    return slot - 1;
}

QString CardBridge::defaultPresetName(int slot) {
    return QString::number(slot);
}

QJsonObject CardBridge::normalizedPresetObject(const QJsonObject &obj, int slot) const {
    QJsonObject preset = obj;
    preset["slot"] = slot;
    if (!preset.contains("name") || preset.value("name").toString().trimmed().isEmpty())
        preset["name"] = defaultPresetName(slot);
    if (!preset.contains("note"))
        preset["note"] = QString();
    if (!preset.contains("saved_at"))
        preset["saved_at"] = QString();
    if (!preset.contains("cards") || !preset.value("cards").isArray())
        preset["cards"] = QJsonArray();
    if (!preset.contains("layout") || !preset.value("layout").isObject())
        preset["layout"] = QJsonObject();
    return preset;
}

void CardBridge::normalizePresets() {
    QJsonArray normalized;
    if (presets_.size() == kPresetSlotCount) {
        for (int i = 0; i < kPresetSlotCount; ++i)
            normalized.append(normalizedPresetObject(presets_.at(i).toObject(), i + 1));
        presets_ = normalized;
        return;
    }

    for (int i = 0; i < kPresetSlotCount; ++i) {
        const int slot = i + 1;
        QJsonObject preset;
        if (i < presets_.size() && presets_.at(i).isObject()) {
            const QJsonObject legacy = presets_.at(i).toObject();
            preset = normalizedPresetObject(legacy, slot);
            if ((!legacy.contains("slot")) && legacy.contains("name")
                && !legacy.value("name").toString().trimmed().isEmpty()) {
                preset["name"] = legacy.value("name").toString();
            }
        }
        normalized.append(normalizedPresetObject(preset, slot));
    }
    presets_ = normalized;
}

int CardBridge::nextCardId() const {
    int maxId = 0;
    for (const auto &e : cards_)
        if (e.id > maxId)
            maxId = e.id;
    return maxId + 1;
}
