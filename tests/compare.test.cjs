const {test,afterEach}=require('node:test');
const assert=require('node:assert/strict');
const {fixture,click}=require('./ui-fixture.cjs');
const {matches}=require('../ui/mods/bro_ledger/ledger.js');
const original={SQ:global.SQ,$:global.$,Path:global.Path,document:global.document,window:global.window};
afterEach(()=>{for(const[k,v]of Object.entries(original)){if(v===undefined)delete global[k];else global[k]=v;}});
test('empty, one and many libraries expose real matches with ten per page and every remainder reachable',()=>{
    for(const count of [0,1,10,14,32,42]){
        const s=fixture(count),seen=[];
        assert.equal(s.button('Source: All'),undefined,'personal-only comparison offers a starter filter');
        do {seen.push(...s.byClass('bl-build-row').map(n=>n.attr('data-build')));const next=s.button('Next');if(!next)break;click(next);}while(true);
        assert.equal(seen.length,count);assert.equal(new Set(seen).size,count);assert.deepEqual(s.calls,[]);
    }
});
test('every membership matches and changing a filter clears a stale selection, including empty results',()=>{
    const s=fixture();for(const w of s.data.library[0].weaponTags)assert.equal(matches(s.data.builds[0],w,'Tank'),true);
    for(const p of ['Tank','Frontline'])assert.equal(matches(s.data.builds[0],'Mace',p),true);
    assert.equal(matches(s.data.builds[0],'Bow','Tank'),false);
    click(s.byClass('bl-build-row')[0]);const track=s.button('Track build');assert.equal(track.disabled,false);
    click(s.button('Weapon: All'));click(s.button('Bow'));
    assert.equal(s.byClass('bl-build-row').length,0);click(track);assert.deepEqual(s.calls,[]);
});
test('native filter buttons open, choose intersecting tags and reset without writing builds',()=>{
    const s=fixture(22),rows=()=>s.byClass('bl-build-row').map(n=>n.attr('data-build'));
    s.data.builds[0].weaponTags=['Bow'];s.data.builds[0].playstyleTags=['Ranged'];
    const before=JSON.stringify(s.data);
    click(s.button('Next'));click(s.byClass('bl-build-row')[0]);const track=s.button('Track build'),page=rows();
    click(s.button('Weapon: All'));assert.ok(s.button('Bow'));assert.equal(track.disabled,false);
    click(s.button('Playstyle: All'));assert.equal(s.button('Bow'),undefined);assert.ok(s.button('Tank'));
    click(s.button('Close'));assert.equal(s.button('Tank'),undefined);assert.deepEqual(rows(),page);assert.equal(track.disabled,false);
    click(s.button('Weapon: All'));click(s.button('Bow'));
    assert.deepEqual(rows(),['user_1']);assert.equal(s.button('All'),undefined);assert.equal(track.disabled,true);
    click(track);assert.deepEqual(s.calls,[]);
    click(s.button('Playstyle: All'));click(s.button('Tank'));assert.deepEqual(rows(),[]);
    click(s.button('Playstyle: Tank'));click(s.button('All'));assert.deepEqual(rows(),['user_1']);
    click(s.button('Weapon: Bow'));click(s.button('All'));
    assert.equal(rows().length,10);assert.equal(rows()[0],'user_1');assert.ok(s.button('Next'));assert.equal(s.button('Previous'),undefined);
    assert.deepEqual(s.calls,[]);assert.equal(JSON.stringify(s.data),before);
});
test('closed, replaced and stale filter controls cannot change the current comparison',()=>{
    for(const end of ['close','switch','actor','hidden','invalidate','replace','cancel']){
        const s=fixture(),opener=s.button('Weapon: All');click(opener);const bow=s.button('Bow');
        if(end==='close'){click(s.button('Close'));click(opener);}
        if(end==='switch')click(s.button('Playstyle: All'));
        if(end==='actor')s.owner.actor=8;if(end==='hidden')s.owner.visible=false;
        if(end==='invalidate')s.owner.invalidate();if(end==='replace')s.owner.compare(s.data);
        if(end==='cancel')click(s.button('Cancel'));
        const nodes=s.owner.popup?s.all():[],before=JSON.stringify(s.data);
        click(bow);
        if(!['close','switch'].includes(end))click(opener);
        assert.deepEqual(s.owner.popup?s.all():[],nodes,end);assert.deepEqual(s.calls,[],end);assert.equal(JSON.stringify(s.data),before,end);
    }
});
test('selection is deliberate; Cancel, actor switches, stale replies and repeated clicks cannot track',()=>{
    for(const end of ['cancel','actor','hidden','invalidate','replace']){
        const s=fixture();assert.equal(s.button('Track build').disabled,true);click(s.byClass('bl-build-row')[0]);const track=s.button('Track build');
        if(end==='cancel')click(s.button('Cancel'));if(end==='actor')s.owner.actor=8;if(end==='hidden')s.owner.visible=false;
        if(end==='invalidate')s.owner.invalidate();if(end==='replace')s.owner.compare(s.data);
        click(track);assert.deepEqual(s.calls,[],end);
    }
    const s=fixture();click(s.byClass('bl-build-row')[0]);const track=s.button('Track build');click(track);click(track);
    assert.equal(s.calls.length,1);assert.equal(s.calls[0].request.build,'user_1');assert.equal(s.calls[0].request.epoch,42);
});
test('unknown plan cannot be replaced; dormant re-enable sends only its explicit action',()=>{
    const blocked=fixture(1,null,'Unknown schema');click(blocked.byClass('bl-build-row')[0]);click(blocked.button('Track build'));assert.equal(blocked.calls.length,0);
    const s=fixture(1,{build:'retired',label:'Saved',enabled:false});click(s.button('Re-enable plan'));click(s.button('Re-enable plan'));
    assert.equal(s.calls.length,1);assert.equal(s.calls[0].request.action,'enabled');assert.equal(s.calls[0].request.enabled,true);
});
test('editor relays eight optional pairs, multiple tags, mandatory/flex route and order without writing the source',()=>{
    const s=fixture(1),before=JSON.stringify(s.data.library);s.owner.editor(s.data,s.data.library[0]);
    const inputs=s.all().filter(n=>n.attr('aria-label')&&/Minimum|Ideal/.test(n.attr('aria-label')));assert.equal(inputs.length,16);
    inputs.find(n=>n.attr('aria-label')==='Ranged defence Minimum').val('5');inputs.find(n=>n.attr('aria-label')==='Ranged defence Ideal').val('15');
    click(s.all().find(n=>n.attr('data-perk')==='perk.student'));click(s.button('Save build'));
    const r=s.calls[0].request;assert.equal(r.action,'saveBuild');assert.equal(r.create,false);assert.equal(r.definition.targets.rdef,5);
    assert.equal(r.definition.preferred.rdef,15);assert.deepEqual(r.definition.weaponTags,['Shield','Hammer','Axe','Mace','Flail']);
    assert.deepEqual(r.definition.flex,['perk.gifted']);assert.equal(r.definition.route.at(-1),'perk.student');assert.equal(JSON.stringify(s.data.library),before);
});
test('failed validation retains editor data and permits correction; stale editor callbacks cannot save',()=>{
    const s=fixture(0);click(s.button('Create build'));const name=s.byClass('bl-name-field')[0].children[0];name.val('<b>literal</b>');
    click(s.button('Save build'));s.reply({error:'Invalid targets'});assert.equal(name.val(),'<b>literal</b>');
    const save=s.button('Save build');s.owner.actor=8;click(save);assert.equal(s.calls.length,1);
});
test('single/bulk sharing relays inert text, explicit duplicate policy, and selection fallback',()=>{
    const s=fixture(1);click(s.button('Export my builds'));assert.equal(s.calls[0].request.build,null);s.reply({share:'BL1|1:0'});
    assert.equal(s.button('Paste clipboard'),undefined);
    const area=s.byClass('bl-share-text')[0];click(s.button('Select all text'));assert.equal(area.selected,true);assert.equal(area.val(),'BL1|1:0');
    assert.equal(area.prop('readOnly'),true);assert.equal(s.calls.length,1);
    s.owner.share(s.owner.data,null);s.byClass('bl-share-text')[0].val('BL1|untrusted text');click(s.button('Import builds'));
    assert.equal(s.calls.at(-1).request.text,'BL1|untrusted text');
});
test('mouse paste selects the target and requests one replacement per click without importing or normalizing text',()=>{
    const s=fixture(1);s.owner.share(s.data,null);const area=s.byClass('bl-share-text')[0];
    area.val('previous input');let commands=0,clipboard='BL1|1:0';
    global.document={execCommand(...args){
        assert.equal(this,global.document);assert.deepEqual(args,['paste']);commands++;
        assert.equal(area.focused,true);assert.equal(area.selectionStart,0);assert.equal(area.selectionEnd,area.val().length);
        area.val(area.val().slice(0,area.selectionStart)+clipboard+area.val().slice(area.selectionEnd));
        area.selectionStart=area.selectionEnd=area.val().length;area.focused=false;return true;
    }};
    const paste=s.button('Paste clipboard');
    for(let i=1;i<=2;i++){click(paste);assert.equal(commands,i);assert.equal(area.val(),clipboard);assert.deepEqual(s.calls,[]);}
    clipboard='  BL1|1:0BL1|1:0\n';click(paste);assert.equal(commands,3);assert.equal(area.val(),clipboard);
    assert.deepEqual(s.calls,[]);click(s.button('Import builds'));
    assert.equal(s.calls.length,1);assert.equal(s.calls[0].request.action,'import');assert.equal(s.calls[0].request.text,clipboard.replace(/^\s+/,''));
});
test('unavailable, refused, throwing or empty clipboard paste retains input and shows a manual fallback',()=>{
    for(const failure of ['unavailable','refused','throwing','empty']){
        const s=fixture(0);s.owner.share(s.data,null);const area=s.byClass('bl-share-text')[0],previous='  previous input\n';
        area.val(previous);let commands=0;
        global.document=failure==='unavailable'?{}:{execCommand(){
            commands++;area.val('');if(failure==='throwing')throw Error('clipboard denied');return failure==='empty';
        }};
        click(s.button('Paste clipboard'));assert.equal(commands,failure==='unavailable'?0:1);
        assert.equal(area.val(),previous);assert.equal(area.prop('readOnly'),false);assert.deepEqual(s.calls,[]);
        const error=s.byClass('bl-error')[0];assert.ok(error);assert.notEqual(error.hidden,true);
        assert.match(error.children[0].value,/paste manually/i);
        area.val('BL1|manual input');click(s.button('Import builds'));
        assert.equal(s.calls.length,1);assert.equal(s.calls[0].request.text,'BL1|manual input');
    }
});
test('paste can recover after failure, and stale import controls cannot read the clipboard',()=>{
    const s=fixture(0);s.owner.share(s.data,null);const area=s.byClass('bl-share-text')[0],paste=s.button('Paste clipboard');let commands=0;
    global.document={execCommand(){commands++;if(commands===1)return false;area.val('BL1|1:0');return true;}};
    click(paste);assert.equal(s.byClass('bl-error').length,1);click(paste);assert.equal(s.byClass('bl-error').length,0);
    assert.equal(area.val(),'BL1|1:0');s.owner.share(s.data,'export text');click(paste);
    assert.equal(commands,2);assert.deepEqual(s.calls,[]);assert.equal(s.byClass('bl-share-text')[0].val(),'export text');
});
test('first-block import relays excess notice once after success and only when supplied',()=>{
    for(const notice of [undefined,'Extra text after the first build block was ignored.']){
        const s=fixture(0);s.owner.share(s.data,null);s.byClass('bl-share-text')[0].val('  BL1|1:0BL1|truncated\n');
        click(s.button('Import builds'));assert.equal(s.calls[0].request.text,'BL1|1:0BL1|truncated\n');
        assert.equal(s.all().filter(n=>n.attr('role')==='status').length,0);
        s.reply(notice?{notice}:{});const status=s.all().filter(n=>n.attr('role')==='status');
        assert.equal(status.length,notice?1:0);
        if(notice){assert.equal(status[0].children[0].value,notice);assert.notEqual(status[0].hidden,true);}
        assert.equal(s.calls.length,1);s.owner.compare(s.owner.data);
        assert.equal(s.all().filter(n=>n.attr('role')==='status').length,0);
    }
});
test('deleting requires a second explicit action and preserves the shown tracked snapshot',()=>{
    const s=fixture(1,{build:'user_1',label:'Saved',enabled:true}),before=JSON.stringify(s.data.plan);click(s.byClass('bl-build-row')[0]);
    click(s.button('Delete'));assert.equal(s.calls.length,0);click(s.button('Delete build'));assert.equal(s.calls[0].request.action,'deleteBuild');assert.equal(JSON.stringify(s.data.plan),before);
});
test('closing a dialog during a request cannot resurrect it on the reply',()=>{
    const s=fixture(0);click(s.button('Create build'));click(s.button('Save build'));s.owner.closeCompare();
    s.reply({revision:1});assert.equal(s.owner.popup,null);
});
test('perk icons toggle flex/order without allowing an unbounded draft route',()=>{
    const s=fixture(1);s.owner.editor(s.data,s.data.library[0]);
    click(s.button('Up'));const first=s.byClass('bl-edit-perk')[0];assert.equal(first.children[0].value,'1. Colossus');
    const second=s.byClass('bl-edit-perk')[1];click(second.children[1].children[0]);
    assert.equal(s.byClass('bl-edit-perk')[0].children[0].value,'1. Gifted');
    assert.equal(s.byClass('bl-edit-perk')[0].children[1].children[1].focused,true,'focus did not follow the moved perk to its enabled control');
    click(s.button('Save build'));assert.deepEqual(s.calls[0].request.definition.route,['perk.gifted','perk.colossus']);
});

