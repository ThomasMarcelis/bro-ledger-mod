var BroLedgerUI = (function () {
    'use strict';
    var sequence = 0;
    var names = {hp: 'HP', resolve: 'Resolve', fatigue: 'Fatigue', initiative: 'Initiative',
        matk: 'Melee skill', ratk: 'Ranged skill', mdef: 'Melee defence', rdef: 'Ranged defence'};
    var offerFields = {hp: 'hitpointsIncrease', resolve: 'braveryIncrease', fatigue: 'fatigueIncrease',
        initiative: 'initiativeIncrease', matk: 'meleeSkillIncrease', ratk: 'rangeSkillIncrease',
        mdef: 'meleeDefenseIncrease', rdef: 'rangeDefenseIncrease'};
    function text(parent, value, heading) {
        return $('<div/>').addClass(heading ? 'bl-heading title-font-normal font-bold' : 'bl-line text-font-normal')
            .text(value).appendTo(parent);
    }
    function safe(value) {
        return String(value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }
    function button(parent, label, action) {
        return $('<div class="bl-button"/>').appendTo(parent).createTextButton(safe(label), action, '', 1);
    }
    function tooltip(node, id) {
        node.addClass('bl-tooltip').bindTooltip({contentType: 'msu-generic', modId: 'mod_bro_ledger', elementId: id});
    }
    function checkbox(label, checked, change) {
        var input = $('<input type="checkbox" class="bl-checkbox"/>').prop('checked', checked).prependTo(label);
        input.iCheck({checkboxClass: 'icheckbox_flat-orange', increaseArea: '0%'});
        input.on('ifChecked ifUnchecked', function () { change(input.prop('checked')); });
        return input;
    }
    function disposeCheckboxes(parent) {
        parent.find('.bl-checkbox').each(function () { $(this).iCheck('destroy'); });
    }
    function disposeTooltips(parent) {
        // Native unbind alone leaves a delayed hover tooltip pending.
        parent.find('.bl-tooltip').each(function () { $(this).trigger('hide-tooltip').unbindTooltip(); });
    }
    function disposeLists(parent) {
        disposeCheckboxes(parent);
        disposeTooltips(parent);
        parent.find('.bl-scroll').each(function () { $(this).destroyList(); });
    }
    function perkName(id, defs) { return defs[id] ? defs[id].name : id + ' (unavailable)'; }
    function perkList(ids, defs) { return ids.map(function (id) { return perkName(id, defs); }).join(', '); }
    function Controller(screen) {
        this.screen = screen;
        this.actor = null;
        this.seq = ++sequence;
        this.data = null;
        this.enabled = null;
        this.visible = false;
        this.popup = null;
        this.editorResize = null;
        this.panel = null;
        this.offerContent = null;
    }
    Controller.prototype.invalidate = function () {
        this.seq = ++sequence;
        this.data = null;
        this.offerContent = null;
    };
    Controller.prototype.request = function (action, extra, done) {
        if (!this.visible || this.actor === null || this.screen.mSQHandle === null) return;
        // Rendered controls can survive a refresh, but an old revision cannot authorize a write.
        if (action !== 'refresh' && action !== 'evaluate' && !this.data) return;
        var self = this, actor = this.actor, seq = ++sequence, previous = this.data, requestPopup = this.popup;
        var request = {action: action, actor: actor, seq: seq};
        if (this.data) { request.epoch = this.data.epoch; request.revision = this.data.revision; }
        Object.keys(extra || {}).forEach(function (k) { request[k] = extra[k]; });
        this.seq = seq;
        this.data = null;
        var received = false, receive = function (reply) {
            received = true;
            if (!self.visible || self.seq !== seq || self.actor !== actor) return;
            if (!reply || reply.error) {
                self.data = previous;
                self.showError(reply && reply.error ? reply.error : 'Planner did not receive a response.');
                return;
            }
            if (reply.actor !== actor || reply.seq !== seq) return;
            self.data = reply;
            self.enabled = reply.settings.Enabled;
            self.render();
            if (done && self.popup === requestPopup) done(reply);
        };
        try { SQ.call(this.screen.mSQHandle, 'onBroLedger', request, receive); }
        catch (error) {
            if (received) throw error;
            receive({error: 'Planner request failed: ' + error});
        }
    };
    Controller.prototype.select = function () {
        var selected = this.screen.mDataSource.getSelectedBrother();
        this.closeCompare();
        this.invalidate();
        this.actor = selected ? selected.id : null;
        this.render();
        this.request('refresh');
    };
    Controller.prototype.showError = function (message) {
        if (this.enabled === false) return;
        var self = this, actor = this.actor, seq = this.seq;
        var parent=this.popup ? this.popup.findPopupDialogContentContainer() : this.panel;
        parent.find('.bl-error').remove();
        var error = $('<div class="bl-error bl-warning"/>').appendTo(parent);
        text(error,message);
        if (!this.popup) {
            parent.show(); this.screen.mContainer.addClass('bl-with-plan');
            if (!this.data || !this.data.plan || !this.data.plan.enabled || this.data.issue) parent.addClass('bl-failure');
            button(error, 'Retry', function () {
                if (self.visible && self.actor === actor && self.seq === seq) self.evaluate();
            });
        }
    };
    Controller.prototype.clearMarks = function () {
        this.screen.mContainer.find('.bl-route, .bl-optional').removeClass('bl-route bl-optional');
    };
    Controller.prototype.markPerks = function () {
        this.clearMarks();
        var data = this.data, plan = data && data.plan;
        if (!plan || !plan.enabled || !data.settings.Enabled || !data.settings.PerkHighlights) return;
        var tree = this.screen.mRightPanelModule.mPerksModule.mPerkTree || [];
        tree.forEach(function (row) { row.forEach(function (perk) {
            if (!perk.Container) return;
            if (plan.flex.indexOf(perk.ID) !== -1) perk.Container.addClass('bl-optional');
            else if (plan.route.remaining.indexOf(perk.ID) !== -1 || plan.route.acquired.indexOf(perk.ID) !== -1 ||
                plan.route.blocked.indexOf(perk.ID) !== -1) perk.Container.addClass('bl-route');
        }); });
    };
    function valueLabel(value) { return value == null ? '?' : String(Number(value.toFixed(2))); }
    function scoreLabel(build) { return build.score == null ? 'Unrated' : valueLabel(build.score) + '/100'; }
    function matches(build, weapon, style, source) {
        return (weapon === 'All' || build.weaponTags.indexOf(weapon) !== -1) &&
            (style === 'All' || build.playstyleTags.indexOf(style) !== -1) &&
            (!source || source === 'All' || (source === 'Starters' ? build.source === 'starter' : build.source !== 'starter'));
    }
    Controller.prototype.targets = function (parent, build, stars, compact) {
        var table = $('<table class="bl-targets"/>').appendTo(parent);
        var header = $('<tr/>').appendTo($('<thead/>').appendTo(table));
        (compact ? ['Stat', 'Current', 'Ideal'] : ['Stat', 'Current', 'Potential', 'Min', 'Ideal', 'Weight']).forEach(function (label) {
            $('<th/>').text(label).appendTo(header);
        });
        var body = $('<tbody/>').appendTo(table), short = {hp:'HP',resolve:'Res',fatigue:'Fat',initiative:'Init',matk:'MAtk',ratk:'RAtk',mdef:'MDef',rdef:'RDef'};
        build.statRows.forEach(function (row) {
            var tr = $('<tr/>').appendTo(body);
            $('<td/>').text(compact ? short[row.key] : names[row.key]).attr('title', names[row.key]).appendTo(tr);
            tooltip($('<td/>').text(valueLabel(row.now)).appendTo(tr), 'stats');
            if (!compact) {
                tooltip($('<td/>').text(valueLabel(row.expected)).appendTo(tr), 'expected');
                $('<td/>').text(row.minimum == null ? '—' : valueLabel(row.minimum)).appendTo(tr);
            }
            tooltip($('<td/>').text(row.idealState === 'ignored' ? 'Ignored' : row.ideal == null ? '—' : valueLabel(row.ideal)).addClass('bl-target-' + row.idealState).appendTo(tr), 'targets');
            if (!compact) $('<td/>').text(row.minimum == null ? '—' : row.weight).appendTo(tr);
        });
        var joint = build.jointState === 'impossible' ? 'Goals compete: no joint maximum-roll allocation.' :
            build.jointState === 'individual' ? 'Red goals exceed individual maximum rolls.' :
            build.jointState === 'unknown' ? 'Growth or saved Ideal goals unknown.' :
            build.jointState === 'untargeted' ? 'No weighted attribute goals.' : 'Goals share limited picks; actual rolls matter.';
        text(parent, 'To L' + build.projection.horizon + ': ' + joint).addClass('bl-bound');
    };
    Controller.prototype.perkOrder = function (parent, plan, defs, compact) {
        text(parent, 'Creator order · blue = flex', true);
        var route = $('<div class="bl-route-list"/>').toggleClass('bl-compact-route', !!compact).appendTo(parent);
        (plan.order || []).forEach(function (id, i) {
            var row = $('<div class="bl-route-item text-font-normal"/>').appendTo(route);
            var label = perkName(id, defs);
            if (compact && id.indexOf('perk.mastery.') === 0) {var key=id.split('.').pop();label=key.charAt(0).toUpperCase()+key.slice(1)+' M.';}
            row.text((i + 1) + '. ' + label).attr('title', perkName(id, defs));
            if (plan.route.acquired.indexOf(id) !== -1) row.addClass('bl-target-met');
            else if (plan.flex.indexOf(id) !== -1) row.addClass('bl-flex-text');
        });
        if (!plan.route.feasible) text(parent, 'Route blocked: unlocks, spent points or missing perks.').addClass('bl-warning bl-route-status');
    };
    Controller.prototype.effects = function (parent, effects) {
        [['dodge','Dodge','Def'],['nimble','Nimble','HP DR'],['battleForged','Forged','Armour DR']].forEach(function (spec) {
            var effect = effects[spec[0]], value = !effect.owned ? '—' : effect.value === null ? '?' :
                spec[0] === 'dodge' ? '+' + effect.value : Number(effect.value.toFixed(1)) + '%';
            var row = $('<div class="bl-effect text-font-normal"/>').appendTo(parent);
            tooltip($('<span/>').text(spec[1] + ' ' + spec[2]).appendTo(row), spec[0]);
            $('<span class="bl-effect-value"/>').text(value).attr('title', effect.owned ? 'Current value' : 'Not learned').appendTo(row);
        });
    };
    Controller.prototype.render = function () {
        if (!this.panel) return;
        disposeLists(this.panel); this.panel.empty().hide().removeClass('bl-failure'); this.screen.mContainer.removeClass('bl-with-plan');
        var self = this, data = this.data, plan = data && data.plan;
        var enabled = data ? data.settings.Enabled : this.enabled;
        this.entry.toggle(this.visible && this.actor !== null && enabled !== false); this.markPerks();
        if (!this.visible || !data || !data.settings.Enabled || !plan || !plan.enabled || data.issue) { this.renderOffer(); return; }
        this.panel.show(); this.screen.mContainer.addClass('bl-with-plan');
        text(this.panel, plan.label, true).addClass('bl-plan-title');
        var controls = $('<div class="bl-controls"/>').appendTo(this.panel);
        button(controls, 'Change build', function () { self.evaluate(); });
        button(controls, 'Disable', function () { self.request('enabled', {enabled:false}); });
        this.targets(this.panel, plan, data.stars, true);
        this.perkOrder(this.panel, plan, data.defs, true);
        this.effects($('<div class="bl-effects"/>').appendTo(this.panel), plan.effects);
        this.renderOffer();
    };
    Controller.prototype.evaluate = function () {
        var self = this; this.request('evaluate', {}, function (data) { if (data.settings.Enabled) self.compare(data); });
    };
    Controller.prototype.closeCompare = function () {
        if (this.editorResize) { $(window).off('resize', this.editorResize); this.editorResize = null; }
        if (!this.popup) return;
        disposeLists(this.popup); this.popup.destroyPopupDialog(); this.popup = null;
        this.screen.mDataSource.notifyBackendPopupDialogIsVisible(false);
    };
    Controller.prototype.dialog = function (title) {
        this.closeCompare(); this.screen.mDataSource.notifyBackendPopupDialogIsVisible(true);
        this.popup = this.screen.mContainer.createPopupDialog(safe(title), null, null, 'bl-compare');
        return this.popup;
    };
    Controller.prototype.current = function (data, popup) {
        return this.popup === popup && this.visible && this.actor === data.actor && this.data === data && data.settings.Enabled;
    };
    Controller.prototype.compare = function (data) {
        if (!data.settings.Enabled) return;
        var self = this, popup = this.dialog(data.title), selected = null, weapon = 'All', style = 'All', source = 'All', page = 0;
        var body = $('<div class="bl-compare-body"/>').appendTo(popup.findPopupDialogContentContainer());
        var context = $('<div class="bl-compare-context"/>').appendTo(body);
        text(context, data.name + ' · Builds and starter templates', true);
        tooltip(text(context, 'Potential: weighted target fit using one shared allocation.'), 'potential');
        var tools = $('<div class="bl-toolbar"/>').appendTo(context);
        button(tools, 'Create build', function () { if (self.current(data,popup)) self.editor(data,null); });
        button(tools, 'Import', function () { if (self.current(data,popup)) self.share(data,null); });
        button(tools, 'Export my builds', function () {
            if (self.current(data,popup)) self.request('export',{build:null},function (reply) { self.share(reply,reply.share); });
        });
        var filters = $('<div class="bl-filters"/>').appendTo(context), chooser = null, filterButton = null;
        function closeChooser() {
            if (!chooser) return;
            chooser.remove(); chooser = null;
            filterButton.attr('aria-expanded', false); filterButton = null;
        }
        function filter(label, values, change) {
            var choice = 'All';
            var control = button(filters, label + ': ' + choice, function () {
                if (!self.current(data,popup)) return;
                var closing = filterButton === control;
                closeChooser();
                if (closing) return;
                var panel = chooser = $('<div class="bl-filter-chooser"/>').appendTo(filters);
                filterButton = control; control.attr('aria-expanded', true);
                var heading = $('<div class="bl-filter-heading"/>').appendTo(panel);
                text(heading,label,true);
                button(heading,'Close',function () { if (self.current(data,popup) && chooser === panel) closeChooser(); });
                var options = $('<div class="bl-filter-options"/>').appendTo(panel);
                ['All'].concat(values).forEach(function (value) {
                    button(options,value,function () {
                        if (!self.current(data,popup) || chooser !== panel) return;
                        closeChooser(); choice = value; change(value);
                        control.changeButtonText(safe(label + ': ' + value));
                        page = 0; selected = null; draw();
                    }).toggleClass('bl-filter-active',value === choice).attr('aria-pressed',value === choice);
                });
            }).attr('aria-expanded',false);
        }
        filter('Weapon',data.weaponTags,function (v) {weapon=v;}); filter('Playstyle',data.playstyleTags,function (v) {style=v;});
        filter('Source',['My builds','Starters'],function (v) {source=v;});
        var columns = $('<div class="bl-compare-columns"/>').appendTo(body);
        var catalog = $('<div class="bl-build-list"/>').appendTo(columns);
        var list = $('<div class="bl-catalog-body"/>').appendTo(catalog);
        var paging = $('<div class="bl-paging"/>').appendTo(catalog);
        var details = $('<div class="bl-build-details bl-detail-content"/>').appendTo(columns);
        function preview(build) {
            if (!self.current(data,popup) || !matches(build,weapon,style,source)) return;
            selected=build; disposeTooltips(details); details.empty();
            list.find('.bl-build-row').removeClass('is-selected').filter(function () {return $(this).attr('data-build')===build.id && $(this).attr('data-source')===build.source;}).addClass('is-selected');
            text(details,build.label + ' · ' + scoreLabel(build),true);
            if(build.source==='starter') text(details,'Starter builds are original examples of common community archetypes. They may be suboptimal; use them as starting guides and adjust them to your brothers and playstyle.').addClass('bl-starter-notice');
            self.targets(details,build,data.stars,false); self.perkOrder(details,build,data.defs,false);
            var actions=$('<div class="bl-toolbar"/>').appendTo(details);
            button(actions,build.source==='starter'?'Copy & edit':'Edit',function () {
                if (self.current(data,popup) && !data.libraryIssue) self.editor(data,(build.source==='starter'?data.starters:data.library).filter(function (b) {return b.id===build.id;})[0],build.source==='starter');
            });
            button(actions,'Export',function () { if (self.current(data,popup)) self.request('export',{build:build.id,source:build.source},function (reply) {self.share(reply,reply.share);}); });
            if(build.source!=='starter') button(actions,'Delete',function () {
                if (!self.current(data,popup)) return;
                actions.empty();text(actions,'Remove from library? Tracked plans keep their snapshots.');
                button(actions,'Delete build',function () {if(self.current(data,popup)) self.request('deleteBuild',{build:build.id},function (reply) {self.compare(reply);});});
                button(actions,'Keep',function () {preview(build);});
            });
            popup.findPopupDialogOkButton().enableButton(!data.issue && (!data.libraryIssue || build.source==='starter') && build.route.unknown.length===0);
        }
        function draw() {
            closeChooser();
            disposeTooltips(list); list.empty(); paging.empty(); disposeTooltips(details); details.empty();
            var filtered=data.builds.filter(function (b) {return matches(b,weapon,style,source);});
            filtered.slice(page*10,page*10+10).forEach(function (build) {
                var row=$('<div class="bl-build-row text-font-normal" role="button" tabindex="0"/>').attr('data-build',build.id).attr('data-source',build.source).appendTo(list);
                $('<span class="bl-build-grade"/>').text(scoreLabel(build)).appendTo(row);
                $('<span class="bl-build-name"/>').text(build.label).appendTo(row);
                if(build.source==='starter') $('<span class="bl-starter-label"/>').text('Starter').appendTo(row);
                row.on('click',function () {preview(build);}).on('keydown',function(e){if(e.which===13||e.which===32){e.preventDefault();preview(build);}});
            });
            text(paging,filtered.length ? (page*10+1)+'–'+Math.min(page*10+10,filtered.length)+' of '+filtered.length : '0 matches');
            if(page>0) button(paging,'Previous',function(){if(self.current(data,popup)){page--;selected=null;draw();}});
            if((page+1)*10<filtered.length) button(paging,'Next',function(){if(self.current(data,popup)){page++;selected=null;draw();}});
            text(details,data.libraryIssue || (data.builds.length===0 ? 'Your library is empty. Create a build or import share text.' :
                filtered.length ? 'Select a build to inspect its targets and perk order.' : 'No builds match these filters.'));
            if(data.issue) text(details,data.issue).addClass('bl-warning');
            if(data.starters && data.starters.length) text(details,'Starter templates are starting guides and may be suboptimal. Select one to inspect it, track it, or copy it into your library.').addClass('bl-starter-notice');
            if(data.plan) text(details,(data.plan.enabled?'Tracking: ':'Disabled plan: ')+data.plan.label);
            // Legacy replacements stay deliberate and reachable from Change build, outside the compact panel.
            if(data.plan && data.plan.options && data.plan.options.length) {
                var alternatives=$('<div class="bl-alternatives"/>').appendTo(details);
                text(alternatives,'Saved perk alternatives',true);
                text(alternatives,'Change a future pick in this saved plan. This does not learn or refund a perk.');
                data.plan.options.forEach(function(option){
                var from=perkName(option.active?option.with:option.replace,data.defs),to=perkName(option.active?option.replace:option.with,data.defs);
                text(alternatives,'Planned: '+from+'. '+option.condition);
                button(alternatives,'Replace '+from+' with '+to,function(){
                    if(self.current(data,popup)) self.request('replace',option,function(reply){self.closeCompare();});
                });
                });
            }
            popup.findPopupDialogOkButton().enableButton(false);
        }
        popup.addPopupDialogCancelButton(function(){if(self.popup===popup)self.closeCompare();});
        popup.addPopupDialogButton(data.plan?'Change build':'Track build','l-ok-button',function(){
            if(self.current(data,popup)&&selected&&matches(selected,weapon,style,source)&&!data.issue && (!data.libraryIssue || selected.source==='starter') && selected.route.unknown.length===0) {
                self.request('track',{build:selected.id,source:selected.source},function(){self.closeCompare();});
            }
        },true);
        if(data.plan&&!data.plan.enabled&&!data.issue) {
            popup.addClass('bl-has-resume');popup.addPopupDialogButton('Re-enable plan','bl-resume-button',function(){
                if(self.current(data,popup))self.request('enabled',{enabled:true},function(){self.closeCompare();});
            });
        }
        draw();
    };
    Controller.prototype.editor = function (data, original, copy) {
        var self=this, popup=this.dialog(copy?'Copy starter':original?'Edit build':'Create build');popup.addClass('bl-editor');
        var b=original?JSON.parse(JSON.stringify(original)):{id:data.newBuildID,label:'',targets:{},preferred:{},route:[],flex:[],weaponTags:[],playstyleTags:[]};
        if(copy)b.id=data.newBuildID;
        if(!b.weights)b.weights={};
        var body=$('<div class="bl-editor-body"/>').appendTo(popup.findPopupDialogContentContainer());
        var title=$('<label class="bl-name-field text-font-normal"/>').text('Build name ').appendTo(body);
        var name=$('<input type="text" maxlength="40"/>').val(b.label).appendTo(title);
        var board=$('<div class="bl-board"/>').appendTo(body),main=$('<div class="bl-board-main"/>').appendTo(board);
        var fields=$('<div class="bl-board-fields"/>').appendTo(main),left=$('<div class="bl-board-targets"/>').appendTo(fields);
        var middle=$('<div class="bl-board-perks"/>').appendTo(fields),right=$('<div class="bl-board-order"/>').appendTo(board);
        text(left,'Attributes Ranges',true);text(left,'Ranges: 0–500, two decimals. Blank pair = ignored.');
        text(left,'Weight 0–10: 0 ignores; 2 = twice 1.');
        var targetTable=$('<table class="bl-targets bl-input-targets"/>').appendTo(left),inputs={};
        var targetHead=$('<tr/>').appendTo($('<thead/>').appendTo(targetTable));
        ['Attribute','Minimum','Ideal','Weight'].forEach(function(label){$('<th/>').text(label).appendTo(targetHead);});
        var targetBody=$('<tbody/>').appendTo(targetTable);
        Object.keys(names).forEach(function(k){
            var row=$('<tr/>').appendTo(targetBody),label=$('<td/>').text(names[k]).appendTo(row);inputs[k]=[];
            ['targets','preferred'].forEach(function(field){inputs[k].push($('<input type="text" inputmode="decimal"/>').attr('aria-label',names[k]+' '+(field==='targets'?'Minimum':'Ideal'))
                .val(b[field][k]===undefined?'':b[field][k]).appendTo($('<td/>').appendTo(row)));});
            var weight=$('<input type="text" inputmode="numeric" maxlength="2"/>').attr('aria-label',names[k]+' Weight')
                .val(b.weights[k]===undefined?1:b.weights[k]).appendTo($('<td/>').appendTo(row));inputs[k].push(weight);
            function ignored(){var off=weight.val().trim()==='0'||(inputs[k][0].val().trim()===''&&inputs[k][1].val().trim()==='');
                row.toggleClass('bl-ignored',off);label.text(names[k]+(off?' · Ignored':''));}
            inputs[k].forEach(function(input){input.on('input change',ignored);});ignored();
        });
        function tags(parent,label,values,key){
            text(parent,label,true);var grid=$('<div class="bl-tag-grid"/>').appendTo(parent);
            values.forEach(function(tag){var node=$('<label class="bl-tag text-font-normal"/>').appendTo(grid);
                if(data.tagIcons && data.tagIcons[tag])$('<img class="bl-tag-icon"/>').attr('src',Path.GFX+data.tagIcons[tag]).attr('alt','').appendTo(node);
                $('<span/>').text(tag).appendTo(node);
                checkbox(node,b[key].indexOf(tag)!==-1,function(checked){if(!self.current(data,popup))return;
                    var at=b[key].indexOf(tag);if(checked&&at===-1)b[key].push(tag);else if(!checked&&at!==-1)b[key].splice(at,1);});
            });
        }
        tags(left,'Playstyle',data.playstyleTags,'playstyleTags');
        text(middle,'Perks · click to add / remove',true);
        var tree=$('<div class="bl-perk-tree"/>').appendTo(middle),header=$('<div class="bl-order-header"/>').appendTo(right);
        text(header,'Perk order',true);var count=text(header,'');
        text(header,'A flexible pick can yield to an off-route perk you learn manually.');
        var listHost=$('<div class="bl-order-list-host"/>').appendTo(right);
        var list=listHost.createList(8,'bl-scroll bl-order-scroll',true),order=list.findListScrollContainer().addClass('bl-edit-route');
        var viewport=list.aciScrollBar('container');
        // The native control allows wheel events to bubble at the ends of its list.
        list.on('mousewheel',function(e){e.preventDefault();e.stopPropagation();});
        function layoutOrder(){
            if(!self.current(data,popup))return;
            listHost.css('top',header.outerHeight(true));list.trigger('update');
        }
        function revealRow(row){
            var top=row.offset().top-viewport.offset().top,bottom=top+row.outerHeight(true);
            if(top<0)list.trigger('scroll',{top:viewport.scrollTop()+top});
            else if(bottom>viewport.innerHeight())list.trigger('scroll',{top:viewport.scrollTop()+bottom-viewport.innerHeight()});
        }
        this.editorResize=layoutOrder;$(window).on('resize',layoutOrder);
        function tiny(parent,label,title,action){return $('<button type="button" class="bl-small"/>').text(label).attr('title',title).on('click',action).appendTo(parent);}
        var routeVersion=0;
        function drawRoute(revealID,direction){
            var version=++routeVersion,scrollTop=viewport.scrollTop(),reveal=null,focus=null;
            disposeCheckboxes(order);order.empty();count.text(b.route.length+' picks · unchecked = mandatory');
            b.route.forEach(function(id,i){
                var row=$('<div class="bl-edit-perk text-font-normal"/>').attr('data-perk',id).appendTo(order);
                $('<span/>').text((i+1)+'. '+perkName(id,data.defs)).appendTo(row);
                var actions=$('<div class="bl-perk-actions"/>').appendTo(row);
                var up=tiny(actions,'Up','Move earlier',function(){if(self.current(data,popup)&&version===routeVersion&&i>0){b.route.splice(i-1,0,b.route.splice(i,1)[0]);drawRoute(id,'up');}}).prop('disabled',i===0);
                var down=tiny(actions,'Dn','Move later',function(){if(self.current(data,popup)&&version===routeVersion&&i<b.route.length-1){b.route.splice(i+1,0,b.route.splice(i,1)[0]);drawRoute(id,'down');}}).prop('disabled',i===b.route.length-1);
                var label=$('<label class="bl-flex-control"/>').appendTo(actions);$('<span/>').text('Flexible').appendTo(label);
                checkbox(label,b.flex.indexOf(id)!==-1,function(checked){if(!self.current(data,popup)||version!==routeVersion)return;
                    var at=b.flex.indexOf(id);if(checked&&at===-1)b.flex.push(id);else if(!checked&&at!==-1)b.flex.splice(at,1);});
                if(!data.defs[id]||data.defs[id].unlock>i)row.addClass('bl-target-impossible').attr('title',!data.defs[id]?'Perk unavailable.':'Requires '+data.defs[id].unlock+' earlier picks. Reorder or add earlier-tier perks.');
                if(id===revealID){reveal=row;if(direction)focus=direction==='up'?(i>0?up:down):(i<b.route.length-1?down:up);}
            });
            tree.find('.bl-perk-choice').each(function(){
                var selected=b.route.indexOf($(this).attr('data-perk'))!==-1;
                $(this).toggleClass('is-selected',selected).attr('aria-pressed',selected);
            });
            layoutOrder();list.trigger('scroll',{top:scrollTop});
            if(reveal)revealRow(reveal);
            if(focus)focus.focus();
        }
        var tier=null,treeRow=null;
        Object.keys(data.defs).sort(function(a,c){return data.defs[a].row-data.defs[c].row||data.defs[a].column-data.defs[c].column;}).forEach(function(id){
            var def=data.defs[id];
            if(tier!==def.row){tier=def.row;treeRow=$('<div class="bl-perk-tier"/>').appendTo(tree);}
            var node=$('<button type="button" class="bl-perk-choice"/>').attr('data-perk',id).attr('title',def.name+' · '+def.unlock+' earlier picks').attr('aria-label',def.name).appendTo(treeRow);
            if(def.icon)$('<img/>').attr('src',Path.GFX+def.icon).attr('alt',def.name).appendTo(node);else node.text(def.name);
            node.on('click',function(){if(!self.current(data,popup))return;var at=b.route.indexOf(id),added=at===-1;if(added){if(b.route.length>=11){self.showError('At most 11 picks, including Student. Remove a perk first.');return;}b.route.push(id);}else{b.route.splice(at,1);at=b.flex.indexOf(id);if(at!==-1)b.flex.splice(at,1);}drawRoute(added?id:null);});
        });
        tags(middle,'Weapon / equipment',data.weaponTags,'weaponTags');drawRoute();
        popup.addPopupDialogCancelButton(function(){if(self.popup===popup)self.evaluate();});
        popup.addPopupDialogButton('Save build','l-ok-button',function(){
            if(!self.current(data,popup))return;b.label=name.val();b.targets={};b.preferred={};
            Object.keys(inputs).forEach(function(k){var values=inputs[k];['targets','preferred'].forEach(function(field,i){
                var value=values[i].val().trim();if(value!=='')b[field][k]=/^\d+(\.\d{1,2})?$/.test(value)?Number(value):value;
            });var weight=values[2].val().trim();b.weights[k]=/^\d+$/.test(weight)?Number(weight):weight;});
            self.request('saveBuild',{definition:b,create:!original||!!copy},function(reply){self.compare(reply);});
        });
    };
    Controller.prototype.share = function(data, exported){
        var self=this,popup=this.dialog(exported===null?'Import builds':'Export builds');popup.addClass('bl-sharing');
        var body=$('<div class="bl-share-body"/>').appendTo(popup.findPopupDialogContentContainer());
        text(body,exported===null?'Paste a single or bulk BL1 or BL2 string. Imports apply together.':'Select text, then Ctrl+C. Paste into another campaign or share with a player.',true);
        text(body,'Library belongs to this campaign; save the campaign to retain edits. Tracked snapshots stay independent.');
        var area=$('<textarea class="bl-share-text" spellcheck="false" maxlength="48000"/>').attr('aria-label','Build share text').val(exported||'').prop('readOnly',exported!==null).appendTo(body);
        if(exported===null)button(body,'Paste clipboard',function(){
            if(!self.current(data,popup))return;
            var previous=area.val(),pasted=false;
            area.focus();area[0].select();
            try { pasted=typeof document.execCommand==='function' && document.execCommand('paste'); }
            catch(error) { pasted=false; }
            if(!pasted || !area.val()){
                area.val(previous);
                self.showError('Could not paste clipboard text. Your text is unchanged; paste manually.');
            } else popup.find('.bl-error').remove();
        });
        var policy=$('<select aria-label="Duplicate handling"/>');
        if(exported===null){var label=$('<label class="text-font-normal"/>').text('Duplicate IDs or names: ').appendTo(body);policy.appendTo(label);
            [['reject','Reject duplicates'],['skip','Skip duplicates'],['copy','Import copies']].forEach(function(p){$('<option/>').val(p[0]).text(p[1]).appendTo(policy);});}
        else button(body,'Select all text',function(){area.focus();area[0].select();});
        popup.addPopupDialogCancelButton(function(){if(self.popup===popup)self.evaluate();});
        if(exported===null)popup.addPopupDialogButton('Import builds','l-ok-button',function(){if(self.current(data,popup))self.request('import',{text:area.val().replace(/^\s+/,''),policy:policy.val()},function(reply){
            self.compare(reply);
            if(reply.notice)text($('<div class="bl-error"/>').attr('role','status').appendTo(self.popup.findPopupDialogContentContainer()),reply.notice);
        });});
    };
    Controller.prototype.renderOffer = function () {
        if (!this.offerContent) return;
        var content = this.offerContent, data = this.data;
        content.closest('.popup-dialog').removeClass('bl-levelup-popup');
        content.removeClass('bl-levelup');
        content.find('.bl-offer').remove();
        content.find('.bl-recommended').removeClass('bl-recommended');
        if (!data || !data.settings.Enabled || !data.settings.LevelUpRecommendations || !data.plan || !data.plan.enabled) return;
        var brother = this.screen.mDataSource.getSelectedBrother();
        var visible = brother && brother.character && brother.character.levelUp;
        if (!visible) return;
        content.addClass('bl-levelup').closest('.popup-dialog').addClass('bl-levelup-popup');
        if (!data.offer || Object.keys(offerFields).some(function (k) { return visible[offerFields[k]] !== data.offer.values[k]; })) {
            text($('<div class="bl-offer"/>').appendTo(content), 'Guidance is unavailable for this offer. Choose stats normally.');
            return;
        }
        text($('<div class="bl-offer"/>').appendTo(content), data.offer.label + ': ' + data.offer.picks.map(function (k) {
            return names[k] + ' +' + data.offer.values[k];
        }).join(' · ') + '. ' + data.offer.reason);
        this.markOfferRows(data.offer.picks);
    };
    Controller.prototype.markOfferRows = function (picks) {
        var header = this.screen.mCharacterPanelModule.mCharacterPanelHeaderModule;
        var fields = picks.map(function (k) { return offerFields[k]; });
        [header.mLevelUpLeftStatsRows, header.mLevelUpRightStatsRows].forEach(function (rows) {
            Object.keys(rows).forEach(function (key) {
                var row = rows[key];
                if (row.Button && fields.indexOf(row.StatValueIdentifier) !== -1)
                    row.Button.closest('.row').addClass('bl-recommended');
            });
        });
    };
    if (typeof CharacterScreen === 'undefined') return {matches: matches, Controller: Controller, safe: safe};
    var connection = CharacterScreen.prototype.onConnection;
    CharacterScreen.prototype.onConnection = function (handle) {
        connection.call(this, handle);
        var owner = this.broLedger = new Controller(this), source = this.mDataSource;
        source.broLedger = owner;
        owner.panel = $('<div class="bl-panel"/>').hide().appendTo(this.mCharacterScreen);
        owner.entry = $('<div class="bl-entry"/>').hide().appendTo(this.mCharacterPanelModule.mCharacterPanelHeaderModule.mContainer);
        owner.entry.createTextButton('Bro Planner', function () { owner.evaluate(); }, '', 1);
        owner.selected = function () { owner.select(); };
        owner.updated = function (ds, bro) {
            if (bro && bro.id === owner.actor) {
                owner.closeCompare();
                // Keep the sheet still: native drag/drop caches the equipment slot bounds.
                owner.request('refresh');
            }
        };
        source.addListener(CharacterScreenDatasourceIdentifier.Brother.Selected, owner.selected);
        source.addListener(CharacterScreenDatasourceIdentifier.Brother.Updated, owner.updated);
    };
    var show = CharacterScreen.prototype.show;
    CharacterScreen.prototype.show = function (data) {
        if (this.broLedger) {
            this.broLedger.visible = true;
            this.broLedger.enabled = null;
            this.broLedger.invalidate(); this.broLedger.render();
        }
        show.call(this, data);
        if (this.broLedger) this.broLedger.select();
    };
    var hide = CharacterScreen.prototype.hide;
    CharacterScreen.prototype.hide = function () {
        if (this.broLedger) {
            this.broLedger.visible = false;
            this.broLedger.closeCompare(); this.broLedger.invalidate(); this.broLedger.render();
        }
        return hide.call(this);
    };
    var disconnect = CharacterScreen.prototype.onDisconnection;
    CharacterScreen.prototype.onDisconnection = function () {
        var owner = this.broLedger, source = this.mDataSource;
        if (owner) {
            owner.visible = false; owner.invalidate();
            source.broLedger = null; this.broLedger = null;
            try {
                // Vanilla removeListener calls an unavailable Array.remove. Splice only our callbacks.
                [[CharacterScreenDatasourceIdentifier.Brother.Selected, owner.selected],
                    [CharacterScreenDatasourceIdentifier.Brother.Updated, owner.updated]].forEach(function (binding) {
                    var listeners = source.mEventListener[binding[0]], index = listeners.indexOf(binding[1]);
                    if (index !== -1) listeners.splice(index, 1);
                });
                owner.closeCompare();
                disposeLists(owner.panel); owner.panel.remove(); owner.entry.remove();
            } catch (error) {
                console.error('Bro Build Planner cleanup failed: ' + error);
            }
        }
        // Native teardown must remove the screen even if optional planner UI disposal failed.
        return disconnect.call(this);
    };
    var tree = CharacterScreenPerksModule.prototype.loadPerkTreesWithBrotherData;
    CharacterScreenPerksModule.prototype.loadPerkTreesWithBrotherData = function (brother) {
        var result = tree.call(this, brother);
        if (this.mDataSource.broLedger) this.mDataSource.broLedger.markPerks();
        return result;
    };
    var offer = CharacterScreenLeftPanelHeaderModule.prototype.createLevelUpDialogContent;
    CharacterScreenLeftPanelHeaderModule.prototype.createLevelUpDialogContent = function () {
        var content = offer.call(this), owner = this.mDataSource.broLedger;
        if (owner && content) {
            owner.offerContent = content;
            owner.renderOffer(); owner.request('refresh', {}, function () { owner.renderOffer(); });
        }
        return content;
    };
    return {matches: matches, Controller: Controller};
}());
if (typeof module !== 'undefined') module.exports = BroLedgerUI;
