local B = ::BroLedger;
function check(value, message) { if (!value) throw message; }
function rejects(fn) { try { fn(); } catch (e) { return true; } return false; }
function same(a,b) {
    if (typeof a!=typeof b) return false;
    if (typeof a=="table" || typeof a=="array") {
        if (a.len()!=b.len()) return false;
        foreach(k,v in a) if (!(k in b) || !same(v,b[k])) return false;
        return true;
    }
    return a==b;
}

function fixture()
{
    local s = {stats={}, rawStats={}, initiativeLoss=0, stars={}, ranges={}, scale={}, horizon=11, normalRows=10, veteranRows=0, giftRows=0, growthKnown=true,
        perks={}, notes=[], warnings=[], level=1, pending=0, free=1, spent=0, futurePerks=9};
    foreach (k in B.Stats)
    {
        s.stats[k] <- 0; s.stars[k] <- 0; s.ranges[k] <- [2,4]; s.scale[k] <- 1.0;
    }
    s.rawStats=s.stats;
    s.ranges.matk = [1,3]; s.ranges.mdef = [1,3];
    return s;
}

function calibratedBro(build, preferred=true)
{
    local s=fixture();s.normalRows=0;s.level<-11;s.free=10;s.futurePerks=0;
    foreach(k,v in build.targets) s.stats[k]=v;
    if(preferred) foreach(k,v in build.preferred) s.stats[k]=v;
    // Gifted is already spent: tests must not borrow an unearned fourth/future row.
    s.perks["perk.gifted"]<-true;s.spent=1;s.free=9;
    return s;
}

function actorFixture()
{
    ::Const <- {Attributes={Hitpoints=0,Bravery=1,Fatigue=2,Initiative=3,MeleeSkill=4,RangedSkill=5,MeleeDefense=6,RangedDefense=7},
        AttributesLevelUp=[{Min=2,Max=4},{Min=2,Max=4},{Min=2,Max=4},{Min=3,Max=5},{Min=1,Max=3},{Min=2,Max=4},{Min=1,Max=3},{Min=2,Max=4}],
        SkillType={Perk=1,Trait=2,PermanentInjury=4,StatusEffect=8},XP={MaxLevelWithPerkpoints=11}};
    local a={m={},level=3,pending=2,free=2,spent=0,talents=[0,0,0,0,0,0,0,0],skills=[],
        origin="scenario.tutorial",background="background.militia",
        natural={Hitpoints=60,Bravery=40,Stamina=100,Initiative=100,MeleeSkill=55,RangedSkill=40,MeleeDefense=5,RangedDefense=0},
        current={FatigueRecoveryRate=15,FatigueRecoveryRateMult=1.0},capacity=60,fatigue=17};
    a.getBaseProperties <- function(){return this.natural;};
    a.getCurrentProperties <- function(){return this.current;};
    a.getTalents <- function(){return this.talents;};
    a.getSkills <- function(){local list=this.skills;return {query=function(mask,hidden){if(!hidden) throw "hidden perks omitted";return list;}};};
    a.getLevel <- function(){return this.level;};a.getLevelUps <- function(){return this.pending;};
    a.getPerkPoints <- function(){return this.free;};a.getPerkPointsSpent <- function(){return this.spent;};
    a.getBackground <- function(){return {getID=@() a.background};};
    ::World <- {State={},Assets={getOrigin=@() {getID=@() a.origin}}};
    a.getHitpointsMax <- @() 75;a.getFatigueMax <- function(){return this.capacity;};
    a.getFatigue <- function(){return this.fatigue;};a.getInitiative <- @() 60;
    a.getAttributeLevelUpValues <- function(){throw "roll getter called";};
    a.fillAttributeLevelUpValues <- function(...){throw "roll generation called";};
    return a;
}
function skill(id,type) {return {getID=@() id,getType=@() type};}

// Historical owned shape, independent of the current plan writer.
function oldPlan(build)
{
    return {schema=2, revision=2, enabled=true, build=build.id, label=build.label,
        route=B.copy(build.route), targets=B.copy(build.targets), priority=B.copy(build.priority),
        preferredTargets=B.copy(build.preferred), armour=build.armour, swaps=[], options=B.copy(build.swaps),
        weapons=build.weapons, patterns=B.copy(build.patterns)};
}