test('hovering a perk describes it, and the counter separates mandatory from flexible',()=>{
    const s=fixture(0),ids=['perk.student','perk.a','perk.b'];
    s.data.defs=Object.fromEntries(ids.map((id,i)=>[id,{name:'Pick '+i,unlock:0,row:0,column:i,
        description:id==='perk.a'?'Grants a real effect.':''}]));
    click(s.button('Create build'));
    const choices=s.byClass('bl-perk-choice'),describe=s.byClass('bl-perk-description')[0];
    // The stub's text() reads one node, so assert on the title and body children directly.
    const paneTitle=()=>describe.children[0].text(),pane=()=>describe.children[1].text();
    // Before hovering, the pane invites the player rather than showing a stale perk.
    assert.match(pane(),/Hover a perk/);
    choices[1].trigger('mouseenter');
    assert.match(pane(),/Grants a real effect\./);
    choices[1].trigger('mouseleave');
    assert.match(pane(),/Hover a perk/);
    // A perk with no description says so instead of rendering an empty pane.
    choices[2].trigger('mouseenter');
    assert.match(pane(),/No description available\./);
    // Two picks, one marked flexible: the counter must not call both mandatory.
    click(choices[1]);click(choices[2]);
    // The counter is the header's second child; the header node itself holds only its own label.
    const counter=()=>s.byClass('bl-order-header')[0].children[1].text();
    assert.match(counter(),/2 mandatory/);
    const flex=s.byClass('bl-edit-perk')[0].children[1].children[2].children[0];
    flex.prop('checked',true).trigger('ifChecked');
    assert.match(counter(),/1 mandatory/);
    assert.match(counter(),/1 flexible/);
});

