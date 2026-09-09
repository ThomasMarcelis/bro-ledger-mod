// Campaign-owned inert definitions. Built-in templates remain outside this flag.
::BroLedger.LibraryFlag <- "BroLedger.Library";
::BroLedger.LibraryLimit <- 32;
::BroLedger.ShareLimit <- 48000;
::BroLedger.WeaponTags <- ["Shield","Spear","Sword","Hammer","Axe","Mace","Flail","Cleaver","Whip","Dagger","Polearm","Bow","Crossbow","Throwing","Handgonne","Net","Two-handed","Light armour","Heavy armour"];
::BroLedger.PlaystyleTags <- ["Frontline","Backline","Tank","Damage","Control","Support","Hybrid","Duelist","Ranged","Mobile"];

::BroLedger.validUTF8 <- function(value)
{
    for(local i=0;i<value.len();i++) {
        local c=value[i]&255;if(c<128) continue;
        local count=c>=194 && c<=223 ? 1 : c>=224 && c<=239 ? 2 : c>=240 && c<=244 ? 3 : -1;
        if(count<0 || i+count>=value.len()) return false;
        local next=value[i+1]&255;
        if((c==224 && next<160)||(c==237 && next>=160)||(c==240 && next<144)||(c==244 && next>=144)) return false;
        for(local j=0;j<count;j++) {i++;if((value[i]&255)<128 || (value[i]&255)>191) return false;}
    }
    return true;
};
::BroLedger.plainName <- function(value, limit)
{
    if (!this.validString(value,limit) || !this.validUTF8(value)) return false;
    local visible=false;foreach(raw in value) {local c=raw&255;if(c<32 || c==127) return false;if(c!=32) visible=true;}
    return visible;
};
::BroLedger.validID <- function(value)
{
    if(!this.validString(value,40)) return false;
    foreach(c in value) if(!((c>=97 && c<=122)||(c>=48 && c<=57)||c==95||c==45)) return false;
    return true;
};
::BroLedger.communityTargets <- function(values)
{
    if(typeof values!="table" || values.len()>8) return false;
    foreach(k,v in values) if(this.Stats.find(k)==null || !this.number(v) || v<0 || v>500 ||
        v!=::Math.round(v*100)/100.0) return false;
    return true;
};
::BroLedger.validBuild <- function(b, defs=null)
{
    if(typeof b!="table" || b.len()!=("weights" in b ? 9 : 8)) return false;
    foreach(k in ["id","label","targets","preferred","route","flex","weaponTags","playstyleTags"]) if(!(k in b)) return false;
    if(!this.validID(b.id) || !this.plainName(b.label,40) || !this.communityTargets(b.targets) ||
        !this.communityTargets(b.preferred) || b.targets.len()!=b.preferred.len() ||
        !this.uniqueStrings(b.route,11) || !this.uniqueStrings(b.flex,11) ||
        !this.uniqueStrings(b.weaponTags,this.WeaponTags.len()) || !this.uniqueStrings(b.playstyleTags,this.PlaystyleTags.len())) return false;
    foreach(k,v in b.targets) if(!(k in b.preferred) || b.preferred[k]<v) return false;
    if("weights" in b) {
        if(typeof b.weights!="table" || b.weights.len()!=8) return false;
        foreach(k in this.Stats) if(!(k in b.weights) || typeof b.weights[k]!="integer" || b.weights[k]<0 || b.weights[k]>10) return false;
    }
    foreach(id in b.flex) if(b.route.find(id)==null) return false;
    if(b.route.len()>(b.route.find("perk.student")!=null ? 11 : 10)) return false;
    if(b.route.len()==11 && b.route[10]=="perk.student") return false; // The refund cannot fund Student itself.
    foreach(i,id in b.route) {
        if(!this.validString(id,80) || id.len()<6 || id.slice(0,5)!="perk.") return false;
        if(defs!=null && (!(id in defs) || defs[id].unlock>i)) return false;
    }
    foreach(tag in b.weaponTags) if(this.WeaponTags.find(tag)==null) return false;
    foreach(tag in b.playstyleTags) if(this.PlaystyleTags.find(tag)==null) return false;
    return true;
};
::BroLedger.buildWeights <- function(build)
{
    if("weights" in build) return this.copy(build.weights);
    local out={};foreach(k in this.Stats) out[k]<-1;return out;
};
::BroLedger.statWeight <- function(weights, key) {return weights==null ? 1 : weights[key];};
::BroLedger.findBuild <- function(id, builds)
{
    foreach(b in builds) if(b.id==id) return b;
    return null;
};
::BroLedger.newBuildID <- function(builds)
{
    for(local i=1;i<=this.LibraryLimit*2+1;i++) if(this.findBuild("user_"+i,builds)==null) return "user_"+i;
    throw "Library is full.";
};
// BL2 adds one integer weight after each Minimum/Ideal pair. BL1 stays readable.
::BroLedger.encodeBuilds <- function(builds, defs=null)
{
    if(typeof builds!="array" || builds.len()>this.LibraryLimit) throw "At most 32 builds are supported.";
    local out="BL2|",seen={};
    local put=function(value){local s=value.tostring();out+=s.len()+":"+s;};
    put(builds.len());
    foreach(b in builds) {
        if(!this.validBuild(b,defs) || b.id in seen) throw "Invalid build, duplicate ID, or illegal perk order.";
        seen[b.id]<-true;put(b.id);put(b.label);
        local weights=this.buildWeights(b);
        foreach(k in this.Stats) {put(k in b.targets ? b.targets[k] : "");put(k in b.preferred ? b.preferred[k] : "");put(weights[k]);}
        foreach(values in [b.route,b.flex,b.weaponTags,b.playstyleTags]) {put(values.len());foreach(v in values) put(v);}
    }
    if(out.len()>this.ShareLimit) throw "Share text exceeds 48,000 bytes.";
    return out;
};
// Only explicit import supplies importInfo; saved-library reads remain strict.
::BroLedger.decodeBuilds <- function(source, defs=null, importInfo=null)
{
    if(typeof source!="string" || source.len()>this.ShareLimit || source.len()<4 || ["BL1|","BL2|"].find(source.slice(0,4))==null)
        throw "Unsupported share version or size. Expected BL1 or BL2 text (up to 48,000 bytes).";
    local at=4,weighted=source.slice(0,4)=="BL2|";
    local integer=function(s,limit) {
        if(s.len()==0 || s.len()>5) throw "Invalid count.";
        local n=0;foreach(c in s) {if(c<48 || c>57) throw "Invalid count.";n=n*10+c-48;if(n>limit) throw "Count exceeds limit.";}return n;
    };
    local take=function() {
        local start=at;while(at<source.len() && source[at]!=58 && at-start<6) at++;
        if(at>=source.len() || source[at]!=58) throw "Invalid text length.";
        local length=integer(source.slice(start,at),800);at++;
        if(at+length>source.len()) throw "Truncated share text.";
        local s=source.slice(at,at+length);at+=length;return s;
    };
    local numeric=function(s) {
        local dot=false,digits=0;
        if(s.len()>6) throw "Target exceeds limit.";
        foreach(c in s) {
            if(c==46 && !dot) {dot=true;continue;}
            if(c<48 || c>57) throw "Invalid target.";
            digits++;
        }
        if(digits==0) throw "Invalid target.";
        return dot ? s.tofloat() : s.tointeger();
    };
    local count=integer(take(),this.LibraryLimit),out=[];
    for(local i=0;i<count;i++) {
        local b={id=take(),label=take(),targets={},preferred={},route=[],flex=[],weaponTags=[],playstyleTags=[]};
        if(weighted) b.weights<-{};
        foreach(k in this.Stats) {
            local m=take(),ideal=take();
            if(m!="") b.targets[k]<-numeric(m);
            if(ideal!="") b.preferred[k]<-numeric(ideal);
            if(weighted) b.weights[k]<-integer(take(),10);
        }
        foreach(values in [b.route,b.flex,b.weaponTags,b.playstyleTags]) {
            local n=integer(take(),20);for(local j=0;j<n;j++) values.push(take());
        }
        out.push(b);
    }
    if(at!=source.len() && importInfo==null) {
        // Strict-reader diagnostics from the Squirrel input.
        // Adler-32 high:low decimal halves stay below 65521 on the game's 32-bit VM.
        local a=1,b=0,next="";
        foreach(c in source) {a=(a+(c&255))%65521;b=(b+a)%65521;}
        for(local i=at;i>=0 && i<source.len() && i-at<4;i++)
            next=next+(next=="" ? "" : ",")+(source[i]&255);
        throw "Trailing share data. Diagnostic 0.4.3-d1: consumed "+at+"/"+source.len()+
            " bytes; decoded "+out.len()+"/"+count+" builds; next "+(next=="" ? "none" : next)+
            "; adler32 "+b+":"+a+".";
    }
    this.encodeBuilds(out,defs); // Same shape, semantic and aggregate limits as the editor.
    if(importInfo!=null) importInfo.ignoredExtra<-at!=source.len();
    return out;
};
::BroLedger.readLibrary <- function(flags, defs)
{
    local raw=flags.has(this.LibraryFlag) ? flags.get(this.LibraryFlag) : null;
    if(raw==null && !flags.has(this.LibraryFlag)) return {builds=[],issue=null,token=null};
    try {return {builds=this.decodeBuilds(raw,defs),issue=null,token=raw};}
    catch(e) {return {builds=[],issue="Library unavailable; saved bytes retained. "+e,token=raw};}
};
::BroLedger.writeLibrary <- function(flags, builds, defs)
{
    if(this.readLibrary(flags,defs).issue!=null) throw "Unsupported or damaged library retained; import into another campaign.";
    local encoded=this.encodeBuilds(builds,defs);
    // Native tag_collection stores one string value; serialize/validate before the sole owning mutation.
    flags.set(this.LibraryFlag,encoded);
    return encoded;
};
::BroLedger.mergeBuilds <- function(existing, incoming, policy, defs)
{
    this.encodeBuilds(existing,defs);this.encodeBuilds(incoming,defs);
    if(["reject","skip","copy"].find(policy)==null) throw "Choose a duplicate policy.";
    local out=this.copy(existing);
    foreach(source in incoming) {
        local duplicate=false;
        foreach(b in out) if(b.id==source.id || b.label.tolower()==source.label.tolower()) duplicate=true;
        if(duplicate && policy=="reject") throw "Duplicate ID or name. Choose Skip duplicates or Import copies.";
        if(duplicate && policy=="skip") continue;
        local b=this.copy(source);
        if(duplicate) {
            b.id=this.newBuildID(out);local length=::Math.min(b.label.len(),28);
            while(!this.validUTF8(b.label.slice(0,length))) length--;
            local prefix=b.label.slice(0,length);
            for(local n=1;n<=out.len()+1;n++) {
                b.label=prefix+" (copy "+n+")";local used=false;
                foreach(existingBuild in out) if(existingBuild.label.tolower()==b.label.tolower()) used=true;
                if(!used) break;
            }
        }
        out.push(b);
    }
    this.encodeBuilds(out,defs);return out;
};
