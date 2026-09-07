::BroLedger <- {
    ID = "mod_bro_ledger",
    Name = "Bro Build Planner",
    Version = "0.2.0",
    Revision = 3,
    Stats = ["hp", "resolve", "fatigue", "initiative", "matk", "ratk", "mdef", "rdef"],
    Grades = ["F", "D", "C", "B", "A", "S"]
};

::BroLedger.copy <- function(value)
{
    if (typeof value == "array")
    {
        local out = [];
        foreach (item in value) out.push(this.copy(item));
        return out;
    }
    if (typeof value == "table")
    {
        local out = {};
        foreach (key, item in value) out[key] <- this.copy(item);
        return out;
    }
    return value;
};

::BroLedger.number <- function(value)
{
    return (typeof value == "integer" || typeof value == "float") &&
        value == value && value > -1000000 && value < 1000000;
};

::BroLedger.gain <- function(snapshot, key, mode)
{
    local stars = snapshot.stars[key];
    if (stars == null) return null;
    local low = snapshot.ranges[key][0] + (stars == 3 ? 2 : stars);
    local high = snapshot.ranges[key][1] + (stars == 3 ? 1 : 0);
    return (mode == "low" ? low : mode == "high" ? high : (low + high) / 2.0) * snapshot.scale[key];
};

// Each attribute can use a row once; each ordinary, veteran or Gifted row supplies three picks.
::BroLedger.feasibility <- function(snapshot, targets, mode, witness = false)
{
    local normal = snapshot.normalRows, veteran = snapshot.veteranRows, gifted = snapshot.giftRows;
    local result = {known = snapshot.growthKnown, feasible = false, picks = {}, required = 0,
        capacity = 3 * (normal + veteran + gifted), shortfalls = []};
    local states = [{n = 0, v = 0, g = 0, picks = {}}];
    foreach (key in this.Stats)
    {
        if (!(key in targets)) continue;
        if (!(key in snapshot.stats) || !this.number(snapshot.stats[key]))
        {
            result.known = false;
            result.picks[key] <- null;
            continue;
        }
        local scale = snapshot.scale[key];
        local gain = normal > 0 ? this.gain(snapshot, key, mode) : scale;
        if (gain == null || gain <= 0 || scale <= 0)
        {
            result.known = false;
            result.picks[key] <- null;
            continue;
        }
        local gift = gifted > 0 ? snapshot.ranges[key][1] * scale : 0;
        local gap = targets[key] - snapshot.stats[key];
        local needed = gap <= 0 ? 0 : ::Math.ceil(gap / ::Math.maxf(gain, ::Math.maxf(scale, gift))).tointeger();
        result.picks[key] <- needed;
        result.required += needed;
        if (gap > normal * gain + veteran * scale + gifted * gift) result.shortfalls.push(key);

        local options = [];
        for (local gp = 0; gp <= gifted; gp++)
        {
            local lastVeteran = veteran + 1;
            for (local np = 0; np <= normal; np++)
            {
                local vp = ::Math.max(0, ::Math.ceil((gap - np * gain - gp * gift) / scale).tointeger());
                if (vp <= veteran && vp < lastVeteran)
                {
                    options.push([np, vp, gp]);
                    lastVeteran = vp;
                }
            }
        }
        local next = {};
        foreach (state in states) foreach (choice in options)
        {
            local n = state.n + choice[0], v = state.v + choice[1], g = state.g + choice[2];
            if (n > 3 * normal || v > 3 * veteran || g > 3 * gifted) continue;
            local id = (n * (3 * veteran + 1) + v) * (3 * gifted + 1) + g;
            if (id in next) continue;
            local picks = this.copy(state.picks);
            picks[key] <- witness ? this.copy(choice) : choice[0] + choice[1] + choice[2];
            next[id] <- {n = n, v = v, g = g, picks = picks};
        }
        // Stable witness selection, independent of Squirrel table iteration order.
        local ids = [];
        foreach (id, _ in next) ids.push(id);
        ids.sort();
        states = [];
        foreach (id in ids) states.push(next[id]);
    }
    if (result.known && states.len() > 0)
    {
        states.sort(function(a, b) {
            local total = (a.n + a.v + a.g) <=> (b.n + b.v + b.g);
            if (total != 0) return total;
            if (a.n != b.n) return a.n <=> b.n;
            if (a.v != b.v) return a.v <=> b.v;
            return a.g <=> b.g;
        });
        result.feasible = true;
        result.picks = states[0].picks;
        result.required = states[0].n + states[0].v + states[0].g;
    }
    return result;
};

::BroLedger.forPlan <- function(snapshot, plan)
{
    local out = this.copy(snapshot);
    out.giftRows = plan.route.find("perk.gifted") != null && !("perk.gifted" in snapshot.perks) &&
        snapshot.free >= 0 && snapshot.futurePerks >= 0 && snapshot.free + snapshot.futurePerks > 0 &&
        snapshot.spent >= snapshot.perks.len() ? 1 : 0;
    return out;
};