test('native order list survives edits, contains wheel events and disposes resize callbacks',()=>{
    const s=fixture(1);s.owner.editor(s.data,s.data.library[0]);
    const list=s.byClass('bl-order-scroll')[0],viewport=list.aciScrollBar('container');
    viewport.scrollTop(80);
    const flex=s.byClass('bl-edit-perk')[0].children[1].children[2].children[0];
    flex.prop('checked',true).trigger('ifChecked');
    assert.equal(viewport.scrollTop(),80);assert.equal(s.byClass('bl-order-scroll')[0],list);
    click(s.byClass('bl-perk-choice').find(n=>n.attr('data-perk')==='perk.student'));
    assert.equal(s.byClass('bl-order-scroll')[0],list);assert.equal(viewport.scrollTop(),80);
    assert.equal(flex.destroyed,true,'rebuilt row retained its checkbox instance');
    let prevented=0,stopped=0;
    list.trigger('mousewheel',{preventDefault(){prevented++;},stopPropagation(){stopped++;}});
    assert.equal(prevented,1);assert.equal(stopped,1);
    const resize=s.owner.editorResize,updates=list.updates;
    s.window.trigger('resize');assert.ok(list.updates>updates);
    s.owner.actor=8;resize();const staleUpdates=list.updates;
    s.owner.closeCompare();resize();
    assert.equal(list.updates,staleUpdates);assert.equal(list.listDestroyed,true);
    assert.equal(s.window.handlers.resize,undefined);assert.equal(s.owner.editorResize,null);
});
test('editor follows source positions and keeps selected perks through reorder, flex, removal and edit save',()=>{
    const s=fixture(1),before=JSON.stringify(s.data.library);
    s.owner.editor(s.data,s.data.library[0]);
    const choices=s.byClass('bl-perk-choice');
    assert.deepEqual(choices.map(n=>n.attr('data-perk')),['perk.colossus','perk.student','perk.gifted']);
    const choice=id=>choices.find(n=>n.attr('data-perk')===id);
    assert.equal(choice('perk.gifted').attr('aria-pressed'),true);
    click(choice('perk.student'));
    click(s.byClass('bl-edit-perk')[2].children[1].children[0]);
    const flex=s.byClass('bl-edit-perk')[1].children[1].children[2].children[0];
    flex.prop('checked',true).trigger('ifChecked');
    click(choice('perk.gifted')); // Removing a selected flex pick also removes its flex intent.
    assert.equal(choice('perk.gifted').attr('aria-pressed'),false);
    assert.equal(choice('perk.student').attr('aria-pressed'),true);
    assert.deepEqual(s.calls,[]);
    click(s.button('Save build'));
    const request=s.calls[0].request;
    assert.equal(request.action,'saveBuild');assert.equal(request.create,false);
    assert.deepEqual(request.definition.route,['perk.colossus','perk.student']);
    assert.deepEqual(request.definition.flex,['perk.student']);
    assert.equal(JSON.stringify(s.data.library),before);
    s.owner.editor(s.data,request.definition);
    assert.deepEqual(s.byClass('bl-perk-choice').filter(n=>n.attr('aria-pressed')).map(n=>n.attr('data-perk')),request.definition.route);
});
test('source order wins over names, unlocks and object order; clean-sheet clicks allow any tier and cap at the list limit',()=>{
    const s=fixture(0),ids=Array.from({length:22},(_,i)=>i===0?'perk.student':'perk.pick_'+i);
    s.data.defs=Object.fromEntries(ids.slice().reverse().map(id=>{
        const i=ids.indexOf(id);return [id,{name:'Pick '+(22-i),unlock:21-i,row:i<4?0:2,column:i<4?i:i-4}];
    }));
    click(s.button('Create build'));
    const choices=s.byClass('bl-perk-choice');
    assert.deepEqual(choices.map(n=>n.attr('data-perk')),ids);
    assert.equal(choices[0].attr('aria-label'),'Pick 22');
    assert.equal(choices[0].attr('title'),'Pick 22 · 21 earlier picks');
    // 20 fit; the 21st is refused because the list itself is full, not because of the perk budget.
    choices.slice(0,20).forEach(click);click(choices[20]);
    assert.equal(choices[20].attr('aria-pressed'),false);assert.equal(s.byClass('bl-error').length,1);
    click(choices[5]);click(choices[20]);
    assert.equal(choices[5].attr('aria-pressed'),false);assert.equal(choices[20].attr('aria-pressed'),true);
    assert.deepEqual(s.calls,[]);click(s.button('Save build'));
    assert.equal(s.calls[0].request.create,true);
    assert.deepEqual(s.calls[0].request.definition.route,ids.slice(0,21).filter((_,i)=>i!==5));
});

