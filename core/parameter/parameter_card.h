#ifndef NEO_CORE_PARAMETER_CARD_H
#define NEO_CORE_PARAMETER_CARD_H

#include <chrono>
#include <cstdint>
#include <deque>
#include <functional>
#include <mutex>
#include <regex>
#include <string>
#include <vector>

namespace neo {

// ---- Card type -----------------------------------------------------------

enum class CardType { Numeric, Boolean };

// ---- Card configuration (serialisable, no runtime state) -----------------

struct CardConfig {
    std::string name;
    std::string pattern;                  // regex (numeric) or "regex; true=v; false=v" (boolean)
    CardType    type    = CardType::Numeric;
    std::string unit;                     // e.g. "degC" – only meaningful for Numeric
    std::string color;                    // hex, e.g. "#0e7a68"
    bool        enabled = true;
};

// ---- A single matched value (stored in history) --------------------------

struct CardValue {
    uint64_t                              id        = 0;
    std::chrono::system_clock::time_point timestamp;
    double                                numeric   = 0.0;   // Numeric cards
    bool                                  boolean   = false;  // Boolean cards
    bool                                  matched   = false;  // true if raw value resolved to a known mapping
    std::string                           raw;                // raw captured string
};

using CardValueCallback = std::function<void(const CardValue&)>;

// ---- ParameterCard -------------------------------------------------------
//
// One card = one regex rule + rolling history, thread-safe.
//
// Usage:
//   ParameterCard card(config);
//   card.onValueChanged([](const CardValue& v){ ... });
//   card.feed("T1=25.3");  // returns true if matched
//
// Boolean pattern format (from legacy):
//   "<regex>; true=ON|YES; false=OFF|NO"
//   If true=/false= omitted, defaults apply:
//     TRUE  <- ON, TRUE, 1, YES
//     FALSE <- OFF, FALSE, 0, NO
// --------------------------------------------------------------------------

class ParameterCard {
public:
    explicit ParameterCard(const CardConfig& config);
    ~ParameterCard();

    ParameterCard(const ParameterCard&)            = delete;
    ParameterCard& operator=(const ParameterCard&) = delete;

    // Feed a line of serial data. Returns true if a match was found.
    bool feed(const std::string& line);

    // Configuration
    const CardConfig& config() const;
    void updateConfig(const CardConfig& config);

    // Current value
    CardValue currentValue() const;
    bool      hasValue()     const;

    // History (same pagination pattern as Session::getMessages)
    std::vector<CardValue> getHistory(uint64_t after_id = 0,
                                      std::size_t limit = 200) const;
    void clearHistory();

    // Callback – fires on every new matched value
    void onValueChanged(CardValueCallback cb);

    static constexpr std::size_t kMaxHistory = 5000;

private:
    void compilePattern();
    bool feedNumeric(const std::string& line);
    bool feedBoolean(const std::string& line);
    void appendValue(CardValue val);

    static std::vector<std::string> splitValues(const std::string& s);
    static std::string              toUpper(const std::string& s);

    CardConfig  config_;
    std::regex  regex_;
    bool        regex_valid_ = false;

    // Boolean true/false value mappings (upper-cased for comparison)
    std::vector<std::string> true_values_;
    std::vector<std::string> false_values_;

    mutable std::mutex      data_mutex_;
    std::deque<CardValue>   history_;
    uint64_t                next_id_   = 1;
    CardValue               current_{};
    bool                    has_value_ = false;

    mutable std::mutex      cb_mutex_;
    CardValueCallback       value_cb_;
};

} // namespace neo

#endif // NEO_CORE_PARAMETER_CARD_H
