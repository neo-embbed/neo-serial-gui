// parameter_card_tester.cpp
// Tests ParameterCard feed() with simulated serial lines (no hardware needed).
//
// Build (MinGW example, from project root):
//   g++ -std=c++17 -I. tester/parameter_card_tester.cpp core/parameter/parameter_card.cpp -o tester/parameter_card_tester.exe

#include "../core/parameter/parameter_card.h"
#include <iostream>
#include <iomanip>
#include <string>
#include <vector>
#include <cassert>

// ── Helpers ─────────────────────────────────────────────────────────────────

static int g_pass = 0;
static int g_fail = 0;

static void check(bool cond, const char* desc) {
    if (cond) {
        std::cout << "  [PASS] " << desc << std::endl;
        ++g_pass;
    } else {
        std::cout << "  [FAIL] " << desc << std::endl;
        ++g_fail;
    }
}

// ── Test 1: Numeric card basic matching ─────────────────────────────────────

static void test_numeric_basic() {
    std::cout << "\n== Test: Numeric basic ==" << std::endl;

    neo::CardConfig cfg;
    cfg.name    = "Temperature";
    cfg.pattern = "temp=([-+]?[0-9]+\\.?[0-9]*)";
    cfg.type    = neo::CardType::Numeric;
    cfg.unit    = "degC";
    cfg.color   = "#ff0000";

    neo::ParameterCard card(cfg);

    // Callback counter
    int cb_count = 0;
    neo::CardValue last_cb_val{};
    card.onValueChanged([&](const neo::CardValue& v) {
        ++cb_count;
        last_cb_val = v;
    });

    // Should not match
    bool hit = card.feed("voltage=3.3V");
    check(!hit, "Non-matching line returns false");
    check(!card.hasValue(), "No value after non-match");

    // Should match
    hit = card.feed("temp=25.3 humidity=60");
    check(hit, "Matching line returns true");
    check(card.hasValue(), "hasValue() is true after match");

    auto val = card.currentValue();
    check(val.matched, "matched flag is true");
    check(val.raw == "25.3", "raw == \"25.3\"");
    check(std::abs(val.numeric - 25.3) < 0.001, "numeric == 25.3");
    check(cb_count == 1, "Callback fired once");

    // Second match
    card.feed("temp=-10.5 ok");
    val = card.currentValue();
    check(std::abs(val.numeric - (-10.5)) < 0.001, "numeric == -10.5 (negative)");
    check(cb_count == 2, "Callback fired twice total");

    // History
    auto hist = card.getHistory();
    check(hist.size() == 2, "History has 2 entries");
    check(hist[0].id < hist[1].id, "IDs are increasing");
}

// ── Test 2: Numeric card – whole match (no capture group) ───────────────────

static void test_numeric_whole_match() {
    std::cout << "\n== Test: Numeric whole match ==" << std::endl;

    neo::CardConfig cfg;
    cfg.name    = "Plain number";
    cfg.pattern = "[0-9]+\\.?[0-9]*";
    cfg.type    = neo::CardType::Numeric;

    neo::ParameterCard card(cfg);

    card.feed("value is 42.0 end");
    check(card.hasValue(), "Matched without capture group");
    check(std::abs(card.currentValue().numeric - 42.0) < 0.001, "numeric == 42.0");
}

// ── Test 3: Boolean card with default mappings ──────────────────────────────

static void test_boolean_default() {
    std::cout << "\n== Test: Boolean default mappings ==" << std::endl;

    neo::CardConfig cfg;
    cfg.name    = "Motor";
    cfg.pattern = "motor=(\\w+)";
    cfg.type    = neo::CardType::Boolean;

    neo::ParameterCard card(cfg);

    card.feed("motor=ON");
    auto v = card.currentValue();
    check(v.matched, "ON matched as true");
    check(v.boolean == true, "boolean == true");

    card.feed("motor=off");
    v = card.currentValue();
    check(v.matched, "off matched (case-insensitive)");
    check(v.boolean == false, "boolean == false");

    card.feed("motor=1");
    v = card.currentValue();
    check(v.matched && v.boolean == true, "1 -> true");

    card.feed("motor=0");
    v = card.currentValue();
    check(v.matched && v.boolean == false, "0 -> false");

    card.feed("motor=UNKNOWN");
    v = card.currentValue();
    check(!v.matched, "UNKNOWN -> not matched");
}

// ── Test 4: Boolean card with custom mappings ───────────────────────────────

static void test_boolean_custom() {
    std::cout << "\n== Test: Boolean custom mappings ==" << std::endl;

    neo::CardConfig cfg;
    cfg.name    = "Pump";
    cfg.pattern = "pump=(\\w+); true=RUN|ACTIVE; false=STOP|IDLE";
    cfg.type    = neo::CardType::Boolean;

    neo::ParameterCard card(cfg);

    card.feed("pump=RUN");
    check(card.currentValue().matched && card.currentValue().boolean == true, "RUN -> true");

    card.feed("pump=active");
    check(card.currentValue().matched && card.currentValue().boolean == true, "active -> true (case-insensitive)");

    card.feed("pump=STOP");
    check(card.currentValue().matched && card.currentValue().boolean == false, "STOP -> false");

    card.feed("pump=idle");
    check(card.currentValue().matched && card.currentValue().boolean == false, "idle -> false");

    // Default ON should NOT match since custom mappings override defaults
    card.feed("pump=ON");
    check(!card.currentValue().matched, "ON not in custom mappings -> not matched");
}

// ── Test 5: Disabled card ───────────────────────────────────────────────────

