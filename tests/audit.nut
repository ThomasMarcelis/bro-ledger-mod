local B=::BroLedger,cases={};
cases.observer_forwards_commands_and_detects_gameplay_changes <- function() {
    local actor=actorFixture(),slots=array(6,null),bag=[null],logs=[],hooks={},queued=null;
    ::Const.ItemSlot <- {Head=0,Body=1,Mainhand=2,Offhand=3,Ammo=4,Accessory=5};
    ::Const.BodyPart <- {Head=0,Body=1};
    actor.getID<-@() 7;actor.getName<-@() "Audit fixture";actor.getHitpoints<-@() 60;
    actor.getActionPoints<-@() 9;actor.getArmor<-@(part) part==0?100:200;
    local items={getItemAtSlot=@(slot) slots[slot],getUnlockedBagSlots=@() bag.len(),getItemAtBagSlot=@(slot) bag[slot]};
    actor.getItems<-@() items;
    B.ownedActor=@(id) id==7?actor:null;
    local randomCalls=0,commandCalls=0,operation=function(){},result={accepted=true},screen={};
    ::Math.rand<-function(min,max){randomCalls++;return min+1;};
    ::logInfo<-function(message){logs.push(message);};
    ::Hooks<-{register=function(...) {
        return {require=function(...){},queue=function(order,fn){queued=fn;},hook=function(path,fn){hooks[path]<-fn;}};
    }};
    B.command=function(received,data) {
        check(this==B && received==screen,"observer changed command receiver or screen");
        commandCalls++;operation();return result;
    };
    dofile("tests/runtime_audit.nut");
    check(queued!=null,"observer startup not queued");queued();
    local request={actor=7,action="evaluate"};
    check(B.command(screen,request)==result && commandCalls==1,"observer blocked or replaced command result");
    check(logs.len()==1 && logs[0].find("sameFacts=true mutators=0 rng=0")!=null,"ordinary command changed gameplay");
    check(B.command(screen,{actor=8,action="evaluate"})==result && logs.len()==1,"unowned actor was audited");
    check(B.command(screen,{actor=7})==result && logs.len()==1,"observer blocked malformed-request validation");

    local q={setHitpoints=function(){},setFatigue=function(value){this.fatigue=value;return value;},
        setActionPoints=function(){},setCurrentProperties=function(){}};
    local setFatigue=q.setFatigue;hooks["scripts/entity/tactical/actor"](q);
    actor.setFatigue<-q.setFatigue(setFatigue);
    operation=function(){check(actor.setFatigue(23)==23 && ::Math.rand(2,9)==3,"observer changed native return values");};
    B.command(screen,request);
    check(logs.top().find("sameFacts=false mutators=1 rng=1")!=null && randomCalls==1,"mutation or RNG went undetected");
    check(!B.Audit.active,"audit remained active after success");
    actor.setFatigue(24);::Math.rand(2,9);
    check(B.Audit.calls==1 && B.Audit.rng==1 && randomCalls==2,"observer counted unrelated gameplay");

    local first={getInstanceID=@() "first",getCondition=@() 40,getStaminaModifier=@() -10};
    local second={getInstanceID=@() "second",getCondition=@() 40,getStaminaModifier=@() -10};
    slots[2]=first;bag[0]=second;
    operation=function(){slots[2]=second;bag[0]=first;};
    B.command(screen,request);
    check(logs.top().find("sameFacts=false mutators=0 rng=0")!=null,"equipped/bag item exchange went undetected");
    local count=logs.len();operation=function(){throw "command failure";};
    local error=null;try {B.command(screen,request);}catch(e){error=e;}
    check(error=="command failure" && !B.Audit.active && logs.len()==count,"exception was swallowed or audit state leaked");
};
return cases;
