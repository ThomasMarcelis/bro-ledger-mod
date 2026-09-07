local B=::BroLedger, cases={}, defs=dofile("tests/perk_unlocks.nut");

// Fixed synthetic role anchors, independent of the catalogue thresholds.
// Natural values at level 11; these are not sampled or observed brothers.
local excellent={
    forged_neutral_axe={hp=90,fatigue=110,resolve=50,matk=90,mdef=40},
    tempo_spear={hp=72,fatigue=100,resolve=45,matk=70,mdef=22},
    pure_bow={hp=85,fatigue=120,resolve=55,ratk=100},
    shield_tank_nimble={hp=100,fatigue=120,resolve=70,mdef=40,initiative=110},
    fencer={hp=80,fatigue=110,resolve=50,initiative=170,matk=95,mdef=35}
};
cases.independent_mature_role_anchors <- function() {
    foreach(id,values in excellent) {
        local b=B.findBuild(id),s=fixture();s.normalRows=0;s.futurePerks=0;s.free=0;s.spent=10;
        foreach(k,v in values) s.stats[k]=v;
        foreach(perk in b.route) s.perks[perk]<-true;
        check(B.evaluate(s,b,defs).grade=="S","independent mature anchor failed: "+id);
    }
};
cases.complete_catalog_routes <- function() {
    local seen={};
    foreach(b in B.Builds) {
        check(!(b.id in seen),"duplicate build");seen[b.id]<-true;
        local p=B.makePlan(b),s=fixture();
        check(B.validPlan(p) && p.route.len()==10,"invalid ten-point plan: "+b.id);
        check(B.evaluate(s,b,defs).route.feasible,"route cannot unlock: "+b.id);
    }
};

cases.minimum_midpoint_preferred_are_comparable <- function() {
    foreach(b in B.Builds)
    {
        local s=calibratedBro(b,false);
        s.perks.clear();foreach(id in b.route) s.perks[id]<-true;s.spent=10;s.free=0;
        check(B.evaluate(s,b,defs).grade=="B","minimum alone is not B: "+b.id);
        foreach(k,v in b.preferred) s.stats[k]=k in b.targets ? (b.targets[k]+v)/2.0 : v;
        check(B.evaluate(s,b,defs).grade=="A","halfway quality is not A: "+b.id);
    }
};

cases.strong_frontliner_progresses_1_7_11_with_gifted_student <- function() {
    local b=B.findBuild("forged_neutral_axe"),s=fixture();
    s.level<-1;s.stats={hp=60,fatigue=110,resolve=50,matk=60,mdef=7,ratk=30,rdef=0,initiative=100};
    s.stars.hp=2;s.stars.matk=2;s.stars.mdef=2;s.free=0;s.futurePerks=10;
    check(B.evaluate(s,b,defs).grade=="S","strong recruit must reach excellent joint targets");
    s.perks["perk.student"]<-true;s.spent=1;s.futurePerks=10;s.level=2;
    for(local row=1;row<=10;row++)
    {
        s.stats.hp+=4;s.stats.matk+=3;s.stats.mdef+=3;s.normalRows--;
        if(row==6)
        {
            s.level=7;s.perks["perk.gifted"]<-true;s.spent=2;s.free=4;s.futurePerks=5;
            s.stats.hp+=4;s.stats.matk+=3;s.stats.mdef+=3;
            check(B.evaluate(s,b,defs).grade=="S","level 7 allocated Gifted/Student caused a cliff");
        }
        if(row==10)
        {
            s.level=11;foreach(id in b.route) s.perks[id]<-true;s.spent=11;s.free=0;s.futurePerks=0;
            check(B.evaluate(s,b,defs).grade=="S","mature allocated plan lost S");
        }
    }
};

cases.stat_improvements_cannot_worsen_role_grade <- function() {
    foreach(b in B.Builds)
    {
        foreach(rows in [0,1,4]) foreach(offset in [-6,0,3])
        {
            local s=calibratedBro(b,false);s.normalRows=rows;
            s.perks.clear();foreach(id in b.route) s.perks[id]<-true;s.spent=10;s.free=0;
            foreach(k,v in b.targets) s.stats[k]+=offset;
            foreach(k in B.Stats)
            {
                local before=B.evaluate(s,b,defs).grade;s.stats[k]+=1;
                check(B.Grades.find(B.evaluate(s,b,defs).grade)>=B.Grades.find(before),"independent improvement worsened "+b.id+"/"+k);
                s.stats[k]-=1;
            }
        }
    }
};

cases.unknown_preferred_data_cannot_certify_excellence <- function() {
    local b=B.findBuild("nimble_2h_axe"),s=calibratedBro(b);
    s.stats.initiative=null;
    check(B.evaluate(s,b,defs).grade=="?","unknown supporting data certified grade");
};