::BroLedger.project <- function(snapshot, plan, preferred, band)
{
    local out = {known = snapshot.growthKnown, stats = {}, allocation = {}, horizon = snapshot.horizon};
    local caps = [snapshot.normalRows, snapshot.veteranRows, snapshot.giftRows], used = [0, 0, 0], gains = {};
    local order = this.copy(plan.priority);
    foreach (key in this.Stats) if (order.find(key) == null) order.push(key);
    foreach (key in this.Stats)
    {
        local scale = snapshot.scale[key];
        local normal = caps[0] > 0 ? this.gain(snapshot, key, "mean") : 0;
        local gift = caps[2] > 0 ? snapshot.ranges[key][1] * scale : 0;
        if (!(key in snapshot.stats) || !this.number(snapshot.stats[key]) || normal == null ||
            !this.number(scale) || scale <= 0) out.known = false;
        out.allocation[key] <- [0, 0, 0];
        gains[key] <- [normal, scale, gift];
    }
    if (!out.known) return out;
    out.stats = this.copy(snapshot.stats);
    local seed = this.feasibility(snapshot, band.seed, band.seedMode, true);
    if (seed.known && seed.feasible) foreach (key, counts in seed.picks)
    {
        for (local i = 0; i < 3; i++)
        {
            out.allocation[key][i] = counts[i];
            used[i] += counts[i];
            out.stats[key] += counts[i] * gains[key][i];
        }
    }
    // Per-attribute counts <= rows and total counts <= three times rows admit a legal schedule.
    local goals = [plan.targets];
    if (preferred != null) goals.push(preferred);
    goals.push(null);
    foreach (goal in goals) foreach (key in order)
    {
        while (goal == null || (key in goal && out.stats[key] < goal[key]))
        {
            local best = null;
            for (local i = 0; i < 3; i++)
                if (used[i] < 3 * caps[i] && out.allocation[key][i] < caps[i] &&
                    (best == null || gains[key][i] > gains[key][best])) best = i;
            if (best == null) break;
            out.allocation[key][best]++;
            used[best]++;
            out.stats[key] += gains[key][best];
        }
    }
    return out;
};

::BroLedger.adviseOffer <- function(snapshot, plan, offer)
{
    foreach (key in this.Stats)
        if (!(key in offer) || !this.number(offer[key]) || offer[key] <= 0 ||
            !(key in snapshot.stats) || !this.number(snapshot.stats[key])) return null;
    snapshot = this.forPlan(snapshot, plan);
    local after = this.copy(snapshot);
    if (after.normalRows > 0) after.normalRows--;
    else if (after.veteranRows > 0) after.veteranRows--;
    local best = null, considered = 0, preferred = this.planPreferred(plan);
    for (local a = 0; a < 6; a++) for (local b = a + 1; b < 7; b++) for (local c = b + 1; c < 8; c++)
    {
        local picks = [this.Stats[a], this.Stats[b], this.Stats[c]];
        after.stats = this.copy(snapshot.stats);
        local progress = 0.0, idealProgress = 0.0, tie = 0;
        foreach (key in picks)
        {
            local delta = offer[key] * snapshot.scale[key];
            after.stats[key] += delta;
            if (key in plan.targets)
                progress += ::Math.minf(delta, ::Math.maxf(0.0, plan.targets[key] - snapshot.stats[key])) / (plan.targets[key] * 1.0);
            if (preferred != null && key in preferred)
                idealProgress += ::Math.minf(delta, ::Math.maxf(0.0, preferred[key] - snapshot.stats[key])) / (preferred[key] * 1.0);
            local priority = plan.priority.find(key);
            if (priority != null) tie += 1 << (8 - priority);
        }
        local minimum = this.feasibility(after, plan.targets, "mean");
        local ideal = preferred == null ? null : this.feasibility(after, preferred, "mean");
        local score = [
            minimum.known && !minimum.feasible ? 1 : 0,
            minimum.known ? minimum.shortfalls.len() : 0,
            minimum.known ? ::Math.max(0, minimum.required - minimum.capacity) : 0,
            -progress, ideal != null && ideal.known && !ideal.feasible ? 1 : 0, -idealProgress, -tie
        ];
        local wins = best == null;
        if (best != null)
            for (local i = 0; i < score.len(); i++)
                if (score[i] != best.score[i])
                {
                    wins = score[i] < best.score[i];
                    break;
                }
        if (wins) best = {picks = picks, score = score};
        considered++;
    }
    local goal = preferred == null ? "Minimum targets" : "Minimum first, then Ideal";
    return {picks = best.picks, considered = considered, reason = goal + (snapshot.growthKnown ?
        "; allows for remaining stat picks." : "; remaining row types are uncertain.")};
};
