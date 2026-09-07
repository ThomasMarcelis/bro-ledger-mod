::BroLedger.bands <- function(snapshot, targets, preferred, legal)
{
    local minimum = this.feasibility(snapshot, targets, "mean");
    local high = this.feasibility(snapshot, targets, "high");
    local ideal = preferred == null ? {known = false, feasible = false, shortfalls = []} :
        this.feasibility(snapshot, preferred, "mean");
    local middle = this.copy(preferred == null ? targets : preferred);
    if (preferred != null) foreach (key, value in targets) middle[key] <- (value + preferred[key]) / 2.0;
    local strong = this.feasibility(snapshot, middle, "mean"), grade = "?";
    if (minimum.known && ideal.known && snapshot.spent >= snapshot.perks.len())
    {
        if (!high.feasible) grade = high.shortfalls.len() >= 2 ? "F" : "D";
        else if (!minimum.feasible) grade = "C";
        else if (ideal.feasible) grade = "S";
        else grade = strong.feasible ? "A" : "B";
        if (!legal && this.Grades.find(grade) > 1) grade = "D";
    }
    return {grade = grade,
        seed = ideal.feasible ? preferred : strong.feasible ? middle : targets,
        seedMode = minimum.feasible ? "mean" : "high"};
};

::BroLedger.statRows <- function(stats, projection, targets, preferred)
{
    local rows = [];
    foreach (key in this.Stats)
    {
        local now = key in stats && this.number(stats[key]) ? stats[key] : null;
        local expected = key in projection.stats ? projection.stats[key] : null;
        local row = {key = key, now = now, expected = expected, minimum = key in targets ? targets[key] : null,
            ideal = preferred != null && key in preferred ? preferred[key] : null};
        row.minimumState <- row.minimum == null ? "none" : now == null ? "unknown" : now >= row.minimum ? "met" : "grow";
        row.idealState <- preferred == null ? "unknown" : row.ideal == null ? "none" : now == null ? "unknown" : now >= row.ideal ? "met" : "grow";
        row.expectedShortfall <- expected != null && row.minimum != null && expected < row.minimum;
        rows.push(row);
    }
    return rows;
};

::BroLedger.assess <- function(snapshot, plan, preferred, legal)
{
    local potential = this.bands(snapshot, plan.targets, preferred, legal), current = this.copy(snapshot);
    current.normalRows = 0;
    current.veteranRows = 0;
    current.giftRows = 0;
    current.growthKnown = true;
    local now = this.bands(current, plan.targets, preferred, legal);
    local projection = this.project(snapshot, plan, preferred, potential);
    return {grade = potential.grade, nowGrade = now.grade,
        projection = projection, statRows = this.statRows(snapshot.stats, projection, plan.targets, preferred)};
};

::BroLedger.evaluate <- function(snapshot, build, defs)
{
    local plan = this.candidatePlan(build, snapshot), adjustments = [];
    foreach (index, id in plan.route)
        if (id != build.route[index]) adjustments.push({replace = build.route[index], with = id});
    local invested = 0;
    foreach (id in build.identity)
    {
        local resolved = plan.route[build.route.find(id)];
        if (resolved in snapshot.perks) invested++;
    }
    snapshot = this.forPlan(snapshot, plan);
    local route = this.route(plan, snapshot, defs);
    local assessment = this.assess(snapshot, plan, build.preferred, route.feasible);
    assessment.id <- build.id;
    assessment.label <- build.label;
    assessment.route <- route;
    assessment.note <- build.note;
    assessment.fallback <- build.stopgap;
    assessment.role <- build.role;
    assessment.weaponTags <- this.copy(build.weaponTags);
    assessment.masteryNote <- build.masteryNote;
    assessment.adjustments <- adjustments;
    assessment.niche <- build.niche;
    assessment.invested <- invested * 1.0 / build.identity.len();
    return assessment;
};

::BroLedger.compare <- function(snapshot, defs)
{
    local builds = [], eligible = {};
    foreach (build in this.Builds)
    {
        local entry = this.evaluate(snapshot, build, defs);
        entry.weapons <- build.weapons;
        builds.push(entry);
        if (!entry.fallback && entry.route.feasible && ["B", "A", "S"].find(entry.grade) != null)
            eligible[build.id] <- entry;
    }
    local investment = -1.0, quality = -1, primary = [];
    foreach (id, entry in eligible)
    {
        local grade = this.Grades.find(entry.grade);
        if (entry.invested > investment || (entry.invested == investment && grade > quality))
        {
            primary = [];
            investment = entry.invested;
            quality = grade;
        }
        if (entry.invested == investment && grade == quality) primary.push(id);
    }
    primary.sort();
    foreach (entry in builds)
    {
        entry.preferred <- primary.find(entry.id) != null;
        entry.alternative <- entry.id in eligible && !entry.preferred;
    }
    builds.sort(function(a, b) {
        local first = ::BroLedger.Grades.find(a.grade), second = ::BroLedger.Grades.find(b.grade);
        first = first == null ? -1 : first;
        second = second == null ? -1 : second;
        if (first != second) return second <=> first;
        if (a.fallback != b.fallback) return a.fallback ? 1 : -1;
        if (a.preferred != b.preferred) return a.preferred ? -1 : 1;
        return a.id <=> b.id;
    });
    return {builds = builds, primary = primary, recommended = primary.len() == 1 ? primary[0] : null};
};