static void test_disabled() {
    std::cout << "\n== Test: Disabled card ==" << std::endl;

    neo::CardConfig cfg;
    cfg.name    = "Disabled";
    cfg.pattern = "x=(\\d+)";
    cfg.type    = neo::CardType::Numeric;
    cfg.enabled = false;

    neo::ParameterCard card(cfg);

    bool hit = card.feed("x=100");
    check(!hit, "Disabled card does not match");
    check(!card.hasValue(), "No value stored");
}

// ── Test 6: Invalid regex ───────────────────────────────────────────────────

static void test_invalid_regex() {
    std::cout << "\n== Test: Invalid regex ==" << std::endl;

    neo::CardConfig cfg;
    cfg.name    = "Bad";
    cfg.pattern = "[invalid(";
    cfg.type    = neo::CardType::Numeric;

    neo::ParameterCard card(cfg);

    bool hit = card.feed("anything");
    check(!hit, "Invalid regex does not crash, returns false");
}

// ── Test 7: History pagination ──────────────────────────────────────────────

static void test_history_pagination() {
    std::cout << "\n== Test: History pagination ==" << std::endl;

    neo::CardConfig cfg;
    cfg.name    = "Counter";
    cfg.pattern = "v=(\\d+)";
    cfg.type    = neo::CardType::Numeric;

    neo::ParameterCard card(cfg);

    for (int i = 1; i <= 10; ++i)
        card.feed("v=" + std::to_string(i));

    auto all = card.getHistory(0, 200);
    check(all.size() == 10, "All 10 values in history");

    auto page = card.getHistory(all[4].id, 3);
    check(page.size() == 3, "Pagination: 3 entries after id=5");
    check(std::abs(page[0].numeric - 6.0) < 0.001, "First in page is v=6");
}

// ── Test 8: clearHistory ────────────────────────────────────────────────────

static void test_clear_history() {
    std::cout << "\n== Test: clearHistory ==" << std::endl;

    neo::CardConfig cfg;
    cfg.name    = "Clear";
    cfg.pattern = "n=(\\d+)";
    cfg.type    = neo::CardType::Numeric;

    neo::ParameterCard card(cfg);

    card.feed("n=1");
    card.feed("n=2");
    check(card.hasValue(), "Has value before clear");

    card.clearHistory();
    check(!card.hasValue(), "hasValue() false after clear");
    check(card.getHistory().empty(), "History empty after clear");
}

// ── Test 9: Realistic multi-field serial line ───────────────────────────────

static void test_realistic_serial() {
    std::cout << "\n== Test: Realistic serial line ==" << std::endl;

    // Simulates: T21: ADC=0x1A3F, Volt=2.45V, Temp=23.75°C
    neo::CardConfig cfg;
    cfg.name    = "Cabin Temp";
    cfg.pattern = "Temp=([-+]?[0-9]+\\.[0-9]+)";
    cfg.type    = neo::CardType::Numeric;
    cfg.unit    = "degC";

    neo::ParameterCard card(cfg);

    std::vector<std::string> lines = {
        "T21: ADC=0x1A3F, Volt=2.45V, Temp=23.75C",
        "T21: ADC=0x1B00, Volt=2.51V, Temp=24.10C",
        "T22: ADC=0x0F20, Volt=1.80V, Temp=-5.30C",
        "SYSTEM: heartbeat ok",
        "T21: ADC=0x1C10, Volt=2.60V, Temp=25.00C",
    };

    int matched = 0;
    for (const auto& line : lines) {
        if (card.feed(line)) ++matched;
    }

    check(matched == 4, "4 out of 5 lines matched");
    check(std::abs(card.currentValue().numeric - 25.0) < 0.001, "Last value == 25.00");
}

// ── Test 10: Feed with Session integration (simulated) ──────────────────────

static void test_session_feed_flow() {
    std::cout << "\n== Test: Session + ParameterCard integration ==" << std::endl;

    // Simulate what CardBridge does: Session receives lines, feeds to cards
    neo::CardConfig cfg_temp;
    cfg_temp.name    = "Temp";
    cfg_temp.pattern = "temp=(\\d+\\.?\\d*)";
    cfg_temp.type    = neo::CardType::Numeric;

    neo::CardConfig cfg_motor;
    cfg_motor.name    = "Motor";
    cfg_motor.pattern = "motor=(\\w+)";
    cfg_motor.type    = neo::CardType::Boolean;

    neo::ParameterCard card_temp(cfg_temp);
    neo::ParameterCard card_motor(cfg_motor);

    // Simulated RX lines (as Session would receive)
    std::vector<std::string> rx_lines = {
        "temp=22.5 motor=ON",
        "temp=23.0 motor=ON",
        "temp=24.1 motor=OFF",
        "status=ok",
        "temp=25.0 motor=ON",
    };

    for (const auto& line : rx_lines) {
        card_temp.feed(line);
        card_motor.feed(line);
    }

    check(card_temp.getHistory().size() == 4, "Temp card: 4 matches");
    check(card_motor.getHistory().size() == 4, "Motor card: 4 matches");
    check(std::abs(card_temp.currentValue().numeric - 25.0) < 0.001, "Temp last = 25.0");
    check(card_motor.currentValue().boolean == true, "Motor last = ON (true)");
}

// ── Main ────────────────────────────────────────────────────────────────────

int main() {
    std::cout << "=== ParameterCard Feed Tester ===" << std::endl;

    test_numeric_basic();
    test_numeric_whole_match();
    test_boolean_default();
    test_boolean_custom();
    test_disabled();
    test_invalid_regex();
    test_history_pagination();
    test_clear_history();
    test_realistic_serial();
    test_session_feed_flow();

    std::cout << "\n=== Results: " << g_pass << " passed, " << g_fail << " failed ===" << std::endl;
    return g_fail > 0 ? 1 : 0;
}