test('weights retain ignored ranges, validate at the backend, and native checkbox events relay tags',()=>{
    const s=fixture(1),before=JSON.stringify(s.data.library);s.owner.editor(s.data,s.data.library[0]);
    const field=name=>s.all().find(n=>n.attr('aria-label')===name);
    field('HP Weight').val('0').trigger('input');field('Melee skill Weight').val('3');
    const tag=s.byClass('bl-tag').find(n=>n.children.some(c=>c.value==='Bow'));
    tag.children[0].prop('checked',true).trigger('ifChecked');
    const stale=s.byClass('bl-edit-perk')[1].children[1].children[2].children[0];
    click(s.byClass('bl-edit-perk')[1].children[1].children[0]);
    stale.prop('checked',false).trigger('ifUnchecked');
    click(s.button('Save build'));
    const b=s.calls[0].request.definition;
    assert.equal(b.weights.hp,0);assert.equal(b.weights.matk,3);assert.equal(b.targets.hp,60);assert.equal(b.preferred.hp,80);
    assert.ok(b.weaponTags.includes('Bow'));assert.ok(b.flex.includes('perk.gifted'));assert.equal(JSON.stringify(s.data.library),before);
    s.reply({error:'Invalid weights'});field('HP Weight').val('1.5');click(s.button('Save build'));
    assert.equal(s.calls.at(-1).request.definition.weights.hp,'1.5');
});

