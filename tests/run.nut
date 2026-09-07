try
{
    ::Math <- {ceil=ceil, floor=floor, round=@(v) floor(v+0.5),
        max=@(a,b) a.tointeger()>b.tointeger()?a.tointeger():b.tointeger(),
        min=@(a,b) a.tointeger()<b.tointeger()?a.tointeger():b.tointeger(),
        maxf=@(a,b) a>b?a:b, minf=@(a,b) a<b?a:b};
    dofile("scripts/mods/bro_ledger/core.nut");
    foreach (file in ["catalog","plan","state","actor","equipment","fit","screen"])
        dofile("scripts/mods/bro_ledger/"+file+".nut");
    loadfile("scripts/!mods_preload/mod_bro_ledger.nut");
    loadfile("tests/runtime_audit.nut");
    dofile("tests/fixtures.nut");
    local count=0;
    foreach (file in ["catalog","growth","plan","fit","reader","equipment","state","screen"])
    {
        local cases=dofile("tests/"+file+".nut"), names=[];
        foreach (name, test in cases) names.push(name);
        names.sort();
        foreach (name in names)
        {
            local globals=clone getroottable(), api=clone ::BroLedger, math=clone ::Math;
            try { cases[name](); }
            catch (e) { throw file+"/"+name+": "+e; }
            local added=[];
            foreach (key, value in getroottable()) if (!(key in globals)) added.push(key);
            foreach (key in added) delete getroottable()[key];
            foreach (key, value in globals) getroottable()[key]=value;
            ::BroLedger.clear(); foreach (key, value in api) ::BroLedger[key]<-value;
            ::Math.clear(); foreach (key, value in math) ::Math[key]<-value;
            count++;
            print("PASS "+file+"/"+name+"\n");
        }
    }
    print("BRO_LEDGER_TESTS_PASSED "+count+"\n");
    return 0;
}
catch (e)
{
    print("FAIL "+e+"\n");
    return 1;
}
