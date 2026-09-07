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
    function scroll(parent) {
        return parent.createList(8, 'bl-scroll', true).findListScrollContainer();
    }
    function disclosure(parent, label) {
        var section = $('<div class="bl-disclosure"/>').appendTo(parent);
        var toggle = $('<div class="bl-disclosure-toggle text-font-normal" role="button" tabindex="0"/>')
            .attr('aria-expanded', 'false').text('+ ' + label).appendTo(section);
        var content = $('<div class="bl-disclosure-content"/>').hide().appendTo(section), open = false;
        function change() {
            open = !open;
            toggle.attr('aria-expanded', open ? 'true' : 'false').text((open ? '- ' : '+ ') + label);
            content.toggle(open);
            section.closest('.bl-scroll').trigger('update', true);
        }
        toggle.on('click', change).on('keydown', function (event) {
            if (event.which === 13 || event.which === 32) { event.preventDefault(); change(); }
        });
        return content;
    }
    function tooltip(node, id) {
        node.addClass('bl-tooltip').bindTooltip({contentType: 'msu-generic', modId: 'mod_bro_ledger', elementId: id});
    }
    function disposeTooltips(parent) {
        // Native unbind alone leaves a delayed hover tooltip pending.
        parent.find('.bl-tooltip').each(function () { $(this).trigger('hide-tooltip').unbindTooltip(); });
    }
    function disposeLists(parent) {
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
        this.visible = false;
        this.popup = null;
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
        var self = this, actor = this.actor, seq = ++sequence;
        var request = {action: action, actor: actor, seq: seq};
        if (this.data) { request.epoch = this.data.epoch; request.revision = this.data.revision; }
        Object.keys(extra || {}).forEach(function (k) { request[k] = extra[k]; });
        this.seq = seq;
        this.data = null;
        SQ.call(this.screen.mSQHandle, 'onBroLedger', request, function (reply) {
            if (!self.visible || self.seq !== seq || self.actor !== actor) return;
            if (!reply || reply.error) {
                self.showError(reply && reply.error ? reply.error : 'Planner did not receive a response.');
                return;
            }
            if (reply.actor !== actor || reply.seq !== seq) return;
            self.data = reply;
            self.render();
            if (done) done(reply);
        });
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
        this.data = null;
        this.clearMarks();
        if (this.popup) {
            var details = this.popup.find('.bl-detail-content');
            disposeTooltips(details); details.empty();
            text(details, message).addClass('bl-warning');
            details.closest('.bl-scroll').trigger('update', true).trigger('scroll', {top: 0});
            this.popup.findPopupDialogOkButton().enableButton(false);
            var resume = this.popup.findPopupDialogButton('bl-resume-button');
            if (resume) resume.enableButton(false);
        }
        else { disposeLists(this.panel); this.panel.show().empty(); text(this.panel, message); }
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
    Controller.prototype.grades = function (parent, build) {
        var grades = $('<div class="bl-grades text-font-normal"/>').appendTo(parent);
        tooltip($('<span/>').text('Now ' + build.nowGrade).appendTo(grades), 'now');
        tooltip($('<span/>').text('Potential ' + build.grade).appendTo(grades), 'potential');
    };
    Controller.prototype.targets = function (parent, build, stars, compact) {
        text(parent, 'Stat goals', true);
        var horizon = build.projection.horizon;
        function valueLabel(value) { return value == null ? '?' : String(Number(value.toFixed(2))); }
        function attribute(node, key) {
            node.addClass('bl-attribute').text(names[key]);
            var talent = stars[key];
            if (talent !== null) {
                tooltip($('<img class="bl-talent"/>').attr('src', Path.GFX + 'ui/icons/talent_' + talent + '.png')
                    .attr('alt', talent + ' talent star' + (talent === 1 ? '' : 's')).appendTo(node), 'talents');
            } else tooltip($('<span class="bl-talent"/>').text('?').appendTo(node), 'talents');
        }
        function target(node, value, state, prefix) {
            var label = state === 'none' ? '—' : valueLabel(value);
            if (state === 'met' || state === 'grow') {
                node.text(prefix || '');
                $('<span aria-hidden="true"/>').addClass(state === 'met' ? 'bl-target-check' : 'bl-arrow bl-arrow-up').appendTo(node);
                $('<span/>').text(label).appendTo(node);
            } else node.text((prefix || '') + label);
            tooltip(node.addClass('bl-target-' + state), 'targets');
        }
        function expected(node, row, prefix) {
            tooltip(node.text((prefix || '') + valueLabel(row.expected) + (row.expectedShortfall ? ' !' : ''))
                .addClass(row.expectedShortfall ? 'bl-warning' : ''), 'expected');
        }
        var body;
        if (compact) {
            tooltip(text(parent, 'Projected at level ' + horizon).addClass('bl-muted'), 'expected');
            body = $('<div class="bl-stat-stack"/>').appendTo(parent);
        } else {
            var table = $('<table class="bl-targets"/>').appendTo(parent);
            var header = $('<tr/>').appendTo($('<thead/>').appendTo(table));
            [['Attribute', 'talents'], ['Now', 'stats'], ['Projected at level ' + horizon, 'expected'],
                ['Minimum', 'targets'], ['Ideal', 'targets']].forEach(function (spec) {
                var cell = $('<th scope="col"/>').text(spec[0]).appendTo(header);
                if (spec[1] === 'expected') $('<div class="bl-muted"/>').text('Average rolls').appendTo(cell);
                tooltip(cell, spec[1]);
            });
            body = $('<tbody/>').appendTo(table);
        }
        build.statRows.forEach(function (row) {
            if (compact) {
                var item = $('<div class="bl-stat text-font-normal"/>').appendTo(body);
                attribute($('<div/>').appendTo(item), row.key);
                var values = $('<div class="bl-stat-values"/>').appendTo(item);
                tooltip($('<span/>').text('Now ' + valueLabel(row.now)).appendTo(values), 'stats');
                $('<span class="bl-arrow" aria-hidden="true"/>').appendTo(values);
                expected($('<span/>').appendTo(values), row, 'L' + horizon + ' ');
                var goals = $('<div class="bl-stat-goals"/>').appendTo(item);
                target($('<span/>').appendTo(goals), row.minimum, row.minimumState, 'Min ');
                target($('<span/>').appendTo(goals), row.ideal, row.idealState, 'Ideal ');
            } else {
                var tr = $('<tr/>').appendTo(body);
                attribute($('<td/>').appendTo(tr), row.key);
                $('<td/>').text(valueLabel(row.now)).appendTo(tr);
                expected($('<td/>').appendTo(tr), row);
                target($('<td/>').appendTo(tr), row.minimum, row.minimumState);
                target($('<td/>').appendTo(tr), row.ideal, row.idealState);
            }
        });
    };
    Controller.prototype.allocation = function (parent, build) {
        var content = disclosure(parent, 'Forecast allocation'), projection = build.projection;
        if (!projection.known) { text(content, 'Unavailable').addClass('bl-muted'); return; }
        build.statRows.forEach(function (row) {
            var counts = projection.allocation[row.key];
            text(content, names[row.key] + ': ' + counts[0] + (counts[0] === 1 ? ' pick' : ' picks') +
                (counts[1] ? ' + ' + counts[1] + ' veteran' : '') + (counts[2] ? ' + Gifted' : ''));
        });
    };
    Controller.prototype.routeWarnings = function (parent, route, defs) {
        if (route.offplan.length) text(parent, 'Already spent outside route: ' + perkList(route.offplan, defs)).addClass('bl-warning');
        if (route.unknown.length) text(parent, 'Missing definitions: ' + perkList(route.unknown, defs)).addClass('bl-warning');
        if (route.blocked.length) text(parent, 'Tier blocked: ' + perkList(route.blocked, defs)).addClass('bl-warning');
        if (route.conflicts.length) text(parent, 'Outside this armour role: ' + perkList(route.conflicts, defs)).addClass('bl-warning');
        if (!route.feasible) text(parent, 'This route cannot currently be completed; check perk budget, tiers and role conflicts.').addClass('bl-warning');
    };
    Controller.prototype.effects = function (parent, effects) {
        text(parent, 'Current effects', true);
        [['dodge', 'Dodge', 'Melee & ranged defence'], ['nimble', 'Nimble', 'HP damage reduction'],
            ['battleForged', 'Battle Forged', 'Armour damage reduction']].forEach(function (spec) {
            var row = $('<div class="bl-effect text-font-normal"/>').appendTo(parent);
            var effect = effects[spec[0]], value = 'Unknown';
            if (!effect.owned) value = 'Not learned';
            else if (effect.value !== null)
                value = spec[0] === 'dodge' ? '+' + effect.value : Number(effect.value.toFixed(1)) + '%';
            $('<span class="bl-effect-value"/>').text(value)
                .addClass(!effect.owned ? 'bl-muted' : '').appendTo(row);
            tooltip($('<span/>').text(spec[1]).appendTo(row), spec[0]);
            $('<div class="bl-effect-kind bl-muted"/>').text(spec[2]).appendTo(row);
        });
    };
    Controller.prototype.weaponComparisons = function (parent, comparisons) {
        if (!comparisons) return;
        var content = disclosure(parent, 'When to switch from a spear');
        tooltip(text(content, comparisons.assumptions), 'weapons');
        text(content, 'Natural Melee skill: ' + Number(comparisons.attack.toFixed(2)) + '.');
        text(content, comparisons.limits);
        comparisons.matches.forEach(function (match) {
            var rows = disclosure(content, match.label + ' / ' + match.armour + ' body armour');
            match.rows.forEach(function (row) {
                text(rows, row.name, true);
                text(rows, Number(row.hit.toFixed(1)) + '% hit · ' + Number(row.hp.toFixed(2)) +
                    ' expected HP · ' + Number(row.armour.toFixed(2)) + ' expected armour · ' +
                    row.fat + '/' + row.masteredFat + ' Fatigue');
                if (row.wins !== null) text(rows, 'More immediate HP than Fighting Spear at Melee skill: ' +
                    (row.wins.length ? row.wins.map(function (range) {
                        return range[0] === range[1] ? String(range[0]) : range[0] + '-' + range[1];
                    }).join(', ') : 'none in the compared range') + '.');
            });
        });
    };
    Controller.prototype.render = function () {
        if (!this.panel) return;
        disposeLists(this.panel);
        this.panel.empty().hide();
        this.screen.mContainer.removeClass('bl-with-plan');
        var self = this, data = this.data, plan = data && data.plan;
        this.entry.toggle(!!(data && data.settings.Enabled));
        this.markPerks();
        if (!data || !data.settings.Enabled || !plan || !plan.enabled || data.issue) { this.renderOffer(); return; }
        this.panel.show(); this.screen.mContainer.addClass('bl-with-plan');
        var header = $('<div class="bl-plan-header"/>').appendTo(this.panel);
        text(header, plan.label, true).addClass('bl-plan-title');
        this.grades(header, plan);
        var controls = $('<div class="bl-controls"/>').appendTo(header);
        button(controls, 'Change build', function () { self.evaluate(); });
        button(controls, 'Disable', function () { self.request('enabled', {enabled: false}); });
        var body = $('<div class="bl-plan-body"/>').appendTo(this.panel);
        body.css('top', header.position().top + header.outerHeight());
        var content = scroll(body);
        this.effects($('<div class="bl-effects"/>').appendTo(this.panel), plan.effects);
        if (data.settings.PerkHighlights) text(content, 'Perks: green route / blue flex.').addClass('bl-muted');
        this.routeWarnings(content, plan.route, data.defs);
        if (plan.legacy) text(content, 'Saved definition differs from this catalog: original route and targets retained. Change build to adopt a current destination.').addClass('bl-muted');
        data.warnings.forEach(function (warning) { text(content, warning).addClass('bl-warning'); });
        this.targets(content, plan, data.stars, true);
        var gear = plan.equipment;
        if (gear) {
            gear.cycles.forEach(function (cycle) {
                if (!cycle.projectedLegal || (cycle.currentFat !== null && !cycle.currentLegal))
                    text(content, (cycle.projectedLegal ? 'Current ' : 'Planned ') + cycle.label +
                        ': AP requirement is not met; check Equipment advice.').addClass('bl-warning');
            });
            var equipment = disclosure(content, 'Equipment advice');
            text(equipment, plan.weapons);
            if (plan.masteryNote) text(equipment, plan.masteryNote);
            this.weaponComparisons(equipment, data.weaponComparisons);
            text(equipment, 'Capacity ' + gear.capacity + ' · headroom now ' + gear.headroom + ' · recovery ' + gear.recovery + '/turn');
            text(equipment, 'Armour head/body max: ' + gear.headArmour + ' / ' + gear.bodyArmour + '. Raw weight ' + gear.rawArmour + '; effective cost ' + gear.effectiveArmour + '.');
            text(equipment, plan.armour === 'nimble' ? 'Nimble: 15 raw armour weight keeps the base 40% HP damage taken. More protection may justify more weight.' : 'Battle Forged: no universal armour cap. Fit heavy protection within the action reserve.');
            gear.cycles.forEach(function (cycle) {
                text(equipment, cycle.label, true);
                text(equipment, 'Planned standard weapon: ' + cycle.projectedFat + ' Fatigue / ' + cycle.projectedAP + ' AP. ' + cycle.turns + ' turns, rested start, ' + cycle.buffer + ' reserve.');
                if (!cycle.projectedLegal) text(equipment, 'This planned cycle exceeds available AP; use a legal fallback or change the route.');
                else text(equipment, 'Needs ' + cycle.reserve + ' capacity; head + body allowance ' + (cycle.armourBudget === null ? 'unknown' : cycle.armourBudget) + ' effective weight with the other current items and modifiers unchanged.');
                text(equipment, cycle.currentFat === null ? 'Matching actions are not currently equipped/acquired; current cycle cost is unknown.' :
                    'Current actions: ' + cycle.currentFat + ' Fatigue / ' + cycle.currentAP + ' AP; ' + cycle.currentReserve + ' capacity for this cycle.' + (cycle.currentLegal ? '' : ' AP requirement is not met.'));
            });
            text(equipment, 'Weapons, shield, ammunition and bag penalties are already included by the game in capacity. Future Bags and Belts/Brawny savings are not assumed. Terrain, incoming hits, swaps, ammunition and target conditions still matter.');
            gear.items.forEach(function (item) { text(equipment, (item.bag ? 'Bag: ' : 'Equipped: ') + item.name); });
        }
        this.allocation(content, plan);
        content.closest('.bl-scroll').trigger('update', true);
        this.renderOffer();
    };
    Controller.prototype.evaluate = function () {
        var self = this;
        this.request('evaluate', {}, function (data) { if (data.settings.Enabled) self.compare(data); });
    };
    Controller.prototype.closeCompare = function () {
        if (!this.popup) return;
        disposeLists(this.popup);
        this.popup.destroyPopupDialog(); this.popup = null;
        this.screen.mDataSource.notifyBackendPopupDialogIsVisible(false);
    };
    Controller.prototype.compare = function (data) {
        var self = this;
        this.closeCompare();
        if (!data.settings.Enabled) return;
        this.screen.mDataSource.notifyBackendPopupDialogIsVisible(true);
        var popup = this.popup = this.screen.mContainer.createPopupDialog(safe(data.title), null, null, 'bl-compare');
        // Keep the native popup chrome; CSS owns sizing instead of addContent's fixed pixel width.
        var body = $('<div class="bl-compare-body"/>').appendTo(popup.findPopupDialogContentContainer());
        var context = $('<div class="bl-compare-context"/>').appendTo(body);
        text(context, data.name, true);
        text(context, 'Fit measures this brother. Spears and swords suit early accuracy; armour and enemy resistances can favour other weapons.');
        var selected = null, roleFilter = 'All', weaponFilter = 'All', rows = [], menu = null;
        function matches(build) {
            return (roleFilter === 'All' || build.role === roleFilter) &&
                (weaponFilter === 'All' || build.weaponTags.indexOf(weaponFilter) !== -1);
        }
        function current() {
            return self.popup === popup && self.visible && self.actor === data.actor &&
                self.data === data && data.settings.Enabled;
        }
        function commit(action, extra) {
            if (!current() || data.issue) return;
            self.closeCompare(); self.request(action, extra);
        }
        var filters = $('<div class="bl-filters"/>').appendTo(context);
        var count = text(context, data.builds.length + ' builds').addClass('bl-muted');
        var columns = $('<div class="bl-compare-columns"/>').appendTo(body);
        var catalog = $('<div class="bl-build-list"/>').appendTo(columns);
        var headings = $('<div class="bl-catalog-heading text-font-normal"/>').appendTo(catalog);
        $('<span/>').text('Build').appendTo(headings);
        tooltip($('<span class="bl-now-column"/>').text('Now').appendTo(headings), 'now');
        tooltip($('<span class="bl-potential-column"/>').text('Potential').appendTo(headings), 'potential');
        var list = scroll($('<div class="bl-catalog-body"/>').appendTo(catalog));
        var details = scroll($('<div class="bl-build-details"/>').appendTo(columns)).addClass('bl-detail-content');
        function preview(build, row) {
            if (!current() || !matches(build)) return;
            selected = build;
            var track = popup.findPopupDialogOkButton();
            if (track) track.enableButton(!data.issue);
            list.find('.bl-build-row').removeClass('is-selected'); row.addClass('is-selected');
            disposeTooltips(details); details.empty();
            if (data.issue) text(details, data.issue).addClass('bl-warning');
            text(details, build.label, true).addClass('bl-detail-title');
            var role = build.preferred ?
                (data.recommended === build.id ? 'Preferred role' : 'One of ' + data.primary.length + ' preferred roles') :
                build.alternative ? 'Conditional alternative' : null;
            if (role) text(details, role).addClass('bl-muted');
            if (build.niche) text(details, build.niche);
            self.grades(details, build);
            self.routeWarnings(details, build.route, data.defs);
            if (data.plan && !data.issue) text(details, (data.plan.enabled ? 'Saved: ' : 'Disabled: ') + data.plan.label +
                '. Change build replaces its route and replacements.').addClass('bl-warning');
            self.targets(details, build, data.stars, false);
            var perks = disclosure(details, 'Perk preview');
            if (build.masteryNote) text(perks, build.masteryNote);
            build.adjustments.forEach(function (change) {
                text(perks, 'Keeps ' + perkName(change.with, data.defs) + ' instead of ' + perkName(change.replace, data.defs) + '.');
            });
            if (build.route.acquired.length) text(perks, 'Acquired: ' + perkList(build.route.acquired, data.defs));
            var route = $('<div class="bl-route-list"/>').appendTo(perks);
            build.route.remaining.forEach(function (id, i) { text(route, (i + 1) + '. ' + perkName(id, data.defs)); });
            var advice = disclosure(details, data.settings.EquipmentAdvice ? 'Build notes & equipment' : 'Build notes');
            text(advice, build.note);
            if (data.settings.EquipmentAdvice) {
                text(advice, build.weapons);
                self.weaponComparisons(advice, data.weaponComparisons);
            }
            data.notes.forEach(function (note) { text(advice, note); });
            data.warnings.forEach(function (warning) { text(details, warning).addClass('bl-warning'); });
            self.allocation(details, build);
            details.closest('.bl-scroll').trigger('update', true).trigger('scroll', {top: 0});
        }
        var first = null, saved = null;
        data.builds.forEach(function (build) {
            var row = $('<div class="bl-build-row text-font-normal" role="button" tabindex="0"/>')
                .attr('data-build', build.id).appendTo(list);
            tooltip($('<span class="bl-build-grade bl-now-column title-font-big"/>').text(build.nowGrade).appendTo(row), 'now');
            tooltip($('<span class="bl-build-grade bl-potential-column title-font-big"/>').text(build.grade).appendTo(row), 'potential');
            $('<span class="bl-build-name"/>').text(build.label).appendTo(row);
            row.on('click', function () { preview(build, row); });
            row.on('keydown', function (event) {
                if (event.which === 13 || event.which === 32) { event.preventDefault(); preview(build, row); }
            });
            rows.push({build: build, row: row});
            if (!first) first = {build: build, row: row};
            if (data.plan && data.plan.build === build.id) saved = {build: build, row: row};
        });
        function closeMenu() {
            if (!menu) return;
            disposeLists(menu); menu.remove(); menu = null;
        }
        function applyFilters() {
            var visible = 0;
            rows.forEach(function (entry) {
                var show = matches(entry.build); entry.row.toggle(show);
                if (show) visible++;
            });
            count.text(visible + ' of ' + data.builds.length + ' builds');
            if (selected && !matches(selected)) {
                selected = null;
                list.find('.bl-build-row').removeClass('is-selected');
            }
            if (!selected) {
                disposeTooltips(details); details.empty();
                text(details, visible ? 'Choose a visible build to preview and track.' : 'No builds match both filters.');
            }
            popup.findPopupDialogOkButton().enableButton(!!selected && !data.issue);
            list.closest('.bl-scroll').trigger('update', true).trigger('scroll', {top: 0});
            details.closest('.bl-scroll').trigger('update', true);
        }
        function filterControl(kind, values) {
            var holder = $('<div class="bl-filter-control"/>').appendTo(filters);
            function render() {
                holder.empty();
                button(holder, kind + ': ' + (kind === 'Role' ? roleFilter : weaponFilter), function () {
                    if (!current()) return;
                    closeMenu();
                    var opened = menu = $('<div class="bl-filter-menu"/>').appendTo(columns);
                    var options = scroll(opened);
                    button(options, 'Close filter', function () { if (current() && menu === opened) closeMenu(); });
                    values.forEach(function (value) {
                        button(options, value, function () {
                            if (!current() || menu !== opened) return;
                            if (kind === 'Role') roleFilter = value; else weaponFilter = value;
                            closeMenu(); render(); applyFilters();
                        });
                    });
                    options.closest('.bl-scroll').trigger('update', true);
                });
            }
            render();
        }
        var roles = [], weapons = [];
        data.builds.forEach(function (build) {
            if (roles.indexOf(build.role) === -1) roles.push(build.role);
            build.weaponTags.forEach(function (tag) { if (weapons.indexOf(tag) === -1) weapons.push(tag); });
        });
        filterControl('Role', ['All'].concat(roles.sort()));
        filterControl('Weapon', ['All'].concat(weapons.sort()));
        var initial = saved || first;
        if (initial) {
            preview(initial.build, initial.row);
            list.closest('.bl-scroll').trigger('update', true).scrollListToElement(initial.row);
        }
        popup.addPopupDialogCancelButton(function () { if (self.popup === popup) self.closeCompare(); });
        popup.addPopupDialogButton(data.plan ? 'Change build' : 'Track build', 'l-ok-button', function () {
            if (selected && matches(selected)) commit('track', {build: selected.id});
        }, !!data.issue || !initial);
        if (data.plan && !data.plan.enabled && !data.issue) {
            popup.addClass('bl-has-resume');
            popup.addPopupDialogButton('Re-enable plan', 'bl-resume-button', function () {
                commit('enabled', {enabled: true});
            });
        }
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
    if (typeof CharacterScreen === 'undefined') return {Controller: Controller, safe: safe};
    var connection = CharacterScreen.prototype.onConnection;
    CharacterScreen.prototype.onConnection = function (handle) {
        connection.call(this, handle);
        var owner = this.broLedger = new Controller(this), source = this.mDataSource;
        source.broLedger = owner;
        owner.panel = $('<div class="bl-panel"/>').hide().appendTo(this.mCharacterScreen);
        owner.entry = $('<div class="bl-entry"/>').hide().appendTo(this.mCharacterPanelModule.mCharacterPanelHeaderModule.mContainer);
        owner.entry.createTextButton('Evaluate', function () { owner.evaluate(); }, '', 1);
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
    return {Controller: Controller};
}());
if (typeof module !== 'undefined') module.exports = BroLedgerUI;