test('starter source filtering, tracking and unsaved copying never modify a template',()=>{
    const s=fixture(1),template=JSON.parse(JSON.stringify(s.data.library[0]));
    template.label='Starter example';s.data.starters=[template];
    s.data.builds.push({...s.data.builds[0],source:'starter',label:template.label});
    s.owner.compare(s.data);const before=JSON.stringify(s.data.starters);
    click(s.button('Source: All'));click(s.button('Starters'));
    assert.equal(s.byClass('bl-build-row').length,1);click(s.byClass('bl-build-row')[0]);
    assert.equal(s.button('Delete'),undefined);
    click(s.button('Track build'));assert.equal(s.calls[0].request.source,'starter');
    s.reply();s.owner.compare(s.owner.data);
    click(s.byClass('bl-build-row')[1]);click(s.button('Copy &amp; edit'));
    assert.equal(s.calls.length,1,'copy opening persisted a draft');
    click(s.button('Save build'));
    const r=s.calls.at(-1).request;assert.equal(r.create,true);assert.equal(r.definition.id,s.data.newBuildID);
    assert.equal(r.definition.label,template.label);assert.equal(JSON.stringify(s.data.starters),before);
    s.reply({error:'Library full'});assert.ok(s.button('Save build'),'failed copy discarded editor');
    click(s.button('Cancel'));assert.equal(s.calls.at(-1).request.action,'evaluate');
    assert.equal(JSON.stringify(s.data.starters),before);
});