cases.bow_accuracy_and_throwing_economy_have_real_minima <- function() {
    local pure=B.findBuild("nimble_thrower"),bow=B.findBuild("nimble_bow_thrower"),s=calibratedBro(pure);
    check(B.evaluate(s,pure,defs).grade=="S" && B.Grades.find(B.evaluate(s,bow,defs).grade)<=1,"close-range throwing accuracy certified long-range bow");
    s.stats.fatigue=60;
    check(B.Grades.find(B.evaluate(s,pure,defs).grade)<=1,"throwing cycle ignored Fatigue capacity");
};

cases.weapon_fit_can_differ_without_a_weapon_power_grade <- function() {
    local s=fixture();s.normalRows=0;s.futurePerks=0;s.free=10;
    s.stats={hp=100,fatigue=120,resolve=70,initiative=110,matk=70,ratk=0,mdef=40,rdef=0};
    check(B.evaluate(s,B.findBuild("tempo_spear"),defs).nowGrade=="S","spear accuracy entry fit lost");
    check(B.evaluate(s,B.findBuild("tempo_sword"),defs).nowGrade=="B","sword has its own minimum");
    check(B.evaluate(s,B.findBuild("shield_tank_nimble"),defs).nowGrade=="S","defensive tank needs no offensive mastery");
    check(B.evaluate(s,B.findBuild("spearwall"),defs).nowGrade=="D","S defensive tank falsely certified Spearwall accuracy");
};

cases.invested_identity_and_genuine_flexible_alternatives <- function() {
    local s=fixture();foreach(k in B.Stats) s.stats[k]=200;
    s.normalRows=0;s.perks["perk.gifted"]<-true;s.spent=1;s.free=9;s.futurePerks=0;
    local flexible=B.compare(s,defs);
    check(flexible.primary.len()>1 && flexible.recommended==null,"flexible brother assigned fake unique catalogue winner");
    s.perks["perk.mastery.bow"]<-true;s.spent=2;s.free=8;
    local invested=B.compare(s,defs);
    check(invested.primary.find("pure_bow")!=null && invested.primary.find("duelist_axe")==null,
        "invested Bow identity ignored or unrelated Axe preferred");
};

cases.stopgap_never_sets_the_primary_floor_and_order_is_not_evidence <- function() {
    local s=calibratedBro(B.findBuild("tempo_spear"),false);
    local c=B.compare(s,defs);
    check(c.primary.len()==0 && c.recommended==null,"stopgap certified endgame floor");
    s=fixture();foreach(k in B.Stats) s.stats[k]=200;
    local before=B.compare(s,defs),order=B.Builds;
    B.Builds=B.copy(order);B.Builds.reverse();local after=B.compare(s,defs);B.Builds=order;
    check(before.primary.len()==after.primary.len(),"catalogue order changed alternatives");
    foreach(id in before.primary) check(after.primary.find(id)!=null,"catalogue order chose winner");
};

cases.suitable_perk_consumption_and_mandatory_bottlenecks <- function() {
    foreach(b in B.Builds)
    {
        local s=calibratedBro(b);s.perks.clear();s.spent=0;s.free=10;
        for(local i=0;i<10;i++)
        {
            local next=B.evaluate(s,b,defs).route.next;
            check(next!=null && defs[next].unlock<=s.spent,"route advised an illegal tier");
            s.perks[next]<-true;s.spent++;s.free--;
            check(B.evaluate(s,b,defs).grade=="S","valid acquired default worsened excellent fit: "+b.id);
        }
        foreach(k,v in b.targets)
        {
            local saved=s.stats[k];s.stats[k]=v-1;
            check(B.Grades.find(B.evaluate(s,b,defs).grade)<=1,"missing mandatory "+k+" compensated in "+b.id);
            s.stats[k]=saved;
        }
    }
};

cases.initiative_stars_are_not_current_stats <- function() {
    local f=B.findBuild("fencer"),s=calibratedBro(f);s.stats.initiative=130;s.stars.initiative=3;
    check(B.Grades.find(B.evaluate(s,f,defs).grade)<=1,"mature stars manufactured Initiative without future levels");
};

cases.pathfinder_is_shared_support <- function() {
    local s=fixture();s.level<-2;s.normalRows=9;s.free=1;s.futurePerks=9;
    s.stats={hp=65,fatigue=110,resolve=45,initiative=110,matk=66,ratk=60,mdef=8,rdef=0};
    s.stars.matk=2;s.stars.ratk=2;s.stars.mdef=2;s.ranges.initiative=[3,5];
    local before=B.compare(s,defs);
    check(before.primary.len()>1,"shared support witness needs a real tie");
    s.perks["perk.pathfinder"]<-true;s.spent=1;s.free=0;
    local after=B.compare(s,defs);
    check(after.primary.len()==before.primary.len(),"Pathfinder alone replaced the S role tie");
    foreach(id in before.primary) check(after.primary.find(id)!=null,"shared support claimed a unique role");
    check(B.evaluate(s,B.findBuild("forged_neutral_axe"),defs).invested==0,"Pathfinder earned identity credit");
};

