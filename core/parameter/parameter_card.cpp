#include "parameter_card.h"

#include <algorithm>
#include <cctype>
#include <sstream>

namespace neo {

// ---- Default boolean mappings (from legacy spec) -------------------------

static const std::vector<std::string> kDefaultTrue  = {"ON", "TRUE", "1", "YES"};
static const std::vector<std::string> kDefaultFalse = {"OFF", "FALSE", "0", "NO"};

// ---- Construction --------------------------------------------------------

ParameterCard::ParameterCard(const CardConfig& config)
    : config_(config)
{
    compilePattern();
}

ParameterCard::~ParameterCard() = default;

// ---- Pattern compilation -------------------------------------------------
//
// Numeric:  pattern is a plain regex.
// Boolean:  "<regex>; true=ON|YES; false=OFF|NO"
//           Parts after the first ';' are optional mappings.

void ParameterCard::compilePattern() {
    regex_valid_ = false;
    true_values_.clear();
    false_values_.clear();

    std::string regex_str = config_.pattern;

    if (config_.type == CardType::Boolean) {
        // Split by ';'
        std::vector<std::string> parts;
        std::istringstream iss(config_.pattern);
        std::string part;
        while (std::getline(iss, part, ';')) {
            auto start = part.find_first_not_of(" \t");
            auto end   = part.find_last_not_of(" \t");
            if (start != std::string::npos)
                parts.push_back(part.substr(start, end - start + 1));
        }

        if (!parts.empty())
            regex_str = parts[0];

        for (std::size_t i = 1; i < parts.size(); ++i) {
            const auto& p = parts[i];
            // Case-insensitive prefix check
            std::string lower = p;
            std::transform(lower.begin(), lower.end(), lower.begin(),
                           [](unsigned char c){ return std::tolower(c); });

            if (lower.substr(0, 5) == "true=") {
                true_values_ = splitValues(p.substr(5));
            } else if (lower.substr(0, 6) == "false=") {
                false_values_ = splitValues(p.substr(6));
            }
        }

        if (true_values_.empty())  true_values_  = kDefaultTrue;
        if (false_values_.empty()) false_values_ = kDefaultFalse;
    }

    try {
        regex_ = std::regex(regex_str);
        regex_valid_ = true;
    } catch (const std::regex_error&) {
        regex_valid_ = false;
    }
}

// ---- Feed ----------------------------------------------------------------

bool ParameterCard::feed(const std::string& line) {
    if (!config_.enabled || !regex_valid_) return false;

    return (config_.type == CardType::Numeric)
        ? feedNumeric(line)
        : feedBoolean(line);
}

bool ParameterCard::feedNumeric(const std::string& line) {
    std::smatch match;
    if (!std::regex_search(line, match, regex_)) return false;

    // Capture group 1 if present, otherwise whole match
    std::string raw = (match.size() > 1) ? match[1].str() : match[0].str();

    double value = 0.0;
    try {
        value = std::stod(raw);
    } catch (...) {
        return false;   // not a valid number
    }

    CardValue cv;
    cv.timestamp = std::chrono::system_clock::now();
    cv.numeric   = value;
    cv.matched   = true;
    cv.raw       = raw;

    appendValue(std::move(cv));
    return true;
}

bool ParameterCard::feedBoolean(const std::string& line) {
    std::smatch match;
    if (!std::regex_search(line, match, regex_)) return false;

    std::string raw   = (match.size() > 1) ? match[1].str() : match[0].str();
    std::string upper = toUpper(raw);

    CardValue cv;
    cv.timestamp = std::chrono::system_clock::now();
    cv.raw       = raw;
    cv.matched   = false;

    for (const auto& v : true_values_) {
        if (toUpper(v) == upper) {
            cv.boolean = true;
            cv.matched = true;
            break;
        }
    }

    if (!cv.matched) {
        for (const auto& v : false_values_) {
            if (toUpper(v) == upper) {
                cv.boolean = false;
                cv.matched = true;
                break;
            }
        }
    }

    // Even if not matched to true/false, we still record it (legacy: show "不匹配")
    appendValue(std::move(cv));
    return true;
}

// ---- History storage (mirrors Session::appendMessage pattern) ------------

void ParameterCard::appendValue(CardValue val) {
    {
        std::lock_guard<std::mutex> lk(data_mutex_);
        val.id     = next_id_++;
        current_   = val;
        has_value_ = true;
        history_.push_back(val);

        while (history_.size() > kMaxHistory)
            history_.pop_front();
    }

    CardValueCallback cb;
    {
        std::lock_guard<std::mutex> lk(cb_mutex_);
        cb = value_cb_;
    }
    if (cb) cb(val);
}

// ---- Config access -------------------------------------------------------

const CardConfig& ParameterCard::config() const {
    return config_;
}

void ParameterCard::updateConfig(const CardConfig& config) {
    std::lock_guard<std::mutex> lk(data_mutex_);
    config_ = config;
    compilePattern();
}

// ---- Value access --------------------------------------------------------

CardValue ParameterCard::currentValue() const {
    std::lock_guard<std::mutex> lk(data_mutex_);
    return current_;
}

bool ParameterCard::hasValue() const {
    std::lock_guard<std::mutex> lk(data_mutex_);
    return has_value_;
}

// ---- History query (same pagination as Session::getMessages) -------------

std::vector<CardValue> ParameterCard::getHistory(uint64_t after_id,
                                                  std::size_t limit) const {
    std::lock_guard<std::mutex> lk(data_mutex_);
    std::vector<CardValue> result;
    result.reserve(std::min(limit, history_.size()));

    for (const auto& v : history_) {
        if (v.id <= after_id) continue;
        result.push_back(v);
        if (result.size() >= limit) break;
    }
    return result;
}

void ParameterCard::clearHistory() {
    std::lock_guard<std::mutex> lk(data_mutex_);
    history_.clear();
    next_id_   = 1;
    has_value_ = false;
    current_   = {};
}

// ---- Callback ------------------------------------------------------------

void ParameterCard::onValueChanged(CardValueCallback cb) {
    std::lock_guard<std::mutex> lk(cb_mutex_);
    value_cb_ = std::move(cb);
}

// ---- Helpers -------------------------------------------------------------

std::vector<std::string> ParameterCard::splitValues(const std::string& s) {
    std::vector<std::string> result;
    std::size_t pos = 0;

    while (pos < s.size()) {
        auto sep = s.find_first_of("|,", pos);
        std::string item;
        if (sep == std::string::npos) {
            item = s.substr(pos);
            pos  = s.size();
        } else {
            item = s.substr(pos, sep - pos);
            pos  = sep + 1;
        }
        auto start = item.find_first_not_of(" \t");
        auto end   = item.find_last_not_of(" \t");
        if (start != std::string::npos)
            result.push_back(item.substr(start, end - start + 1));
    }
    return result;
}

std::string ParameterCard::toUpper(const std::string& s) {
    std::string result = s;
    std::transform(result.begin(), result.end(), result.begin(),
                   [](unsigned char c) { return std::toupper(c); });
    return result;
}

} // namespace neo