test('hiding starters drops the source chooser and stale controls while personal copies remain trackable',()=>{
    const s=fixture(1),template={...s.data.library[0],label:'Starter example'};
    s.data.starters=[template];s.data.builds.push({...s.data.builds[0],source:'starter',label:template.label});
    s.owner.compare(s.data);click(s.button('Source: All'));const oldChoice=s.button('Starters');
    s.owner.evaluate();s.reply({starters:[],builds:s.data.builds.filter(b=>b.source==='library')});
    assert.equal(s.button('Source: All'),undefined);click(oldChoice);
    assert.equal(s.byClass('bl-build-row').length,1);
    click(s.byClass('bl-build-row')[0]);click(s.button('Track build'));
    assert.equal(s.calls.at(-1).request.source,'library');assert.equal(s.calls.at(-1).request.build,template.id);
    s.reply();s.owner.evaluate();s.reply();
    click(s.button('Source: All'));click(s.button('Starters'));
    assert.equal(s.byClass('bl-build-row').length,1);
    assert.equal(s.byClass('bl-build-row')[0].attr('data-source'),'starter');
});

test('legacy alternatives relay the saved option and stale dialogs cannot replace perks',()=>{
    const option={index:0,replace:'perk.colossus',with:'perk.gifted',active:false,condition:'A different future pick.'};
    const s=fixture(0,{label:'Saved',enabled:true,options:[option]});
    const action=s.button('Replace Colossus with Gifted');click(action);
    assert.equal(s.calls[0].request.action,'replace');assert.equal(s.calls[0].request.index,0);
    assert.equal(s.calls[0].request.replace,option.replace);assert.equal(s.calls[0].request.with,option.with);
    s.reply();click(action);assert.equal(s.calls.length,1);
});
