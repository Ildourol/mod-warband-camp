// Standalone test suite exercising the Warband Camp phase allocation logic.
#include <cstdint>
#include <cmath>
#include <iostream>
#include <vector>

using uint8 = std::uint8_t;
using uint32 = std::uint32_t;

constexpr float CAMP_RADIUS = 40.0f;
constexpr float CAMP_MIN_SEPARATION = 150.0f;
constexpr float PHASE_REUSE_RADIUS = 600.0f;
constexpr uint8 CAMP_PHASE_BIT_MIN = 1;
constexpr uint8 CAMP_PHASE_BIT_MAX = 31;

struct Camp
{
    uint32 accountId = 0;
    uint32 map = 0;
    float x = 0.0f, y = 0.0f, z = 0.0f, o = 0.0f;
    uint8 phaseBit = 0;
    uint32 zoneId = 0;
};

std::vector<Camp> g_camps;

float Dist2D(float ax, float ay, float bx, float by)
{
    float const dx = ax - bx;
    float const dy = ay - by;
    return std::sqrt(dx * dx + dy * dy);
}

uint8 PickPhaseBit(uint32 map, float x, float y)
{
    uint32 used = 0;
    for (Camp const& c : g_camps)
    {
        if (c.map != map)
            continue;
        if (Dist2D(c.x, c.y, x, y) > PHASE_REUSE_RADIUS)
            continue;
        used |= (1u << c.phaseBit);
    }

    for (uint8 bit = CAMP_PHASE_BIT_MIN; bit <= CAMP_PHASE_BIT_MAX; ++bit)
        if (!(used & (1u << bit)))
            return bit;

    return 0;   // 31 camps within 600 yards; caller refuses the claim
}

static int failures = 0;
static void check(bool ok, char const* what)
{
    std::cout << (ok ? "PASS  " : "FAIL  ") << what << std::endl;
    if (!ok) ++failures;
}

static void addCamp(uint32 map, float x, float y, uint8 bit)
{
    Camp c;
    c.map = map;
    c.x = x;
    c.y = y;
    c.phaseBit = bit;
    g_camps.push_back(c);
}

int main()
{
    check(PickPhaseBit(0, 0, 0) == CAMP_PHASE_BIT_MIN, "empty realm gives bit 1");

    // --- the reuse-radius boundary, one neighbour, measured exactly ---
    addCamp(0, 0.0f, 0.0f, 1);
    check(PickPhaseBit(0, PHASE_REUSE_RADIUS - 1.0f, 0.0f) == 2,
          "just INSIDE reuse radius: must not share the neighbour bit");
    check(PickPhaseBit(0, PHASE_REUSE_RADIUS + 1.0f, 0.0f) == 1,
          "just OUTSIDE reuse radius: reuses bit 1 - spatial reuse verified");
    g_camps.clear();

    // --- 31 co-located camps exhaust the pool; the 32nd must be REFUSED ---
    for (uint8 b = CAMP_PHASE_BIT_MIN; b <= CAMP_PHASE_BIT_MAX; ++b)
        addCamp(0, float(b) * 10.0f, 0.0f, b);
    check(g_camps.size() == 31, "31 co-located camps placed");
    check(PickPhaseBit(0, 0, 0) == 0, "32nd co-located camp refused, not wedged");

    // A point beyond the reuse radius of EVERY one of those 31 is free again.
    check(PickPhaseBit(0, 310.0f + PHASE_REUSE_RADIUS + 1.0f, 0.0f) == CAMP_PHASE_BIT_MIN,
          "clear of the whole cluster: bit 1 free again");
    check(PickPhaseBit(1, 0, 0) == CAMP_PHASE_BIT_MIN, "a different map is its own world");

    // --- invariants that must hold or the bitmask maths is undefined ---
    uint8 const b = PickPhaseBit(1, 0, 0);
    check(b >= 1 && b <= 31, "bit always in 1..31, so 1u<<bit is never UB");
    check(CAMP_MIN_SEPARATION > 2.0f * CAMP_RADIUS,
          "min separation > two bubbles: no player is ever inside two camps");
    check(PHASE_REUSE_RADIUS > 250.0f + CAMP_RADIUS,
          "reuse radius clears MAX_VISIBILITY_DISTANCE + bubble");

    std::cout << std::endl
              << (failures ? "TESTS FAILED" : "ALL TESTS PASSED")
              << " (" << failures << " failures)" << std::endl;
    return failures ? 1 : 0;
}