cases.preferred_only_goal_and_shortfall <- function() {
    local b=B.findBuild("nimble_2h_axe"),s=calibratedBro(b);
    s.perks.clear();foreach(id in b.route) s.perks[id]<-true;s.spent=10;s.free=0;s.stats.initiative=109;
    local e=B.evaluate(s,b,defs);
    local initiative=e.statRows[3];
    check(e.grade=="B","preferred-only target witness changed");
    check(initiative.key=="initiative" && initiative.ideal==110 && initiative.minimum==null,
        "preferred-only criterion absent from payload");
    check(initiative.idealState=="grow","decisive preferred shortfall absent from payload");
    initiative.ideal=0;check(b.preferred.initiative==110,"payload exposes mutable strategy targets");
};

cases.sort_stopgap_by_grade <- function() {
    local s=fixture();
    s.stats={hp=52,fatigue=92,resolve=45,initiative=105,matk=55,ratk=35,mdef=8,rdef=0};
    s.stars.hp=2;s.stars.mdef=3;s.ranges.initiative=[3,5];
    local result=B.compare(s,defs),last=6;
    check(result.builds.len()==B.Builds.len(),"comparison lost catalog entries");
    foreach(e in result.builds) {
        local grade=B.Grades.find(e.grade);grade=grade==null ? -1 : grade;
        check(grade<=last,"grade inversion: "+e.grade+" "+e.id);last=grade;
    }
    check(result.builds[0].fallback && ["S","A"].find(result.builds[0].grade)!=null,"A stopgap must precede B/C/D");
    check(!result.builds[0].preferred && result.primary.find("tempo_spear")==null && result.recommended!="tempo_spear",
        "display sorting made Stopgap an endgame recommendation");
    local again=B.compare(s,defs);foreach(i,e in result.builds)check(e.id==again.builds[i].id,"unstable ordering");
};

cases.now_ignores_talents_and_pending_growth <- function() {
    local b=B.findBuild("nimble_2h_axe"),s=fixture();
    s.stats={hp=68,fatigue=107,resolve=56,initiative=110,matk=64,ratk=40,mdef=12,rdef=0};
    local e=B.evaluate(s,b,defs);
    check(e.nowGrade=="F" && e.grade!="F","current shortfalls must remain distinct from growth");
    s.stars.matk=3;s.stars.mdef=3;
    check(B.evaluate(s,b,defs).nowGrade==e.nowGrade,"talents changed current fit");
    s.growthKnown=false;e=B.evaluate(s,b,defs);
    check(e.nowGrade=="F" && e.grade=="?" && !e.projection.known,"unknown growth erased known current fit");
};

cases.targets_distinguish_met_unmet_missing_and_unknown <- function() {
    local rows=B.statRows({hp=60,matk=69.99999}, {stats={hp=72,matk=70}}, {hp=60,matk=70},{hp=72,matk=80});
    check(rows.len()==8,"untargeted stats disappeared");
    check(rows[0].minimumState=="met" && rows[0].idealState=="grow","minimum/Ideal not independent");
    check(rows[4].minimumState=="grow","rounded value falsely reached target");
    check(rows[3].minimumState=="none" && rows[3].minimum==null,"no Initiative target invented");
    check(rows[4].expectedShortfall==false,"reachable projected minimum marked short");
    rows=B.statRows({}, {stats={}}, {hp=60},{hp=90});
    check(rows[0].minimum==60 && rows[0].ideal==90 && rows[0].minimumState=="unknown" && rows[0].idealState=="unknown","missing current stat erased known targets");
    rows=B.statRows({}, {stats={}}, {hp=60},null);
    check(rows[0].minimumState=="unknown" && rows[0].idealState=="unknown","unknown turned into zero or absent");
};

cases.no_growth_and_route_cap <- function() {
    local s=fixture(),b=B.findBuild("tempo_spear"),p=B.makePlan(b);
    s.stats=B.copy(b.preferred);
    foreach(k in B.Stats) if(!(k in s.stats)) s.stats[k]<-0;
    s.normalRows=0;s.giftRows<-0;
    local a=B.assess(s,p,b.preferred,true);
    check(a.grade=="S" && a.nowGrade=="S","no-growth grades differ");
    foreach(k in B.Stats) check(a.projection.stats[k]==s.stats[k],"no-growth forecast invented gains");
    a=B.assess(s,p,b.preferred,false);
    check(a.grade=="D" && a.nowGrade=="D","route cap not shared");
    a=B.assess(s,p,null,true);
    check(a.grade=="?" && a.nowGrade=="?" && a.statRows[0].idealState=="unknown","missing saved Ideals certified grade");
};
return cases;
