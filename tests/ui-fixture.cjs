// Native control boundary double. Layout is measured separately with production/native browser fixtures.
const {Controller} = require('../ui/mods/bro_ledger/ledger.js');
function fixture(count=14, plan=null, issue=null) {
    const calls=[],notices=[],nodes=[];
    class Node {
        constructor(markup='') {
            this.classes=new Set((/class="([^"]*)"/.exec(markup)||['',''])[1].split(' '));
            this.children=[];this.handlers={};this.attributes={};this.props={};this.value='';this[0]=this;this.length=1;nodes.push(this);
        }
        addClass(s){s.split(' ').forEach(c=>this.classes.add(c));return this;}
        removeClass(s){s.split(' ').forEach(c=>this.classes.delete(c));return this;}
        toggleClass(s,v){return v?this.addClass(s):this.removeClass(s);}
        text(s){if(s===undefined)return this.value;this.value=s;return this;}
        val(s){return this.text(s===undefined?undefined:String(s));}
        prop(k,v){if(v===undefined)return this.props[k];this.props[k]=v;return this;}
        attr(k,v){if(v===undefined)return this.attributes[k];this.attributes[k]=v;return this;}
        appendTo(p){p.append(this);return this;}
        prependTo(p){p.children.unshift(this);this.parent=p;return this;}
        append(c){this.children.push(c);c.parent=this;return this;}
        empty(){this.children=[];return this;}
        remove(){if(this.parent)this.parent.children=this.parent.children.filter(c=>c!==this);return this;}
        hide(){this.hidden=true;return this;}
        show(){this.hidden=false;return this;}
        toggle(v){this.hidden=!v;return this;}
        on(e,fn){e.split(' ').forEach(name=>this.handlers[name]=fn);return this;}
        off(e,fn){if(this.handlers[e]===fn)delete this.handlers[e];return this;}
        css(k,v){this.styles=this.styles||{};this.styles[k]=v;return this;}
        outerHeight(){return 0;}innerHeight(){return 0;}offset(){return {top:0};}
        scrollTop(v){if(v===undefined)return this.scrollPosition||0;this.scrollPosition=v;return this;}
        iCheck(action){if(action==='destroy'){this.destroyed=true;return this;}this.skinned=true;return this;}
        find(selector){const out=[];const visit=n=>n.children.forEach(c=>{if(c.classes.has(selector.slice(1)))out.push(c);visit(c);});visit(this);return collection(out);}
        trigger(e,data){if(e==='hide-tooltip')this.pendingTooltip=false;
            if(e==='update')this.updates=(this.updates||0)+1;
            if(e==='scroll'&&this.listViewport&&data)this.listViewport.scrollTop(data.top);
            if(this.handlers[e])this.handlers[e](data||{});return this;}
        bindTooltip(data){this.tooltip=data;this.pendingTooltip=true;return this;}
        unbindTooltip(){this.tooltip=null;return this;}
        createList(delta,classes){const list=new Node().addClass(classes).appendTo(this);
            list.listViewport=new Node().appendTo(list);list.listContent=new Node().appendTo(list.listViewport);return list;}
        findListScrollContainer(){return this.listContent;}
        aciScrollBar(action){if(action!=='container')throw Error('Unexpected scrollbar action');return this.listViewport;}
        destroyList(){this.listDestroyed=true;return this;}
        enableButton(v){this.disabled=!v;return this;}
        createTextButton(label,action){return new Node().text(label).on('click',action).appendTo(this);}
        changeButtonText(label){this.text(label);return null;}
        createPopupDialog(){const p=new Node().appendTo(this);p.content=new Node().appendTo(p);p.buttons={};
            p.findPopupDialogContentContainer=()=>p.content;
            p.addPopupDialogButton=(label,cls,fn,disabled)=>{p.buttons[cls]=new Node().text(label).on('click',fn).enableButton(!disabled).appendTo(p);return p;};
            p.addPopupDialogCancelButton=fn=>p.addPopupDialogButton('Cancel','l-cancel-button',fn);
            p.findPopupDialogOkButton=()=>p.buttons['l-ok-button'];p.destroyPopupDialog=()=>p.remove();return p;}
        focus(){this.focused=true;return this;}select(){this.selected=true;this.selectionStart=0;this.selectionEnd=this.value.length;}
    }
    function collection(items){return {items,length:items.length,each(fn){items.forEach(n=>fn.call(n));return this;},
        filter(fn){return collection(items.filter(n=>fn.call(n)));},removeClass(s){items.forEach(n=>n.removeClass(s));return this;},
        addClass(s){items.forEach(n=>n.addClass(s));return this;},remove(){items.forEach(n=>n.remove());return this;}};}
    global.$=v=>typeof v==='string'?new Node(v):v;global.Path={GFX:'coui://gfx/'};
    global.window=new Node();
    global.SQ={call(handle,method,request,callback){calls.push({request,callback});}};
    const owner=new Controller({mContainer:new Node(),mSQHandle:'fixture',mDataSource:{notifyBackendPopupDialogIsVisible:v=>notices.push(v)}});
    owner.visible=true;owner.actor=7;owner.render=()=>{};
    const build=i=>({id:'user_'+i,label:'Build '+i,targets:{hp:60},preferred:{hp:80},route:['perk.colossus','perk.gifted'],flex:['perk.gifted'],
        weaponTags:['Shield','Hammer','Axe','Mace','Flail'],playstyleTags:['Tank','Frontline']});
    const data={actor:7,epoch:42,revision:0,title:'Planner',name:'Brother',settings:{Enabled:true},plan,issue,libraryIssue:null,
        defs:{'perk.colossus':{name:'Colossus',unlock:0,row:0,column:0},'perk.gifted':{name:'Gifted',unlock:1,row:1,column:0},'perk.student':{name:'Student',unlock:0,row:0,column:1}},
        starters:[],library:Array.from({length:count},(_,i)=>build(i+1)),newBuildID:'user_33',weaponTags:['Shield','Hammer','Axe','Mace','Flail','Bow'],playstyleTags:['Tank','Frontline','Ranged'],
        stars:{},builds:[]};
    data.builds=data.library.map((b,i)=>({...b,source:'library',score:100-i,order:b.route,projection:{horizon:11},jointState:'possible',statRows:[],
        route:{remaining:b.route,acquired:[],blocked:[],offplan:[],unknown:[],conflicts:[],feasible:true}}));
    owner.data=data;owner.compare(data);
    function all(){const out=[];const visit=n=>{out.push(n);n.children.forEach(visit);};visit(owner.popup);return out;}
    return {owner,data,calls,notices,nodes,all,window:global.window,byClass:cls=>all().filter(n=>n.classes.has(cls)),
        button:label=>all().find(n=>n.value===label&&n.handlers.click),
        reply(extra={}){const c=calls.at(-1);c.callback({...data,seq:c.request.seq,...extra});}};
}
function click(node){if(!node||!node.handlers.click)throw Error('Missing clickable control');node.handlers.click();}
module.exports={fixture,click};
