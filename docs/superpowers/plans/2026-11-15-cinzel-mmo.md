# Cinzel MMORPG Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the MMORPG layer to Cinzel: per-floor monsters with elites and named rares, mastery by use with 3 special tiers and style relics, consumables with a quick bar, refining, a mission board, and a bestiary with titles, all lost on death.

**Architecture:** New pure-logic classes in `game/logic/` (MonsterDB, Mastery, SpecialMove, Buffs, Refine, MissionBoard, Bestiary, Titles) hang off `RunState`, so `RunState.die()` drops them with the rest of the run and unit tests drive them without scenes. Actors report to the run through two narrow calls (`RunState.record_kill`, `RunState.add_mastery_xp`); stats stay computed in one place (`PlayerStats.from_equipment(eq, run)`). UI is built on the existing `UiPanel`/`UiKit`/`ItemCell` kit; art goes through the existing `art-src/` scripts.

**Tech Stack:** Godot 4.7, GDScript (static types), the in-repo test runner (`game/tests/run_tests.gd`, `T` helper), AI generator MCP for art and sound, Python 3 + Pillow scripts in `art-src/`, the QA robot `game/tools/qa_autopilot.gd`.

**Spec:** `docs/superpowers/specs/2026-11-15-cinzel-mmo-design.md`

## Global Constraints

- GDScript only, statically typed (typed vars, typed `Array[...]`/`Dictionary[...]`, return types), tabs, `##` doc comments, one `class_name` per logic file; match the surrounding file's style.
- `GODOT=/Applications/Godot.app/Contents/MacOS/Godot`.
- Tests: `$GODOT --headless --path game --import` then `$GODOT --headless --path game -s res://tests/run_tests.gd`; done means the last line is `PASS N / FAIL 0` and the output has no `SCRIPT ERROR`. A test that exercises an intended `push_error` goes in its suite's `EXPECTS_ERRORS`.
- Tests reach autoloads through `(Engine.get_main_loop() as SceneTree).root.get_node("Game")`, as the existing suites do; new suites go in `game/tests/unit/test_<name>.gd`.
- Screenshots: always `$GODOT --position 5000,5000 --path game -- --screenshot=<scene> --out=/tmp/<name>.png --frames=<n> [debug args]`, then open the PNG with Read and check what the step names. No UI, VFX or art step is done on a typecheck alone.
- Art: town style (key art `art-src/keyart/keyart-town-1-*.png`), AI generator project `asset-gen`, preset `cinzel-pixel`, generation names prefixed `cinzel-`, originals saved under `art-src/gen/r3/`, built by `art-src/` scripts with `python3 -I` from a venv with Pillow, `art-src/check_art.py` passes, one row per new file in `docs/assets.md`. A sprite must match its icon (same shapes and colours); a monster visibly carries the material it drops, in that material icon's colours.
- Player-facing text in Portuguese, short: toasts up to 5 words, speech bubbles up to 25 words in 3 lines (`TownLogic.bubble_fits`).
- Death (`RunState.die()`) resets all run progress: gear, gold, floors, mastery, specials unlocked, buffs, quick bar, refine levels, missions, bestiary, titles. Outfits, the worn outfit, `show_armor`, `dual_blades` and `tutorial_done` stay. Nothing is saved to disk.
- No copying other games: no names, creatures, items or UI lifted from existing games or franchises.
- Commits: Portuguese, short, prefix as the repo does (`feat:`, `arte:`, `docs:`, `teste:`), `git add` only the task's paths, no Claude co-author or generated-by trailer, never push.
- Balance numbers pinned below are starting values; the robot passes (Tasks 10 and 27) may change them and must record every change in `docs/balance.md`.

## Review Focus

1. Mastery XP from things that are not the player's fight: hits on the final boss's summons must give no weapon XP and no kill; an ember vent or shockwave rolled through gives roll XP once per roll, not once per frame; healing in town gives no heal XP. Tests in Task 11 (`test_summon_hits_give_no_mastery`, `test_hazard_dodge_counts_once_per_roll`, `test_heal_xp_only_in_tower`).
2. Using a consumable while a panel is open (tree paused, swap panel) or during a roll, special or death: refused, nothing spent. Test in Task 19 (`test_quick_use_refused_while_paused_or_busy`).
3. Leaving mid-floor (held Q, stairs to town) with missions running: kills already made still count, a "reach floor X without leaving" mission resets with the trip, and done-but-unclaimed missions survive the next board refresh. Test in Task 23 (`test_leaving_mid_floor_keeps_kills_resets_reach`).
4. Refining an item and then selling, dropping or swapping out its last copy: the refine level goes with it, so a later copy starts at +0; a second copy still owned keeps the shared level. Test in Task 21 (`test_refine_cleared_when_last_copy_leaves`).
5. Elites and rares where they do not belong: never in tutorial or boss rooms, never on summons; a summoned slime does not split. Tests in Task 2 (`test_summoned_slime_does_not_split`), Task 5 (`test_no_elites_in_tutorial_boss_or_summons`) and Task 6 (`test_rare_never_in_tutorial_or_boss_room`).

---

### Task 1: Monster roster framework and species drops

Floor rosters by role, species-based drops, and the kill report every later system listens to. Until Task 2 lands, floor 1's `charger` role spawns the existing beetle (`rhino_beetle`).

**Files:**
- Create: `game/logic/monster_db.gd`
- Modify: `game/logic/loot_table.gd`, `game/logic/run_state.gd`, `game/actors/enemies/enemy_base.gd`, `crawler.gd`, `shooter.gd`, `charger.gd`, `crawler.tscn`, `shooter.tscn`, `charger.tscn`, `game/actors/bosses/boss_final.gd`, `game/world/room.gd`, `game/world/dungeon.gd`, `game/world/test_arena.gd`
- Test: `game/tests/unit/test_monster_db.gd`; update `test_loot_table.gd`, `test_floors.gd`, `test_weapon_combat.gd`, `test_dual_blades.gd` (they read `ENEMY_MATERIALS` / `loot_type()`)

**Interfaces:**
- Produces:
  - `MonsterDB.SPECIES: Dictionary[StringName, Dictionary]`, each row `{"name": String, "floor": int, "role": StringName, "scene": String, "material": StringName, "attack": String, "weakness": String, "hunter_title": String}` (rares, Task 6, use `"title"` and `"line"` instead of `"hunter_title"`).
  - `MonsterDB.ROSTER: Dictionary[int, Dictionary]` floor -> role (`&"crawler"`, `&"shooter"`, `&"charger"`) -> species.
  - `MonsterDB.species_for(role: StringName, floor_num: int) -> StringName`, `scene_path(role: StringName, floor_num: int) -> String`, `species_of_floor(floor_num: int) -> Array[StringName]`, `material(species: StringName) -> StringName`, `display_name(species: StringName) -> String`, `floor_of(species: StringName) -> int`. Floors clamp to 1..3.
  - `LootTable.roll_enemy(species: StringName, floor_num: int, rng: RandomNumberGenerator) -> Array[LootDrop]`, `LootTable.ENEMY_DROP_CHANCE := 0.5`, `EXTRA_DROP_CHANCE := 0.2`, `EXTRA_MATERIALS: Array[StringName] = [&"mat_iron_ore", &"mat_old_leather"]`. `ENEMY_MATERIALS` is removed.
  - `EnemyBase`: `@export var species: StringName = &""`, `var summoned: bool = false`, `var elite: bool = false` (used from Task 5); `loot_type()` is removed.
  - `RunState`: `signal enemy_killed(species: StringName, elite: bool)`, `func record_kill(species: StringName, elite: bool = false) -> void`.
  - `Room`: `var floor_num: int = 1` (Dungeon sets it before `start`).

- [ ] **Step 1: Write the failing tests** in `test_monster_db.gd`

```gdscript
func test_roster_resolves_roles_per_floor() -> void:
	T.eq(MonsterDB.species_for(&"crawler", 1), &"slime")
	T.eq(MonsterDB.species_for(&"shooter", 1), &"sentinel")
	T.eq(MonsterDB.scene_path(&"crawler", 1), "res://actors/enemies/crawler.tscn")
	T.eq(MonsterDB.scene_path(&"shooter", 9), MonsterDB.scene_path(&"shooter", 3), "floor clamps to 3")
	T.eq(MonsterDB.material(&"slime"), &"mat_old_leather")
	T.eq(MonsterDB.material(&"sentinel"), &"mat_iron_ore")
	T.eq(MonsterDB.material(&"rhino_beetle"), &"mat_beetle_horn")

func test_enemy_drops_its_own_material_half_the_time() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var got: Dictionary[StringName, int] = {}
	for i in 400:
		for d: LootDrop in LootTable.roll_enemy(&"slime", 1, rng):
			got[d.id] = got.get(d.id, 0) + d.qty
	T.eq(got.keys(), [&"mat_old_leather"], "floor 1: only its own material")
	T.ok(got[&"mat_old_leather"] > 160 and got[&"mat_old_leather"] < 240, "about 50%")

func test_deep_floor_enemy_also_drops_iron_or_leather() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var extra := 0
	for i in 400:
		for d: LootDrop in LootTable.roll_enemy(&"rhino_beetle", 2, rng):
			if LootTable.EXTRA_MATERIALS.has(d.id):
				extra += 1
	T.ok(extra > 50 and extra < 110, "about 20%% extra iron or leather (%d/400)" % extra)

func test_unknown_species_drops_nothing() -> void:
	T.ok(LootTable.roll_enemy(&"ghost", 1, RandomNumberGenerator.new()).is_empty())

func test_kill_reports_species_and_summons_report_nothing() -> void:
	# spawn crawler.tscn under a Node2D holder (test_enemy_scaling style),
	# connect run.enemy_killed, kill it: got == [&"slime"].
	# Same with a second crawler whose summoned = true before add_child:
	# got stays [&"slime"] and no PickupItem appears under the holder.

func test_room_spawns_the_floor_roster() -> void:
	# f1_colunas with floor_num = 1, start(0, ...): every enemy's species is
	# in MonsterDB.species_of_floor(1) or is the transitional rhino_beetle.
```

- [ ] **Step 2: Run the tests.** Expected: `FAIL test_monster_db.gd::...` (MonsterDB not found) plus parse failures.

- [ ] **Step 3: Implement.** `MonsterDB` with rows for `slime` (crawler.tscn, floor 1, `mat_old_leather`), `sentinel` (shooter.tscn, floor 1, `mat_iron_ore`), `rhino_beetle` (charger.tscn, floor 2, `mat_beetle_horn`); texts:
  - slime: name "Slime de Esgoto", attack "Persegue e morde depois de piscar em vermelho.", weakness "Rolar na mordida. Ao morrer vira 2 pequenos.", hunter_title "Caçador de Slimes".
  - sentinel: "Sentinela de Pedra", "Atira de longe e recua.", "Correr até ela e rolar no tiro.", "Quebra-Sentinelas".
  - rhino_beetle: "Besouro-Rinoceronte", "Avisa com uma linha e investe.", "Rolar para o lado da investida.", "Caçador de Besouros".
  - `ROSTER` for floors 1, 2 and 3: crawler -> slime, shooter -> sentinel, charger -> rhino_beetle.

  `roll_enemy`: one `randf() < ENEMY_DROP_CHANCE` roll for the species material, then on `floor_num >= 2` one `randf() < EXTRA_DROP_CHANCE` roll picking evenly from `EXTRA_MATERIALS`. Scenes export `species` (crawler `slime`, shooter `sentinel`, charger `rhino_beetle`). `EnemyBase.roll_loot` uses `species`; `_on_died` calls `Game.run.record_kill(species, elite)` unless `summoned` or `species == &""`, and skips `_drop_loot` when `summoned`. `BossFinal.summon` sets `summoned = true`. `Room._spawn` resolves `crawler|shooter|charger` through `MonsterDB.scene_path(kind, floor_num)` (bosses and `base` looks stay in `ENEMY_SCENES`); `Dungeon._go_to_room` sets `room.floor_num = current_floor` before `room.start`. Update the four existing suites to the species API (`test_floors`: the drop is `MonsterDB.material(e.species)` or in `EXTRA_MATERIALS`).

- [ ] **Step 4: Run the tests.** Expected: `PASS N / FAIL 0`.

- [ ] **Step 5: Commit**

```bash
git add game/logic/monster_db.gd game/logic/loot_table.gd game/logic/run_state.gd game/actors game/world/room.gd game/world/dungeon.gd game/world/test_arena.gd game/tests/unit
git commit -m "feat: monstros por espécie e por andar, derrubam o próprio material"
```

### Task 2: Floor 1 monsters (Slime de Esgoto, Toco Vivo, Sentinela de Pedra)

**Files:**
- Create: `game/actors/enemies/stump.gd`, `game/actors/enemies/stump.tscn`
- Modify: `game/actors/enemies/crawler.gd`, `enemy_base.gd`, `game/world/room.gd`, `game/logic/monster_db.gd`
- Test: `game/tests/unit/test_floor1_monsters.gd`

**Interfaces:**
- Consumes: Task 1 (`MonsterDB`, `EnemyBase.species/summoned`, `Room.floor_num`).
- Produces: `EnemyBase.signal spawned(e: EnemyBase)` (a child enemy the room must count), `Room.adopt(e: EnemyBase) -> void`; `Crawler`: `@export var splits: bool = true`, `var small: bool = false`, consts `SPLIT_COUNT := 2`, `SMALL_HP_MULT := 0.35`, `SMALL_DMG_MULT := 0.6`, `SMALL_SCALE := 0.6`; `class_name Stump` with `enum State { DORMANT, RISE, SWEEP, RECOVER, WALK }`, consts `WAKE_RANGE := 54.0`, `RISE_TIME := 0.5`, `SWEEP_TIME := 0.2`, `SWEEP_RADIUS := 27.0`, `RECOVER_TIME := 1.0`, `WALK_SPEED := 33.0`, `SWEEP_RANGE := 30.0`; MonsterDB row `stump` (floor 1, role charger, `mat_ash_wood`), `ROSTER[1][&"charger"] = &"stump"`.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_slime_splits_into_two_small_ones_and_room_waits() -> void:
	# f1_colunas, floor_num 1; kill the first slime in room.enemies.
	# await 2 physics frames.
	T.eq(room.enemies.filter(func(e: EnemyBase) -> bool: return (e as Crawler) != null and (e as Crawler).small).size(), 2)
	T.ok(not room.is_cleared, "the small ones keep the doors shut")
	# small slime: hp == roundi(parent max_hp * Crawler.SMALL_HP_MULT), drops_loot false, species &"slime"
	# killing every enemy (small ones included) clears the room exactly once

func test_small_slime_does_not_split_again() -> void:
	# kill a small slime: no new enemy is adopted

func test_summoned_slime_does_not_split() -> void:
	# crawler.tscn with summoned = true under a holder, kill it:
	# no EnemyBase child appears in the holder after 2 frames

func test_stump_sleeps_until_close_then_sweeps() -> void:
	# Stump under a holder, a Node2D "player" (group &"player") at 120 px.
	# s._think(0.1) x 10 -> state DORMANT, velocity ZERO, hitbox inactive.
	# move the player to 40 px, _think(0.1) -> RISE with telegraph on;
	# after Stump.RISE_TIME -> SWEEP with the hitbox active;
	# after SWEEP_TIME -> RECOVER with the hitbox off.

func test_stump_wakes_when_hit() -> void:
	# DORMANT stump, health.damage(1, ...) -> state RISE

func test_floor_one_roster() -> void:
	T.eq(MonsterDB.species_of_floor(1), [&"slime", &"stump", &"sentinel"] as Array[StringName])
	T.eq(MonsterDB.material(&"stump"), &"mat_ash_wood")
```

- [ ] **Step 2: Run the tests.** Expected: `FAIL test_floor1_monsters.gd::...` (no `Stump`, no split).

- [ ] **Step 3: Implement.** Split in `Crawler._on_died` (before `super()`, so `spawned` fires before `killed`): when `splits and not small and not summoned and drops_loot`, add `SPLIT_COUNT` copies of `crawler.tscn` with `small = true`, `splits = false`, `drops_loot = false`, `gold_drop = 1`, base hp/damage scaled by the small consts, sprite scale `SMALL_SCALE`, placed 8 px to each side, `elite` copied; emit `spawned(child)` for each. `Room._spawn` connects `spawned` to `adopt`, which appends, connects `killed` and increments `_alive` (no fade-in grace). `Stump` stays on idle frame 0 while DORMANT (the disguise), uses a circle hitbox of `SWEEP_RADIUS`, base hp 60, damage 16, gold 4; until Task 7 its scene uses `res://assets/enemies/charger.png`. Stump texts: name "Toco Vivo", attack "Parece um toco. Perto dele, levanta e varre em volta.", weakness "Chegar, recuar e golpear depois da varrida.", hunter_title "Lenhador de Tocos". The sentinel already shoots and backs off: no change beyond its row.

- [ ] **Step 4: Run the tests.** Expected: `PASS N / FAIL 0`.

- [ ] **Step 5: Visual check.** `$GODOT --position 5000,5000 --path game -- --screenshot=res://world/dungeon.tscn --out=/tmp/f1_roster.png --frames=120 --room=res://world/rooms/f1/f1_arena.tscn --floor=1`: slime, stump (still dormant, idle pose) and sentinel spawn; no error in the log.

- [ ] **Step 6: Commit**

```bash
git add game/actors/enemies game/world/room.gd game/logic/monster_db.gd game/tests/unit/test_floor1_monsters.gd
git commit -m "feat: andar 1 com slime que se divide, toco vivo e sentinela"
```

### Task 3: Floor 2 monsters (Esqueleto Mineiro, Besouro-Couraça, Besouro-Rinoceronte)

**Files:**
- Create: `game/actors/enemies/skeleton_miner.gd/.tscn`, `shell_beetle.gd/.tscn`
- Modify: `game/actors/enemies/enemy_base.gd`, `game/logic/monster_db.gd`
- Test: `game/tests/unit/test_floor2_monsters.gd`

**Interfaces:**
- Consumes: Task 1.
- Produces: `EnemyBase.incoming_damage(dmg: int, from: Hitbox) -> int` (virtual, default returns `dmg`; `_on_hit` uses it before `health.damage`); `class_name SkeletonMiner` (`MELEE_RANGE := 24.0`, `SWING_WINDUP := 0.4`, `THROW_MIN := 60.0`, `THROW_MAX := 150.0`, `THROW_INTERVAL := 2.5`, `THROW_AIM := 0.35`, `ROCK_SPEED := 120.0`, `WALK_SPEED := 45.0`, `@export var rocks_per_throw: int = 1`, `ROCK_FAN_DEG := 20.0`); `class_name ShellBeetle` (`SPEED := 40.0`, `BITE_RANGE := 21.0`, `WINDUP_TIME := 0.35`, `OPEN_AFTER_BITE := 1.5`, `SHELL_DAMAGE := 1`, `func is_open() -> bool`); MonsterDB rows `skeleton_miner` (shooter role, `mat_silver_ore`), `shell_beetle` (crawler role, `mat_chitin`); `ROSTER[2] = {crawler: shell_beetle, shooter: skeleton_miner, charger: rhino_beetle}`.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_shell_beetle_blocks_front_hits() -> void:
	# beetle facing right (face(Vector2.RIGHT)), a player Hitbox (team &"player", damage 20)
	# placed to its right: incoming_damage == ShellBeetle.SHELL_DAMAGE
	# same hitbox placed to its left (behind): incoming_damage == 20

func test_shell_beetle_open_after_biting() -> void:
	# drive _think through a bite; right after it is_open() is true and a
	# front hit deals full damage; after OPEN_AFTER_BITE + 0.1 s it is closed again

func test_skeleton_miner_swings_close_and_throws_far() -> void:
	# player at 20 px: after SWING_WINDUP the hitbox is active
	# player at 100 px: after THROW_INTERVAL + THROW_AIM a Projectile is added to the parent
	# rocks_per_throw = 3: three Projectiles, directions ROCK_FAN_DEG apart

func test_floor_two_roster_and_drops() -> void:
	T.eq(MonsterDB.species_of_floor(2), [&"shell_beetle", &"skeleton_miner", &"rhino_beetle"] as Array[StringName])
	T.eq(MonsterDB.material(&"skeleton_miner"), &"mat_silver_ore")
	T.eq(MonsterDB.material(&"shell_beetle"), &"mat_chitin")
```

- [ ] **Step 2: Run the tests.** Expected: FAIL (classes missing).

- [ ] **Step 3: Implement.** Front = the hitbox's position is on the side the sprite faces (`sprite.flip_h`), within 90 degrees. Base stats: skeleton miner hp 70, damage 18, gold 6; shell beetle hp 80, damage 16, gold 5. Until Task 8 the scenes use `crawler.png` (shell beetle) and `shooter.png` (miner). Rows:
  - skeleton_miner: "Esqueleto Mineiro", "Golpeia com a picareta de perto e joga pedra de longe.", "Ficar a meia distância e rolar na pedra.", "Caçador de Esqueletos".
  - shell_beetle: "Besouro-Couraça", "Morde devagar. De frente, fecha a carapaça.", "Bater por trás ou logo depois da mordida.", "Abre-Couraças".

- [ ] **Step 4: Run the tests.** Expected: `PASS N / FAIL 0`.

- [ ] **Step 5: Visual check.** Same screenshot command with `--room=res://world/rooms/f2/f2_nave.tscn --floor=2 --out=/tmp/f2_roster.png`: the three floor 2 species spawn.

- [ ] **Step 6: Commit**

```bash
git add game/actors/enemies game/logic/monster_db.gd game/tests/unit/test_floor2_monsters.gd
git commit -m "feat: andar 2 com esqueleto mineiro e besouros"
```

### Task 4: Floor 3 monsters (Salamandra de Brasa, Golem de Obsidiana, Espectro)

**Files:**
- Create: `game/actors/enemies/salamander.gd/.tscn`, `golem.gd/.tscn`, `specter.gd/.tscn`, `game/world/ember_patch.gd`
- Modify: `game/logic/monster_db.gd`
- Test: `game/tests/unit/test_floor3_monsters.gd`

**Interfaces:**
- Consumes: Task 1; `Shockwave` (`actors/bosses/shockwave.gd`, `trigger()`, `max_radius`, `warn_time`).
- Produces: `class_name Salamander` (`KEEP_MIN := 50.0`, `KEEP_MAX := 70.0`, `JET_WINDUP := 0.5`, `JET_TIME := 0.4`, `JET_LENGTH := 48.0`, `JET_WIDTH := 14.0`, `@export var embers_per_jet: int = 1`, `@export var jet_length_mult: float = 1.0`); `class_name EmberPatch extends Hitbox` (`LIFE := 3.0`, `DAMAGE := 6`, team enemy, frees itself after `LIFE`); `class_name Golem` (`SPEED := 30.0`, `SLAM_RANGE := 40.0`, `SLAM_WINDUP := 0.9`, `SLAM_RADIUS := 26.0`, `WAVE_RADIUS := 72.0`); `class_name Specter` (`SPEED := 55.0`, `BLINK_INTERVAL := 4.0`, `FADE_TIME := 0.4`, `BEHIND_DIST := 28.0`, `CLAW_WINDUP := 0.35`); rows `salamander` (shooter role, `mat_coal`), `golem` (charger role, `mat_obsidian`), `specter` (crawler role, `mat_specter_cloth`); `ROSTER[3] = {crawler: specter, shooter: salamander, charger: golem}`.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_salamander_jet_leaves_ember() -> void:
	# player 60 px away; drive _think past JET_WINDUP + JET_TIME:
	# exactly embers_per_jet EmberPatch nodes in the parent, team &"enemy";
	# with embers_per_jet = 3 there are 3

func test_ember_patch_expires() -> void:
	# add an EmberPatch, step physics EmberPatch.LIFE + 0.1 s: freed

func test_golem_slam_sends_wave() -> void:
	# player at 30 px: after SLAM_WINDUP the hitbox is active and its Shockwave was triggered

func test_specter_blinks_behind_the_player() -> void:
	# player at (100, 100) facing RIGHT (set_meta or a Player stub with `facing`),
	# specter at (40, 100); drive _think past BLINK_INTERVAL + FADE_TIME:
	T.near(specter.global_position.distance_to(Vector2(100 - Specter.BEHIND_DIST, 100)), 0.0, 1.0)
	# while faded its hurtbox is not monitorable

func test_floor_three_roster() -> void:
	T.eq(MonsterDB.species_of_floor(3), [&"specter", &"salamander", &"golem"] as Array[StringName])
```

- [ ] **Step 2: Run the tests.** Expected: FAIL.

- [ ] **Step 3: Implement.** The specter reads the player's `facing` when the node has it, else appears on the far side from itself. Base stats: salamander hp 55, damage 14, gold 6; golem hp 140, damage 22, gold 8; specter hp 50, damage 18, gold 6. Placeholder sheets until Task 9: shooter.png, charger.png, crawler.png. Rows:
  - salamander: "Salamandra de Brasa", "Cospe fogo curto e deixa brasa no chão.", "Sair da brasa e bater entre os jatos.", "Apaga-Salamandras".
  - golem: "Golem de Obsidiana", "Lento. Bate no chão e solta uma onda.", "Rolar através da onda.", "Quebra-Golens".
  - specter: "Espectro", "Some e aparece atrás de você.", "Virar e rolar quando ele sumir.", "Caçador de Espectros".

- [ ] **Step 4: Run the tests.** Expected: `PASS N / FAIL 0`.

- [ ] **Step 5: Visual check.** Screenshot `--room=res://world/rooms/f3/f3_forja.tscn --floor=3 --frames=240 --out=/tmp/f3_roster.png`: the three species spawn; an ember patch is drawn after a jet.

- [ ] **Step 6: Commit**

```bash
git add game/actors/enemies game/world/ember_patch.gd game/logic/monster_db.gd game/tests/unit/test_floor3_monsters.gd
git commit -m "feat: andar 3 com salamandra, golem e espectro"
```

### Task 5: Elites

**Files:**
- Create: `game/actors/enemies/elite_outline.gdshader`
- Modify: `game/actors/enemies/enemy_base.gd`, `game/world/room.gd`, `game/world/dungeon.gd` (debug `--elite`), `game/logic/loot_table.gd`
- Test: `game/tests/unit/test_elites.gd`

**Interfaces:**
- Consumes: Tasks 1-4.
- Produces: `Room.ELITE_CHANCE := 0.08`; `EnemyBase.ELITE_HP_MULT := 1.8`, `ELITE_DMG_MULT := 1.3`, `ELITE_SCALE := 1.25`, `ELITE_GOLD_MULT := 2`, `ELITE_OUTLINE := Color(1.0, 0.82, 0.3)`; `LootTable.ELITE_RELIC_CHANCE := 0.25`; `LootTable.roll_enemy(species, floor_num, rng, elite: bool = false, clock_level: int = 0)`; `Room._spawn(kind: String, pos: Vector2, base: String, elite: bool = false)`; Dungeon debug `--elite` makes every eligible spawn elite.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_elite_stats() -> void:
	# crawler.tscn with elite = true before add_child, clock level 0:
	T.eq(e.health.max_hp, roundi(base_hp * EnemyBase.ELITE_HP_MULT))
	T.eq(e.hitbox.damage, roundi(base_damage * EnemyBase.ELITE_DMG_MULT))
	T.eq(e.gold_amount(), roundi(gold_drop * EnemyBase.ELITE_GOLD_MULT))
	T.ok(e.sprite.material is ShaderMaterial, "gold outline")

func test_elite_drops_double_and_may_drop_a_relic() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var relics := 0
	for i in 400:
		for d: LootDrop in LootTable.roll_enemy(&"slime", 1, rng, true):
			if ItemDB.kind(d.id) == &"material":
				T.eq(d.qty, 2, "double material")
			elif ItemDB.kind(d.id) == &"relic":
				relics += 1
	T.ok(relics > 70 and relics < 130, "about 25%% relics (%d/400)" % relics)

func test_elite_rate_in_a_normal_room() -> void:
	# 200 x f1_arena start(0, ...) with seeded rngs: elite share between 3% and 14%

func test_no_elites_in_tutorial_boss_or_summons() -> void:
	# start t1_move_attack and boss_f1 200 times each (seeds 0..199):
	# no enemy has elite == true. BossFinal.summon() children: elite false.
```

- [ ] **Step 2: Run the tests.** Expected: FAIL.

- [ ] **Step 3: Implement.** `Room._spawn` rolls `rng.randf() < ELITE_CHANCE` only when `not is_boss and not is_tutorial`; the roll uses the room rng passed to `start` (store it). `EnemyBase._ready` applies the multipliers when `elite`, scales `sprite` and `hurtbox` by `ELITE_SCALE`, and sets a `ShaderMaterial` with the outline shader (1 px outline in `ELITE_OUTLINE` where alpha is 0 next to an opaque pixel). `roll_loot` passes `elite` and the clock level; the elite relic is `LootTable._gear(&"relic", roll_rarity(floor_num, clock_level, rng), rng)`.

- [ ] **Step 4: Run the tests.** Expected: `PASS N / FAIL 0`.

- [ ] **Step 5: Visual check.** Screenshot `--room=res://world/rooms/f1/f1_arena.tscn --floor=1 --elite --out=/tmp/elites.png --frames=120`: each enemy is bigger with a clean 1 px gold outline, no outline gaps on the death row.

- [ ] **Step 6: Commit**

```bash
git add game/actors/enemies game/world/room.gd game/world/dungeon.gd game/logic/loot_table.gd game/tests/unit/test_elites.gd
git commit -m "feat: elites com contorno dourado, dobro de loot e chance de relíquia"
```

### Task 6: Named rares (Rei Gosma, Velho Picareta, Brasa Viva)

**Files:**
- Create: `game/actors/enemies/rare_mark.gd`, `king_slime.tscn`, `old_pickaxe.tscn`, `living_ember.tscn`
- Modify: `enemy_base.gd`, `crawler.gd` (summon interval), `game/logic/monster_db.gd`, `game/logic/floor_plan.gd`, `game/logic/floor_state.gd`, `game/logic/loot_table.gd`, `game/world/room.gd`, `game/world/dungeon.gd` (debug `--rare`), `game/ui/hud.gd`
- Test: `game/tests/unit/test_rares.gd`

**Interfaces:**
- Consumes: Tasks 1-5; `SpeechBubble`.
- Produces: `class_name RareMark extends Node` with `signal boss_hp(hp: int, max_hp: int)`, `@export var rare_id: StringName`, `func bind(health: Health) -> void`; `EnemyBase.RARE_HP_MULT := 6`, `RARE_GOLD_MULT := 6`, `func is_rare() -> bool`; `Crawler.@export var summon_interval: float = 0.0`, `SUMMON_MAX := 4`; `MonsterDB.RARES: Dictionary[int, StringName] = {1: &"king_slime", 2: &"old_pickaxe", 3: &"living_ember"}`, `MonsterDB.RARE_CHANCE := 0.10`, `MonsterDB.is_rare(species) -> bool`; `FloorPlan.rare_room(plan_size: int, tutorial_count: int, rng: RandomNumberGenerator) -> int` (-1 or an index of a random room); `FloorState.FloorRecord.rare_room: int = -1`; `Room.start(extra, has_chest, rng, save = null, has_back = false, rare: StringName = &"")`; `LootTable.roll_rare(species: StringName, rng: RandomNumberGenerator) -> Array[LootDrop]`, `RARE_EPIC_CHANCE := 0.3`, `RARE_MATERIALS := 3`.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_rare_room_chance_and_range() -> void:
	# 1000 seeded FloorPlan.rare_room(7, 2, rng) calls: 60..140 return an index,
	# every index is in [2, 5] (never a tutorial room, never the boss at 6)

func test_rare_never_in_tutorial_or_boss_room() -> void:
	# t1_move_attack.start(0, false, rng, null, false, &"king_slime"): no enemy is_rare()
	# boss_f1 the same: no enemy is_rare()

func test_rare_spawns_with_mini_boss_life_and_line() -> void:
	# f1_arena.start(0, false, rng, null, false, &"king_slime"):
	# one enemy with is_rare(), species &"king_slime",
	# max_hp == roundi(base_hp * EnemyBase.RARE_HP_MULT), in group &"rare"

func test_rare_loot_guarantees_rare_or_epic_relic() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for i in 100:
		var drops := LootTable.roll_rare(&"king_slime", rng)
		var relics := drops.filter(func(d: LootDrop) -> bool: return ItemDB.kind(d.id) == &"relic")
		T.eq(relics.size(), 1)
		T.ok(ItemDB.rarity(relics[0].id) in [&"rare", &"epic"])
		T.ok(drops.any(func(d: LootDrop) -> bool: return d.id == &"mat_old_leather" and d.qty == LootTable.RARE_MATERIALS))

func test_king_slime_calls_small_slimes_up_to_cap() -> void:
	# king slime in a room, player stub near: after summon_interval * 3 s of _think,
	# adopted small slimes alive <= Crawler.SUMMON_MAX

func test_hud_shows_rare_bar_with_name() -> void:
	# hud + king slime in tree: hud.boss_box.visible and hud.boss_label.text == "Rei Gosma"
```

- [ ] **Step 2: Run the tests.** Expected: FAIL.

- [ ] **Step 3: Implement.** Rare scenes instance their base species scene (crawler.tscn, skeleton_miner.tscn, salamander.tscn) with a `RareMark` child, `species` set to the rare id, sprite scale 1.67 until the 40 px art, and the tweaks `summon_interval = 5.0` (king slime), `rocks_per_throw = 3` (old pickaxe), `embers_per_jet = 3` and `jet_length_mult = 1.5` (living ember). `EnemyBase._ready` finds `RareMark`, applies `RARE_HP_MULT` and `RARE_GOLD_MULT`, joins group `&"rare"`, binds the mark and shows a `SpeechBubble` with the row's `line` for 2.5 s. Rares never split (`splits = false`) and are stun-immune like bosses. `Dungeon._build_floor` stores `rec.rare_room`; `_go_to_room` passes `MonsterDB.RARES[current_floor]` when `index == rec.rare_room` and the room save is not cleared. `Room.start` spawns the rare at the far marker furthest from the entry, only when `not is_boss and not is_tutorial`. HUD: `boss` falls back to the first `RareMark` in group `&"rare"`, name from `MonsterDB.display_name`. Rows (`floor`, `role` `&"rare"`, `material`, `attack`, `weakness`, `title`, `line`):
  - king_slime: 1, `mat_old_leather`, "Persegue e chama slimes pequenos.", "Matar os pequenos primeiro.", "Destronador do Rei Gosma", "Meu esgoto, minhas regras!"
  - old_pickaxe: 2, `mat_silver_ore`, "Joga três pedras em leque.", "Rolar para dentro do leque.", "Aposentador do Velho Picareta", "Essa prata é minha. Cava a tua!"
  - living_ember: 3, `mat_coal`, "Jato longo que deixa três brasas.", "Bater pelas costas entre os jatos.", "Apagador da Brasa Viva", "Chega mais perto. Eu esquento."

- [ ] **Step 4: Run the tests.** Expected: `PASS N / FAIL 0`.

- [ ] **Step 5: Visual check.** Screenshot `--room=res://world/rooms/f1/f1_arena.tscn --floor=1 --rare --frames=90 --out=/tmp/rare_f1.png`: the Rei Gosma bubble reads in full, the bottom bar shows "Rei Gosma".

- [ ] **Step 6: Commit**

```bash
git add game/actors/enemies game/logic game/world game/ui/hud.gd game/tests/unit/test_rares.gd
git commit -m "feat: raros com nome, fala, vida de mini-chefe e relíquia garantida"
```

### Task 7: Floor 1 monster art

**Files:**
- Create: `art-src/gen/r3/enemy24-slime-sheet-1.png`, `enemy24-stump-sheet-1.png`, `enemy40-king-slime-sheet-1.png` (downloads), `art-src/preview_monsters.py`, `game/assets/enemies/stump.png`, `king_slime.png`
- Modify: `art-src/build_enemies.py` (new names and the 40 px size, ground row 37), `art-src/check_art.py` (40 px ground line), `game/assets/enemies/crawler.png` (rebuilt with `--force`), `stump.tscn`, `king_slime.tscn`, `docs/assets.md`
- Test: `game/tests/unit/test_monster_art.gd`

**Interfaces:**
- Produces: `test_monster_art.gd::_check_sheet(path: String, cell: int)` helper reused by Tasks 8 and 9.

- [ ] **Step 1: Write the failing test**

```gdscript
func test_floor1_sheets_exist_and_fit_the_grid() -> void:
	_check_sheet("res://assets/enemies/crawler.png", 24)
	_check_sheet("res://assets/enemies/stump.png", 24)
	_check_sheet("res://assets/enemies/shooter.png", 24)
	_check_sheet("res://assets/enemies/king_slime.png", 40)
	# _check_sheet: ResourceLoader.exists, size == Vector2(6 * cell, 4 * cell)

func test_scenes_use_their_sheets() -> void:
	# stump.tscn Sprite texture path ends with "stump.png"; king_slime.tscn with "king_slime.png"
```

- [ ] **Step 2: Run the test.** Expected: FAIL (`stump.png` missing).

- [ ] **Step 3: Generate.** AI generator `generate_styled_image`, preset `cinzel-pixel`, role `characters`, project `asset-gen`, 6x4 pose grid (idle, move, attack, death) on flat magenta, side view facing right, town key art as style reference: `cinzel-enemy24-slime-sheet` (edit of the current crawler: sewer slime, grey-green, scraps of brown old leather inside in the `mat_old_leather` icon colours), `cinzel-enemy24-stump-sheet` (ash stump with root legs and two branch arms, pale ash wood of the `mat_ash_wood` icon; idle row looks like a plain stump), `cinzel-enemy40-king-slime-sheet` (bigger slime with a crude crown of rusted iron). The sentinel keeps `shooter.png` if its preview passes the icon check, else regenerate as `cinzel-enemy24-sentinel-sheet` with iron-ore veins. Download with `fetch_gen.py` to `art-src/gen/r3/`.

- [ ] **Step 4: Build.** Point `stump.tscn` at `stump.png` and `king_slime.tscn` at `king_slime.png` with `frame_size = 40` and sprite scale 1 (Tasks 8 and 9 do the same for their rares). Add the sheets to `build_enemies.py`, run `python3 -I art-src/build_enemies.py . --force crawler stump king_slime`, then `check_art.py`. `preview_monsters.py` writes `/tmp/monsters_f1.png`: each species' idle frame 1 at 4x next to its material icon at 4x.

- [ ] **Step 5: Run the tests.** Expected: `PASS N / FAIL 0`.

- [ ] **Step 6: Visual check.** Read `/tmp/monsters_f1.png` (material colours visible on each monster) and screenshot `--room=res://world/rooms/f1/f1_arena.tscn --floor=1 --rare --frames=120 --out=/tmp/f1_art.png`: monsters read on the painted floor, feet on the ground line, no magenta fringe.

- [ ] **Step 7: Commit** (rows added to `docs/assets.md` for every new file and generation)

```bash
git add art-src/gen/r3 art-src/build_enemies.py art-src/check_art.py art-src/preview_monsters.py game/assets/enemies game/actors/enemies/stump.tscn game/actors/enemies/king_slime.tscn docs/assets.md game/tests/unit/test_monster_art.gd
git commit -m "arte: slime de esgoto, toco vivo e rei gosma"
```

### Task 8: Floor 2 monster art

Same steps and commands as Task 7, for `skeleton_miner.png` (24 px; pickaxe, a lump of `mat_silver_ore` on the belt), `shell_beetle.png` (24 px; plated shell in the `mat_chitin` icon colours, a visibly closed-shell pose in the attack row's first frame), `charger.png` rebuilt as the rhino beetle (edit of the current charger with one big horn in the `mat_beetle_horn` colours) and `old_pickaxe.png` (40 px, bent old skeleton, bigger pick, miner's lamp). Test `test_floor2_sheets_exist_and_fit_the_grid` in `test_monster_art.gd`; screenshot `--room=res://world/rooms/f2/f2_nave.tscn --floor=2 --rare`; preview `/tmp/monsters_f2.png`.

- [ ] **Step 1: Failing test** (`_check_sheet` for the four sheets, scene textures).
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Generate** (`cinzel-enemy24-skeleton-miner-sheet`, `cinzel-enemy24-shell-beetle-sheet`, `cinzel-enemy24-rhino-beetle-sheet`, `cinzel-enemy40-old-pickaxe-sheet`).
- [ ] **Step 4: Build and check_art.**
- [ ] **Step 5: Run tests.** Expected: `PASS N / FAIL 0`.
- [ ] **Step 6: Visual check** (preview and screenshot as in Task 7).
- [ ] **Step 7: Commit**

```bash
git add art-src/gen/r3 art-src/build_enemies.py game/assets/enemies game/actors/enemies docs/assets.md game/tests/unit/test_monster_art.gd
git commit -m "arte: esqueleto mineiro, besouros e velho picareta"
```

### Task 9: Floor 3 monster art

Same as Task 7 for `salamander.png` (24 px; ember-orange belly in the `mat_coal` icon colours), `golem.png` (24 px; black glassy `mat_obsidian` body with cracks), `specter.png` (24 px; ragged cloth of the `mat_specter_cloth` icon, a faded frame in the move row for the blink) and `living_ember.png` (40 px). Test `test_floor3_sheets_exist_and_fit_the_grid`; screenshot `--room=res://world/rooms/f3/f3_forja.tscn --floor=3 --rare --elite --out=/tmp/f3_art.png` also checks the elite outline on every new sheet.

- [ ] **Step 1: Failing test.**
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Generate** (`cinzel-enemy24-salamander-sheet`, `cinzel-enemy24-golem-sheet`, `cinzel-enemy24-specter-sheet`, `cinzel-enemy40-living-ember-sheet`).
- [ ] **Step 4: Build and check_art.**
- [ ] **Step 5: Run tests.** Expected: `PASS N / FAIL 0`.
- [ ] **Step 6: Visual check.**
- [ ] **Step 7: Commit**

```bash
git add art-src/gen/r3 art-src/build_enemies.py game/assets/enemies game/actors/enemies docs/assets.md game/tests/unit/test_monster_art.gd
git commit -m "arte: salamandra, golem, espectro e brasa viva"
```

### Task 10: QA robot for the new monsters and monster balance

**Files:**
- Modify: `game/actors/enemies/enemy_base.gd`, `game/tools/qa_autopilot.gd`, enemy `.tscn` base values as measured, `docs/balance.md`

**Interfaces:**
- Produces: `EnemyBase.is_telegraphing() -> bool`; autopilot RESULT line gains `elites=<n> rares=<n>`.

- [ ] **Step 1: Write the failing test** in `game/tests/unit/test_elites.gd`

```gdscript
func test_telegraph_is_readable() -> void:
	# crawler under a holder: is_telegraphing() false; set_telegraph(true) -> true
```

- [ ] **Step 2: Run.** Expected: FAIL. **Step 3:** add `is_telegraphing`; in `_dodge`, after the specific branches, roll perpendicular to any other `EnemyBase` that is telegraphing within 56 px (same `_reacts` reaction-time rule); `_source_name` names enemies by `species`. **Step 4: Run tests.** Expected: `PASS N / FAIL 0`.

- [ ] **Step 5: Balance runs.** `$GODOT --headless --fixed-fps 60 --path game -s res://tools/run_node.gd -- --node=res://tools/qa_autopilot.gd --mode=win --skill=0.8` 10 times, and `--floors=3` 5 times. Targets: floor 1 wins 8/10 or better at `--skill=0.8`, `--no-dodge` still loses floor 1; per floor, no single species causes over half the deaths; every win ends with materials for at least one recipe. Change only `base_hp`/`base_damage` in the scenes; record before/after tables in a new `docs/balance.md` section "Monstros por andar (15/11)".

- [ ] **Step 6: Commit**

```bash
git add game/actors/enemies game/tools/qa_autopilot.gd docs/balance.md game/tests/unit/test_elites.gd
git commit -m "teste: robô de QA rola nos avisos dos monstros novos; balanço dos andares"
```

### Task 11: Mastery core (XP, levels, bonuses, death reset)

**Files:**
- Create: `game/logic/mastery.gd`
- Modify: `game/logic/run_state.gd`, `game/logic/player_stats.gd`, `game/actors/common/hitbox.gd`, `game/actors/common/hurtbox.gd`, `game/actors/enemies/enemy_base.gd`, `game/actors/player/player.gd`, `player_arrow.gd`, `player_blast.gd`, `game/autoload/game.gd` (debug `--mastery=spear:6,roll:5`)
- Test: `game/tests/unit/test_mastery.gd`

**Interfaces:**
- Consumes: `RunState.equipment.dual_active()`.
- Produces:
  - `class_name Mastery`: `STYLES: Array[StringName] = [&"sword", &"longsword", &"axe", &"spear", &"dagger", &"bow", &"roll", &"heal", &"dual"]`; `STYLE_NAME: Dictionary[StringName, String]` ("Espada", "Espada Longa", "Machado", "Lança", "Adaga", "Arco", "Rolamento", "Cura", "Lâminas Gêmeas"); `MAX_LEVEL := 10`; `XP_TO_REACH: Array[int] = [0, 400, 1200, 1600, 2000, 2400, 3100, 3800, 4600, 5400]` (total XP for levels 1..10); `DODGE_XP := 30`; `ROLL_XP := 3`; `HEAL_XP_PER_HP := 2.0`; `WEAPON_DMG_PER_LEVEL := 0.03`; `WEAPON_SPEED_PER_LEVEL := 0.01`; `ROLL_DIST_PER_LEVEL := 0.02`; `ROLL_IFRAME_LEVELS: Array[int] = [5, 10]`; `ROLL_IFRAME_STEP := 0.05`; `HEAL_RATE_PER_LEVEL := 0.04`; `HEAL_DELAY_PER_LEVEL := 0.05`; `MIN_HEAL_DELAY := 0.3`; `TIER_LEVELS: Array[int] = [1, 3, 6]`.
  - `var xp: Dictionary[StringName, int]`; `func level(style: StringName) -> int`; `func progress(style: StringName) -> float` (0..1 to the next level, 1 at max); `func add(style: StringName, amount: int) -> int` (the new level when it rose, else 0); `static func tiers(level: int) -> int`; `func bonus_text(style: StringName) -> String`.
  - `RunState`: `var mastery: Mastery`; `signal mastery_up(style: StringName, level: int)`; `func add_mastery_xp(style: StringName, amount: float) -> void` (emits `mastery_up` and `changed` only on a level-up); `func mastery_style() -> StringName` (`&"dual"` when `equipment.dual_active()`, else the weapon type); `stats()` returns `PlayerStats.from_equipment(equipment, self)`.
  - `PlayerStats.from_equipment(eq: Equipment, run: RunState = null) -> PlayerStats`; new field `roll_iframes: float = 0.3`.
  - `Hitbox.style: StringName = &""` (set by the player on its hitbox, arrows and blasts); `Hurtbox.signal dodged(hitbox: Hitbox)` (emitted once per hitbox per invulnerable stretch when an other-team hit is rejected).

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_levels_follow_the_curve() -> void:
	var m := Mastery.new()
	T.eq(m.level(&"spear"), 1)
	T.eq(m.add(&"spear", 399), 0)
	T.eq(m.add(&"spear", 1), 2)
	m.add(&"spear", 100000)
	T.eq(m.level(&"spear"), Mastery.MAX_LEVEL)
	T.near(m.progress(&"spear"), 1.0)
	T.eq(Mastery.tiers(2), 1)
	T.eq(Mastery.tiers(3), 2)
	T.eq(Mastery.tiers(6), 3)

func test_weapon_bonus_applies_to_its_style_only() -> void:
	# run with sword_iron, mastery sword at level 4 (add XP_TO_REACH[3]):
	T.eq(run.stats().damage, roundi(10 * (1.0 + 3 * Mastery.WEAPON_DMG_PER_LEVEL)))
	T.near(run.stats().attack_speed_mult, 1.0 * (1.0 + 3 * Mastery.WEAPON_SPEED_PER_LEVEL))
	# equip spear_hunter: damage back to the spear's catalog 12

func test_roll_and_heal_bonuses() -> void:
	# roll level 5: roll_distance == 54 * (1 + 4 * 0.02) * roll_speed_mult, roll_iframes == 0.35
	# roll level 10: roll_iframes == 0.40
	# heal level 10: heal_per_sec == 6 * (1 + 9 * 0.04), heal_delay == maxf(0.3, 1.5 - 9 * 0.05)

func test_damage_dealt_gives_weapon_xp() -> void:
	# enemy (crawler.tscn) with 45 hp hit by a Hitbox(team player, damage 60, style &"sword"):
	T.eq(run.mastery.xp[&"sword"], 45, "only the hp it really lost")

func test_summon_hits_give_no_mastery() -> void:
	# same with summoned = true: xp.get(&"sword", 0) == 0, no enemy_killed emitted

func test_hazard_dodge_counts_once_per_roll() -> void:
	# player.tscn in tree, start a roll (player._start_roll(Vector2.RIGHT));
	# an EmberVent-like enemy Hitbox overlapping, receive() called on 5 frames:
	T.eq(run.mastery.xp[&"roll"], Mastery.ROLL_XP + Mastery.DODGE_XP)
	# a second roll through the same hitbox adds ROLL_XP + DODGE_XP again

func test_heal_xp_only_in_tower() -> void:
	# player armed = false (town), hp 50/100, idle 5 s of _update_heal: xp.get(&"heal", 0) == 0
	# armed = true, same: xp[&"heal"] == roundi(healed * Mastery.HEAL_XP_PER_HP)

func test_level_up_signal_and_death_reset() -> void:
	# connect mastery_up; add_mastery_xp(&"bow", 400) -> one emit (&"bow", 2)
	# run.die(): run.mastery.level(&"bow") == 1, outfits and tutorial_done untouched
```

- [ ] **Step 2: Run the tests.** Expected: FAIL (`Mastery` missing).

- [ ] **Step 3: Implement.** Bonuses use `level - 1`. Weapon XP: `EnemyBase._on_hit` calls `Game.run.add_mastery_xp(from.style, dealt)` when `from.team == &"player"`, `from.style != &""` and not `summoned`. The player sets `hitbox.style = Game.run.mastery_style()` in `_set_weapon` and passes it to every `PlayerArrow` and `PlayerBlast` it makes. Roll: `_start_roll` adds `ROLL_XP` when `armed`; a dict of dodged hitbox instance ids, cleared at each roll start, gives `DODGE_XP` per new hitbox while `state == State.ROLL`. Heal: `_update_heal` gives `(hp_after - hp_before) * HEAL_XP_PER_HP` when `armed`. Player uses `_stats.roll_iframes` instead of `ROLL_IFRAMES`. `die()` makes a new `Mastery`. Debug `--mastery=<style>:<level>,...` sets XP to `XP_TO_REACH[level - 1]`.

- [ ] **Step 4: Run the tests.** Expected: `PASS N / FAIL 0`.

- [ ] **Step 5: Commit**

```bash
git add game/logic/mastery.gd game/logic/run_state.gd game/logic/player_stats.gd game/actors game/autoload/game.gd game/tests/unit/test_mastery.gd
git commit -m "feat: maestria por uso, com bônus por nível e zerada na morte"
```

### Task 12: Mastery UI (level-up notice and "Maestria" tab)

**Files:**
- Create: `game/ui/mastery_notice.gd`, `game/ui/mastery_tab.gd`, `game/assets/audio/sfx/level_up.ogg`
- Modify: `game/ui/hud.gd`, `game/ui/inventory_screen.gd`, `game/autoload/sfx.gd` (`IDS` gains `&"level_up"`), `docs/assets.md`
- Test: `game/tests/unit/test_mastery_ui.gd`

**Interfaces:**
- Consumes: Task 11 (`RunState.mastery_up`, `Mastery.level/progress/bonus_text/STYLE_NAME`).
- Produces: `class_name MasteryNotice extends Control` with `func show_level(style: StringName, level: int) -> void` and `var text: String`; `class_name MasteryTab extends VBoxContainer` with `var rows: Array[Control]`; `InventoryScreen.tab: StringName` (`&"bag"` | `&"mastery"`), `func select_tab(t: StringName) -> void`.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_notice_reads_style_and_level() -> void:
	# hud in tree; run.add_mastery_xp(&"spear", 1200)
	T.eq(hud.mastery_notice.text, "Lança 3")
	T.ok(hud.mastery_notice.visible)

func test_mastery_tab_lists_eight_styles_and_dual_when_unlocked() -> void:
	# InventoryScreen, select_tab(&"mastery"): tab.rows.size() == 8
	# run.set_dual_blades(true), refresh: 9 rows, last one "Lâminas Gêmeas"
	# a row shows "Nível 4", a progress bar value == mastery.progress, and bonus_text
```

- [ ] **Step 2: Run.** Expected: FAIL.

- [ ] **Step 3: Implement.** The notice sits under the top-centre of the HUD for 1.6 s: plaque with "<Estilo> <nível>", behind it a radial light (12 additive rays drawn in `_draw`, rotating slowly and fading out, in `UiKit.COLOR_ITEM`), plus `Sfx.play(&"level_up")`. Sound: AI generator `generate_sfx`, project `asset-gen`, name `cinzel-sfx-level-up`, short bright metallic chime, then ffmpeg as the other sfx (trim at -50 dB, peak -3 dB, Ogg Vorbis). Backpack: two tab buttons "Mochila" | "Maestria" over the existing layout; the Maestria tab shows one row per style: name, "Nível N", a 60 px bar, `bonus_text`.

- [ ] **Step 4: Run tests.** Expected: `PASS N / FAIL 0`.

- [ ] **Step 5: Visual check.** `--screenshot=res://world/dungeon.tscn --room=res://world/rooms/f1/f1_arena.tscn --notice=spear:3 --frames=20 --out=/tmp/notice.png` (debug `--notice=<style>:<level>` in `Hud._ready` calls `show_level` once) and `--screenshot=res://world/town.tscn --inventory --tab=mastery --mastery=sword:4,roll:2 --out=/tmp/mastery_tab.png` (add `--tab` to `PauseMenu._debug_inventory`): rays visible behind the plaque; the tab fits the panel, no clipped text.

- [ ] **Step 6: Commit**

```bash
git add game/ui game/autoload/sfx.gd game/assets/audio/sfx/level_up.ogg docs/assets.md game/tests/unit/test_mastery_ui.gd
git commit -m "feat: aviso de nível de maestria e aba Maestria na mochila"
```

### Task 13: Special tiers in the hold-to-charge

**Files:**
- Modify: `game/logic/special_charge.gd`, `game/actors/player/player.gd`, `game/actors/player/weapon_fx.gd`, `game/ui/special_icon.gd`, `game/ui/hud.gd`
- Test: `game/tests/unit/test_special_charge.gd`

**Interfaces:**
- Consumes: `Mastery.tiers(level)`, `RunState.mastery_style()`.
- Produces: `SpecialCharge.TIER_STEP := 0.5`, `TIER_COOLDOWN: Array[float] = [4.0, 7.0, 10.0]`, `var tiers: int = 1`, `var cooldowns: Array[float] = [0.0, 0.0, 0.0]`, `var fired_tier: int = 0`, `cooldown` becomes a property over `cooldowns[0]` (old callers keep working), `func tier_hold(tier: int) -> float` (`special_hold + TIER_STEP * (tier - 1)`), `func is_tier_ready(tier: int) -> bool`, `func cooldown_ratio(tier: int = 1) -> float`, `func refund(seconds: float) -> void` (all tiers), `func refund_ratio(r: float) -> void` (each tier by `r * TIER_COOLDOWN[i]`); `Player._start_special(tier: int = 1)`; `SpecialIcon.set_tiers(unlocked: int, ready: Array[bool])`.

- [ ] **Step 1: Write the failing tests** (added to the existing suite; the old ones stay unchanged)

```gdscript
func test_longer_hold_fires_higher_unlocked_tier() -> void:
	var c := SpecialCharge.new()
	c.tiers = 3
	c.press()
	c.tick(1.55, true)
	T.eq(c.tick(0.0, false), SpecialCharge.SPECIAL)
	T.eq(c.fired_tier, 3)
	T.near(c.cooldowns[2], 10.0)
	T.near(c.cooldowns[0], 0.0, 0.001)

func test_locked_tier_falls_back() -> void:
	var c := SpecialCharge.new()
	c.tiers = 2
	c.press()
	c.tick(2.0, true)
	c.tick(0.0, false)
	T.eq(c.fired_tier, 2)

func test_tier_on_cooldown_falls_to_lower_ready_one() -> void:
	# tiers 3, fire tier 3, then hold 1.6 s again: fired_tier == 2

func test_bow_tiers_start_at_one_second() -> void:
	var c := SpecialCharge.new(1.0, 0.5)
	c.tiers = 3
	T.near(c.tier_hold(2), 1.5)
	T.near(c.tier_hold(3), 2.0)

func test_player_tiers_follow_mastery() -> void:
	# player.tscn, run mastery sword level 6: player.special.tiers == 3; level 1: 1
```

- [ ] **Step 2: Run.** Expected: FAIL.

- [ ] **Step 3: Implement.** On release: the highest tier `<= tiers` whose `tier_hold` was reached and which is ready fires; else the next lower ready reached tier; else the bow's `CHARGED` rule as today. `glow()` fills toward the next unlocked tier that can fire. The player sets `special.tiers = Mastery.tiers(run.mastery.level(run.mastery_style()))` in `_refresh_stats` (and on `mastery_up`), keeps the cooldowns across weapon swaps, and passes `special.fired_tier` to `_start_special` (moves come in Tasks 14-15; until then every tier fires the tier-1 move). `WeaponFx` flashes once each time the hold crosses an unlocked tier; `SpecialIcon` draws 3 pips under the slot: lit (unlocked, ready), dim (unlocked, cooling), dark outline (locked).

- [ ] **Step 4: Run tests.** Expected: `PASS N / FAIL 0`.

- [ ] **Step 5: Visual check.** `--mastery=sword:6` dungeon screenshot `--frames=30 --out=/tmp/tiers.png`: three lit pips under the special slot; with `--special-cd=3`, pip 1 dim.

- [ ] **Step 6: Commit**

```bash
git add game/logic/special_charge.gd game/actors/player game/ui/special_icon.gd game/ui/hud.gd game/tests/unit/test_special_charge.gd
git commit -m "feat: três degraus de golpe especial liberados pela maestria"
```

### Task 14: The new melee moves

**Files:**
- Create: `game/logic/special_move.gd`
- Modify: `game/logic/weapon_def.gd`, `game/actors/player/player.gd`
- Test: `game/tests/unit/test_special_moves.gd`

**Interfaces:**
- Consumes: Task 13 (`_start_special(tier)`).
- Produces: `class_name SpecialMove` with `kind: StringName`, `mult: float`, `name: String`, `repeats: int = 1`, `reach_mult: float = 1.0`, `stun: float = 0.0`, `radius: float = 0.0`, `pierce: int = 0`, `end_wave: bool = false`, `static func of(kind: StringName, mult: float, name: String, extra: Dictionary = {}) -> SpecialMove`; `WeaponDef.moves: Array[SpecialMove]` (3 per type; `moves[0]` mirrors `special`/`special_mult`).

The moves (tier 1 is today's; Tasks 14 and 15 add 12 for the six weapon types plus 2 for Lâminas Gêmeas):

| Type | Tier 2 | Tier 3 |
|---|---|---|
| sword | `spin` 2.2 "Giro Largo", reach_mult 1.3 | `thrust_line` 2.8 "Estocada de Onda", end_wave |
| longsword | `spin` 1.8 "Giro Duplo", repeats 2 | `ground_slam` 3.0 "Golpe Sísmico", radius 90 |
| axe | `lunge` 2.4 "Investida do Machado", stun 0.6 | `ground_slam` 1.8 "Três Tremores", repeats 3 |
| spear | `lunge` 1.8 "Investida Dupla", repeats 2 | `spear_throw` 3.0 "Arremesso", pierce 99 (Task 15) |
| dagger | `flurry` 0.8 "Dança das Lâminas", repeats 10 | `spin` 1.6 "Redemoinho", repeats 3 |
| bow | `arrow_fan` 1.5 "Leque", pierce 1 (Task 15) | `explosive_arrow` 2.5 "Flecha Explosiva", radius 36 (Task 15) |
| dual | `cross_flurry` 0.9 "Tempestade Cruzada", repeats 6 | `spin` 1.6 "Giro Gêmeo", repeats 2, with the off-hand share |

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_every_type_has_three_moves() -> void:
	for t: StringName in ItemDB.WEAPON_TYPES:
		var d := WeaponDef.for_type(t)
		T.eq(d.moves.size(), 3, String(t))
		T.eq(d.moves[0].kind, d.special)
		T.near(d.moves[0].mult, d.special_mult)
	T.eq(WeaponDef.dual_swords(&"sword_iron").moves[1].name, "Tempestade Cruzada")

func test_move_table() -> void:
	T.eq(WeaponDef.for_type(&"spear").moves[1].repeats, 2)
	T.eq(WeaponDef.for_type(&"longsword").moves[2].radius, 90.0)
	T.ok(WeaponDef.for_type(&"sword").moves[2].end_wave)

func test_double_lunge_hits_twice() -> void:
	# player.tscn with spear_hunter, an enemy Hurtbox 40 px ahead counting hits;
	# player._start_special(2) then step _process_special to the end:
	T.eq(hits, 2)

func test_three_tremors_march_forward() -> void:
	# axe, _start_special(3): 3 PlayerBlast WAVE nodes, each 24 px further along the facing

func test_spin_repeats_reset_hits() -> void:
	# longsword _start_special(2): an enemy inside the circle is hit twice
```

- [ ] **Step 2: Run.** Expected: FAIL.

- [ ] **Step 3: Implement.** `Player` keeps `var _move: SpecialMove` and switches on `_move.kind` where it switched on `weapon.special`; `repeats` replays the pattern with `hitbox.reset_hits()` between runs (flurry/cross_flurry: number of cuts; lunge/spin: back-to-back runs; ground_slam: each slam 24 px further along `_special_dir`); `reach_mult`, `radius`, `stun` and `end_wave` (a `PlayerBlast` WAVE at the end of the thrust line) adjust the existing shapes. Each move uses its own tier's damage `mult`.

- [ ] **Step 4: Run tests.** Expected: `PASS N / FAIL 0`.

- [ ] **Step 5: Visual check.** Extend `game/tools/capture_fx.gd` with `--special-tier=N`; capture each melee type at tiers 2 and 3 (`--weapon=<id> --mastery=<type>:6`) to `/tmp/moves/`: each move's light trail reads distinct from tier 1.

- [ ] **Step 6: Commit**

```bash
git add game/logic/special_move.gd game/logic/weapon_def.gd game/actors/player/player.gd game/tools/capture_fx.gd game/tests/unit/test_special_moves.gd
git commit -m "feat: golpes 2 e 3 das armas de perto e das Lâminas Gêmeas"
```

### Task 15: The new ranged moves (spear throw, fan, explosive arrow)

**Files:**
- Modify: `game/actors/player/player.gd`, `game/actors/player/player_arrow.gd`, `game/actors/player/player_blast.gd`
- Test: `game/tests/unit/test_special_moves.gd`

**Interfaces:**
- Consumes: Task 14 (`SpecialMove`, `WeaponDef.moves`).
- Produces: `PlayerArrow.blast_radius: float = 0.0` (bursts into a one-volley `PlayerBlast` RAIN of that radius where it lands or ends), `PlayerArrow.spear: bool = false` (drawn as a spear shaft, 16 px); `PlayerBlast.volleys` already exists.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_spear_throw_pierces_everything_in_line() -> void:
	# spear, _start_special(3): one PlayerArrow with spear true, pierce 99,
	# damage == roundi(stats.damage * 3.0) (crit rng seeded to miss); 4 hurtboxes in line all hit

func test_bow_fan_shoots_three_charged_arrows() -> void:
	# bow, _start_special(2): 3 PlayerArrow, charged, pierce 1, directions -15, 0, +15 degrees

func test_explosive_arrow_bursts_where_it_lands() -> void:
	# bow, _start_special(3), a hurtbox 60 px ahead: after it lands a PlayerBlast
	# with radius 36 and volleys 1 exists at the hurtbox position
```

- [ ] **Step 2: Run.** Expected: FAIL. **Step 3:** implement the three kinds in `_start_special`. **Step 4: Run tests.** Expected: `PASS N / FAIL 0`.

- [ ] **Step 5: Visual check.** `capture_fx.gd --weapon=spear_hunter --mastery=spear:6 --special-tier=3` and `--weapon=bow_short --mastery=bow:6 --special-tier=2/3`: thrown spear and the 3-arrow fan read clearly; the burst ring matches its hit area.

- [ ] **Step 6: Commit**

```bash
git add game/actors/player game/tools/capture_fx.gd game/tests/unit/test_special_moves.gd
git commit -m "feat: arremesso da lança, leque e flecha explosiva"
```

### Task 16: Style relics (data, effects, sources)

**Files:**
- Modify: `game/data/item_catalog.gd`, `game/logic/player_stats.gd`, `game/logic/run_state.gd` (`add_mastery_xp` applies the XP relic), `game/actors/player/player.gd`, `game/actors/enemies/enemy_base.gd`, `game/actors/common/hitbox.gd`, `game/logic/item_compare.gd` (rows for the new stats)
- Test: `game/tests/unit/test_style_relics.gd`; update `test_item_db.gd::test_content_counts` to 24 relics

**Interfaces:**
- Consumes: Tasks 11, 13, 14.
- Produces: catalog key `"style": StringName` on relics (optional); mods keys `xp_mult`, `finisher_refund`, `style_stun`, `stunned_bonus`, `lunge_stun`, `style_crit`, `extra_pierce`, `roll_refund`, `heal_while_charging`; `PlayerStats` fields `xp_mult: Dictionary[StringName, float]`, `finisher_refund: float`, `style_stun: float`, `stunned_bonus: float`, `lunge_stun: float`, `extra_pierce: int`, `roll_refund: float`, `heal_while_charging: bool`; `Hitbox.stunned_bonus: float = 0.0`.

The 16 relics (id, style, rarity, base_price, name, desc, mods):

| id | style | rarity | name | desc | mods |
|---|---|---|---|---|---|
| duelist_ribbon | sword | rare | Fita do Duelista | O golpe final da espada recarrega 0,5 s do especial. | finisher_refund 0.5 |
| whetstone | sword | common | Pedra de Amolar | +50% de maestria de Espada. | xp_mult 1.5 |
| lead_counterweight | longsword | rare | Contrapeso de Chumbo | Golpes da espada longa atordoam por 0,3 s. | style_stun 0.3 |
| greatsword_manual | longsword | common | Manual do Montante | +50% de maestria de Espada Longa. | xp_mult 1.5 |
| woodcutter_belt | axe | epic | Cinto do Lenhador | +30% de dano do machado em quem está atordoado. | stunned_bonus 0.3 |
| coarse_file | axe | common | Lima Grossa | +50% de maestria de Machado. | xp_mult 1.5 |
| lancer_pennant | spear | rare | Flâmula do Lanceiro | A investida da lança atordoa por 0,6 s. | lunge_stun 0.6 |
| marked_shaft | spear | common | Haste Marcada | +50% de maestria de Lança. | xp_mult 1.5 |
| rogue_glove | dagger | rare | Luva de Ladino | +15% de crítico com adaga. | style_crit 0.15 |
| small_hone | dagger | common | Pedrinha de Afiar | +50% de maestria de Adaga. | xp_mult 1.5 |
| deep_quiver | bow | rare | Aljava Funda | A flecha carregada atravessa mais 2 inimigos. | extra_pierce 2 |
| raven_feather | bow | common | Pena de Corvo | +50% de maestria de Arco. | xp_mult 1.5 |
| acrobat_slippers | roll | epic | Sapatilha de Acrobata | Rolar recarrega 20% do especial. | roll_refund 0.2 |
| ankle_band | roll | common | Tornozeleira | +50% de maestria de Rolamento. | xp_mult 1.5 |
| ancient_moss | heal | rare | Musgo Antigo | Cura parado também enquanto carrega o especial. | heal_while_charging 1 |
| root_tea | heal | common | Chá de Raiz | +50% de maestria de Cura. | xp_mult 1.5 |

base_price: common 25, rare 35, epic 45.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_sixteen_style_relics_two_per_style() -> void:
	var per: Dictionary[StringName, int] = {}
	for id: StringName in ItemDB.ids(&"relic"):
		var s: StringName = ItemCatalog.ITEMS[id].get("style", &"")
		if s != &"":
			per[s] = per.get(s, 0) + 1
	T.eq(per.size(), 8)
	for s: StringName in per:
		T.eq(per[s], 2, String(s))

func test_xp_relic_speeds_its_style() -> void:
	# equip marked_shaft (spear), add_mastery_xp(&"spear", 100): xp[&"spear"] == 150; sword XP unaffected

func test_duplicate_style_relics_do_not_stack() -> void:
	# two marked_shaft equipped: add 100 spear XP -> 150, not 225
	# two lancer_pennant: stats().lunge_stun == 0.6

func test_weapon_relic_only_works_with_its_weapon() -> void:
	# rogue_glove with sword_iron: crit_chance == sword's 0.05; with dagger_rogue: 0.2 + 0.15

func test_relic_with_full_slots_goes_to_the_backpack() -> void:
	# 3 relics equipped, run.take_loot(&"whetstone") == 0, relics unchanged,
	# inventory.count(&"whetstone") == 1, its XP bonus not active

func test_roll_refunds_special() -> void:
	# acrobat_slippers, special.cooldowns = [4.0, 7.0, 10.0], _start_roll:
	# cooldowns == [3.2, 5.6, 8.0]

func test_heal_while_charging() -> void:
	# ancient_moss, special.holding true, idle past heal_delay: hp rises; without the relic it does not

func test_stunned_bonus() -> void:
	# woodcutter_belt + axe: a stunned crawler takes roundi(dmg * 1.3)

func test_style_relics_drop_from_chests_and_rares() -> void:
	# 2000 seeded roll_chest calls include at least one style relic;
	# roll_rare relic pool includes the epic style relics
```

- [ ] **Step 2: Run.** Expected: FAIL.

- [ ] **Step 3: Implement.** In `from_equipment`, style relics are deduplicated by id; weapon-style effects apply only when the relic's style equals `s.weapon_type` (roll and heal relics always); XP mults store `max` per style. Player: `finisher_refund` on a finisher swing (`special.refund`), `roll_refund` in `_start_roll` (`special.refund_ratio`), `style_stun` on longsword swings, `lunge_stun` on lunge moves, `extra_pierce` on charged arrows, `heal_while_charging` drops `not special.holding` from the idle rule; the player hitbox carries `stunned_bonus` and `EnemyBase._on_hit` multiplies when `stunned > 0`. Relics need no new loot code: chests, elites, rares and bosses already draw from `sourced_by(&"relic", rarity)`.

- [ ] **Step 4: Run tests.** Expected: `PASS N / FAIL 0`.

- [ ] **Step 5: Commit**

```bash
git add game/data/item_catalog.gd game/logic game/actors game/tests/unit/test_style_relics.gd game/tests/unit/test_item_db.gd
git commit -m "feat: 16 relíquias de estilo"
```

### Task 17: Style relic icons

**Files:**
- Create: `art-src/gen/r3/icons-style-relics-sheet.png`, `game/assets/items/<id>.png` for the 16 ids
- Modify: `art-src/build_items.py`, `docs/assets.md`
- Test: `game/tests/unit/test_item_db.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
func test_every_item_has_an_icon_file() -> void:
	for id: StringName in ItemDB.ids():
		T.ok(ResourceLoader.exists(ItemDB.icon_path(id)), "%s icon" % id)
```

- [ ] **Step 2: Run.** Expected: FAIL for the 16 style relics.
- [ ] **Step 3: Generate** `cinzel-icons-style-relics-sheet` (4x4 grid on magenta, preset `cinzel-pixel`, role `gameplayProps`, project `asset-gen`, style reference: the current relic icons sheet), each icon describing its table row (ribbon, whetstone, lead weight, book, belt, file, pennant, notched shaft, glove, small hone, quiver, black feather, slippers, ankle band, moss in a jar, tea cup with root).
- [ ] **Step 4: Build** with `build_items.py` (16x16, same outline and rarity frame as the others), `check_art.py`, `preview_items.py`.
- [ ] **Step 5: Run tests.** Expected: `PASS N / FAIL 0`. (Task 18 adds the 4 consumables to a `PENDING_ICONS: Array[StringName]` const that this test skips; Task 20 empties it.)
- [ ] **Step 6: Visual check.** Read the `preview_items.py` sheet: each icon reads at 16 px and matches its name; screenshot the backpack with `--give=whetstone,lancer_pennant,acrobat_slippers --inventory`.
- [ ] **Step 7: Commit**

```bash
git add art-src/gen/r3 art-src/build_items.py game/assets/items docs/assets.md game/tests/unit/test_item_db.gd
git commit -m "arte: ícones das relíquias de estilo"
```

### Task 18: Consumables and buffs

**Files:**
- Create: `game/logic/buffs.gd`
- Modify: `game/data/item_catalog.gd`, `game/logic/item_db.gd`, `game/logic/run_state.gd`, `game/logic/player_stats.gd`, `game/logic/market.gd`, `game/logic/loot_table.gd`, `game/ui/shop_panel.gd`, `game/actors/player/player.gd`
- Test: `game/tests/unit/test_consumables.gd`; update `test_item_db.gd::test_content_counts` and add the 4 ids to its `PENDING_ICONS` (Task 17)

**Interfaces:**
- Produces: kind `&"consumable"` in `ItemDB.KINDS`; `ItemDB.CONSUMABLE_STACK := 5`; catalog key `"use": {"buff": StringName, "seconds": float, "value": float}`; items `potion_life` ("Poção de Vida", "Cura 30 em 3 s. Dá para andar.", regen 10.0 for 3.0 s, base_price 40), `ration_travel` ("Ração de Viagem", "+10% de dano por 120 s.", damage 1.10 for 120 s, 15), `elixir_wind` ("Elixir do Vento", "+15% de velocidade por 90 s.", speed 1.15 for 90 s, 20), `tonic_stone` ("Tônico de Pedra", "+3 de defesa por 120 s.", defense 3.0 for 120 s, 20), all common; `class_name Buffs` with `var left: Dictionary[StringName, float]` (consumable id -> seconds), `func apply(id: StringName) -> void` (refreshes, never stacks), `func tick(delta: float) -> bool` (true when one expired), `func regen_rate() -> float`, `func dmg_mult() -> float`, `func move_mult() -> float`, `func defense_add() -> int`; `RunState.buffs: Buffs`, `RunState.use_consumable(id: StringName) -> String` ("" when used, else the reason "Não tem"); `Market.CONSUMABLES: Array[StringName]` (the 4, always for sale), `Market.buy_item(run: RunState, id: StringName) -> bool`; `LootTable.CHEST_CONSUMABLES: Array[StringName] = [&"potion_life", &"elixir_wind"]`, `CHEST_KIND_WEIGHTS[&"consumable"] = 12.0`.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_consumables_stack_to_five() -> void:
	var inv := Inventory.new(8)
	T.eq(inv.add(&"potion_life", 7), 0)
	T.eq(inv.used(), 2)
	T.eq(ItemDB.stack_max(&"potion_life"), 5)

func test_potion_heals_thirty_over_three_seconds() -> void:
	# run with potion_life, hp 40/100, use_consumable -> "", count 0
	# player physics 3.2 s while walking (not idle): hp == 70

func test_buffs_change_stats_and_expire() -> void:
	# ration_travel: stats().damage == roundi(10 * 1.10); tonic_stone: defense +3;
	# elixir_wind: move_speed * 1.15; buffs.tick(121.0) -> true and stats back to base

func test_redrinking_refreshes_not_stacks() -> void:
	# apply ration, tick 60, apply again: left[&"ration_travel"] == 120, dmg_mult == 1.10

func test_shop_always_sells_consumables() -> void:
	# ShopPanel.buy_list() contains the 4; Market.buy_item with 64 gold buys potion_life (40 * 1.6)

func test_chests_drop_only_potion_and_elixir() -> void:
	# 3000 seeded roll_chest: consumables seen are only potion_life and elixir_wind, at least one

func test_death_clears_buffs() -> void:
	# apply elixir, die(): buffs.left.is_empty()
```

- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** `PlayerStats.from_equipment` multiplies `damage` and `move_speed` and adds `defense` from `run.buffs`. The player ticks `run.buffs` in `_physics_process` only when `armed` (the timers stop in town and while paused), heals `regen_rate() * delta`, and emits `run.changed` when `tick` reports an expiry. Consumables are sellable (`TRADE_KINDS` gains `&"consumable"`), not in `STOCK_KINDS`.
- [ ] **Step 4: Run tests.** Expected: `PASS N / FAIL 0`.
- [ ] **Step 5: Visual check.** `--screenshot=res://world/town.tscn --panel=shop --tab=buy --gold=200 --out=/tmp/shop_consumables.png`: the four consumables listed with prices, panel not overflowing.
- [ ] **Step 6: Commit**

```bash
git add game/logic game/data/item_catalog.gd game/ui/shop_panel.gd game/actors/player/player.gd game/tests/unit/test_consumables.gd game/tests/unit/test_item_db.gd
git commit -m "feat: poção, ração, elixir e tônico, com efeitos por tempo"
```

### Task 19: Quick bar and buff icons

**Files:**
- Modify: `game/project.godot` (actions `quick_1`, `quick_2`, `quick_3` on keys 1, 2, 3), `game/logic/run_state.gd`, `game/actors/player/player.gd`, `game/ui/hud.gd`, `game/ui/inventory_screen.gd`, `game/ui/pause.gd` (controls text), `game/tests/unit/test_hud.gd` (slots now show the quick bar)
- Test: `game/tests/unit/test_quick_bar.gd`

**Interfaces:**
- Consumes: Task 18.
- Produces: `RunState.quick_bar: Array[StringName]` (3 entries, `&""` empty), `func set_quick(slot: int, id: StringName) -> void` (a consumable only; removes it from any other slot), `func quick_count(slot: int) -> int`; consumables taken by `take_loot` or bought fill the first empty quick slot when not already on the bar; `Player.QUICK_ACTIONS: Array[StringName]`, `func use_quick(slot: int) -> bool`; HUD `quick_icons: Array[TextureRect]`, `quick_counts: Array[Label]`, `buff_row: HBoxContainer`.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_bought_consumable_lands_on_the_bar() -> void:
	# new run, take_loot(&"potion_life", 2): quick_bar[0] == &"potion_life", quick_count(0) == 2

func test_quick_use_spends_one() -> void:
	# player in tower (armed), use_quick(0) -> true, quick_count(0) == 1, buff active

func test_quick_use_refused_while_paused_or_busy() -> void:
	# tree paused: use_quick(0) false, count unchanged (unpause after)
	# UiKit.block_gameplay_input() this frame: false
	# state ROLL, SPECIAL and DEAD each: false, count unchanged
	# armed = false (town): false and Game toast "Na cidade não"

func test_empty_slot_does_nothing() -> void:
	# quick_bar[2] == &"": use_quick(2) false, no toast

func test_assign_from_backpack() -> void:
	# InventoryScreen, select the elixir's bag slot, press quick_2: quick_bar[1] == &"elixir_wind"

func test_hud_shows_bar_and_buffs() -> void:
	# hud.quick_icons[0].texture != null, quick_counts[0].text == "2";
	# with ration active, buff_row has 1 child showing "120"
	# die(): quick_bar == [&"", &"", &""]
```

- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** `use_quick` refuses when `get_tree().paused`, `UiKit.gameplay_input_blocked()`, `state in [State.ROLL, State.SPECIAL, State.DEAD]` or the slot count is 0; not armed toasts "Na cidade não". `_physics_process` checks the three actions with `_just_pressed`. The HUD's 3 slots switch from relics to the quick bar: icon, stack count bottom-right, key number top-left in `UiKit.COLOR_MUTED`; empty slots show only the key number. Buff icons sit under the bar: 9 px icon (the consumable's icon scaled) and whole seconds left. In the backpack, keys 1/2/3 on a selected consumable assign it; its tooltip note reads "Teclas 1, 2 e 3: barra rápida".
- [ ] **Step 4: Run tests.** Expected: `PASS N / FAIL 0`.
- [ ] **Step 5: Visual check.** Dungeon screenshot with `--give=potion_life:3,ration_travel:1` and a debug `--use=1` (Player, uses quick slot 1 on load) `--out=/tmp/quickbar.png`: numbers legible at 1x, buff timer shown, nothing overlaps the special slot.
- [ ] **Step 6: Commit**

```bash
git add game/project.godot game/logic/run_state.gd game/actors/player/player.gd game/ui game/tests/unit/test_quick_bar.gd game/tests/unit/test_hud.gd
git commit -m "feat: barra rápida nas teclas 1, 2 e 3 e ícones de efeito no HUD"
```

### Task 20: Consumable icons

Same steps as Task 17 for `potion_life`, `ration_travel`, `elixir_wind`, `tonic_stone` (generation `cinzel-icons-consumables-sheet`, 2x2 on magenta: red potion flask, wrapped bread and jerky, pale green swirling vial, grey stone-capped bottle). Empty `PENDING_ICONS` in `test_item_db.gd`; `test_every_item_has_an_icon_file` must pass for every id. Visual check: the quick bar screenshot from Task 19 again, icons readable at 16 px and at the 9 px buff size.

- [ ] **Step 1: Failing test** (remove the 4 ids from `PENDING_ICONS`).
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Generate.**
- [ ] **Step 4: Build and check_art.**
- [ ] **Step 5: Run tests.** Expected: `PASS N / FAIL 0`.
- [ ] **Step 6: Visual check.**
- [ ] **Step 7: Commit**

```bash
git add art-src/gen/r3 art-src/build_items.py game/assets/items docs/assets.md game/tests/unit/test_item_db.gd
git commit -m "arte: ícones dos consumíveis"
```

### Task 21: Refine logic

**Files:**
- Create: `game/logic/refine.gd`
- Modify: `game/data/item_catalog.gd` (`"refine_mat"` on every weapon and armor), `game/logic/run_state.gd`, `game/logic/player_stats.gd`, `game/ui/ui_kit.gd` (`item_name` adds the level)
- Test: `game/tests/unit/test_refine.gd`

**Interfaces:**
- Produces: `class_name Refine`: `MAX := 5`, `CHANCE: Array[float] = [1.0, 0.9, 0.75, 0.6, 0.45]`, `MAT_QTY: Array[int] = [2, 3, 4, 5, 6]`, `GOLD: Array[int] = [20, 40, 70, 110, 160]`, `BONUS_PER_LEVEL := 0.08`, `KINDS: Array[StringName] = [&"weapon", &"armor"]`; `static func can_refine(id: StringName) -> bool`; `static func material(id: StringName) -> StringName`; `static func cost(run: RunState, id: StringName) -> Dictionary` (`{"material": StringName, "qty": int, "gold": int, "chance": float}` for the next level); `static func block_reason(run: RunState, id: StringName) -> String` ("Não dá para refinar", "Já está em +5", "Faltam materiais", "Ouro insuficiente", or ""); `static func attempt(run: RunState, id: StringName, rng: RandomNumberGenerator) -> int` (1 success, 0 failed, -1 refused and nothing spent); `RunState.refine: Dictionary[StringName, int]`, `func refine_level(id: StringName) -> int`, `func owns(id: StringName) -> bool` (equipped, off-hand or in the backpack), `func prune_refine() -> void` (connected to its own `changed`).

refine_mat per item: `sword_iron`, `longsword_steel`, `axe_woodcutter`, `axe_war`, `dagger_rogue`, `armor_chain`, `armor_plate`: `mat_iron_ore`; `sword_knight`: `mat_silver_ore`; `sword_midnight`, `dagger_twin_fang`: `mat_obsidian`; `longsword_ember`: `mat_coal`; `spear_hunter`, `bow_short`, `bow_elven`: `mat_ash_wood`; `spear_dragoon`: `mat_beetle_horn`; `armor_cloth`, `armor_leather`: `mat_old_leather`; `armor_scale`: `mat_chitin`; `armor_shadow`: `mat_specter_cloth`.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_first_refine_always_works_and_costs() -> void:
	# run with 2 iron, 20 gold: attempt(run, &"sword_iron", rng) == 1
	T.eq(run.refine_level(&"sword_iron"), 1)
	T.eq(run.gold, 0)
	T.eq(run.inventory.count(&"mat_iron_ore"), 0)
	T.eq(run.stats().damage, roundi(10 * 1.08))
	T.eq(UiKit.item_name(&"sword_iron"), "Espada de Ferro +1")

func test_failure_spends_but_keeps_level() -> void:
	# level 4 -> 5 at chance 0.45 with a seed that fails: returns 0, level stays 4,
	# 6 iron and 160 gold gone

func test_chances_over_many_tries() -> void:
	# 2000 seeded attempts from +4: success share between 0.40 and 0.50

func test_armor_refine_raises_defense_and_life() -> void:
	# armor_chain +2: defense == roundi(4 * 1.16), max_hp == 100 + roundi(20 * 1.16)

func test_helms_relics_and_materials_cannot_refine() -> void:
	T.eq(Refine.block_reason(run, &"helm_iron"), "Não dá para refinar")

func test_refine_cleared_when_last_copy_leaves() -> void:
	# two sword_iron owned (one equipped, one in the bag) at +3
	# sell the bag copy (Market.sell): level stays 3
	# equip spear_hunter (sword back in bag), drop that slot (inventory.take_slot + changed):
	T.eq(run.refine_level(&"sword_iron"), 0)
	# a sword forged or picked up later starts at +0

func test_death_resets_refine() -> void:
	# +2 sword, die(): refine.is_empty()
```

- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** `attempt` spends materials and gold before the roll (`rng.randf() < CHANCE[level]`). `PlayerStats` multiplies the weapon's damage (and the off-hand's) and the armor's defense and max_hp by `1 + BONUS_PER_LEVEL * level`, rounding each. `UiKit.item_name` appends `" +%d"` when `Game.run.refine_level(id) > 0`.
- [ ] **Step 4: Run tests.** Expected: `PASS N / FAIL 0`.
- [ ] **Step 5: Commit**

```bash
git add game/logic/refine.gd game/data/item_catalog.gd game/logic/run_state.gd game/logic/player_stats.gd game/ui/ui_kit.gd game/tests/unit/test_refine.gd
git commit -m "feat: refino de +1 a +5 guardado por item na subida"
```

### Task 22: Refine tab at the smith and the +5 glow

**Files:**
- Modify: `game/ui/smith_panel.gd`, `game/actors/player/layered_sprite.gd`, `game/actors/player/player.gd`, `game/world/town.gd` (`--tab=refine` for `--panel=smith`)
- Test: `game/tests/unit/test_refine_ui.gd`

**Interfaces:**
- Consumes: Task 21.
- Produces: `SmithPanel.tab: StringName` (`&"forge"` | `&"refine"`), `func select_tab(t: StringName) -> void`, `var refine_cells: Array[ItemCell]`, `var refine_button: Button`, `func refine_selected() -> int`, `var rng: RandomNumberGenerator` (seedable); `LayeredSprite.set_glow(layer: StringName, on: bool) -> void`.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_refine_tab_lists_worn_and_bag_weapons_and_armors() -> void:
	# sword_iron worn, armor_leather and helm_iron in the bag:
	# select_tab(&"refine"): refine_cells ids == [sword_iron, armor_leather]

func test_refine_button_reports_result() -> void:
	# enough iron and gold: refine_selected() == 1, message "Deu certo! +1"
	# seeded failure at +4: message "Falhou. O item continua +4."
	# not enough gold: button disabled with "Ouro insuficiente"

func test_plus_five_glows_on_the_hero() -> void:
	# player.tscn, refine sword_iron to 5 (set run.refine directly, emit changed):
	# sprite glow on for &"weapon"; back to +4: off
```

- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** Tab buttons "Forjar" | "Refinar" at the top of the existing panel. The Refinar side shows the item with its stat rows against the next level (`ItemCompare`), the material row (icon, have/need, red when short), the gold row, the chance as "Chance: 75%", and "Refinar" disabled with `block_reason`. Success plays `&"forge"` and pulses the cell; failure plays `&"door_locked"`. `set_glow` pulses the layer's `self_modulate` between 1.0 and 1.35 with a 1.2 s period.
- [ ] **Step 4: Run tests.** Expected: `PASS N / FAIL 0`.
- [ ] **Step 5: Visual check.** `--screenshot=res://world/town.tscn --panel=smith --tab=refine --give=mat_iron_ore:10,gold:200 --out=/tmp/refine.png` (tab fits, numbers aligned) and a dungeon screenshot with a debug `--refine=sword_iron:5` (Game) `--out=/tmp/glow.png` (weapon glow visible but subtle).
- [ ] **Step 6: Commit**

```bash
git add game/ui/smith_panel.gd game/actors/player game/world/town.gd game/autoload/game.gd game/tests/unit/test_refine_ui.gd
git commit -m "feat: aba Refinar no ferreiro e brilho no +5"
```

### Task 23: Mission board logic

**Files:**
- Create: `game/logic/mission_board.gd`
- Modify: `game/logic/run_state.gd`, `game/world/dungeon.gd`
- Test: `game/tests/unit/test_missions.gd`

**Interfaces:**
- Consumes: `RunState.record_kill`, `MonsterDB.species_of_floor`, `LootTable.roll_rarity/_gear`.
- Produces: `class_name MissionBoard`; inner `class Mission` with `type: StringName` (`&"hunt"`, `&"deliver"`, `&"elite"`, `&"reach"`), `target: StringName`, `need: int`, `have: int`, `gold: int`, `bonus: StringName`, `func text() -> String`; consts `COUNT := 3`, `HUNT_NEED := 6`, `HUNT_GOLD_PER_KILL := 8` (times the species' floor), `DELIVER_NEED := 4`, `DELIVER_GOLD_MULT := 2` (times `ItemDB.price`), `ELITE_GOLD := 60`, `REACH_GOLD_PER_FLOOR := 50`, `BONUS_CHANCE := 0.2`; `var missions: Array[Mission]`; `func begin_visit(rng: RandomNumberGenerator, run: RunState) -> void`; `func on_kill(species: StringName, elite: bool) -> void`; `func on_trip_start(floor_num: int) -> void`; `func on_floor_entered(floor_num: int) -> void`; `func is_done(i: int, run: RunState) -> bool`; `func block_reason(i: int, run: RunState) -> String`; `func claim(i: int, run: RunState) -> bool`; `RunState.missions: MissionBoard`.

Texts: hunt "Caçar 6 Slime de Esgoto", deliver "Entregar 4 Quitina de Besouro", elite "Vencer um elite", reach "Chegar ao andar 3 sem sair".

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_board_draws_three_distinct_types_from_opened_floors() -> void:
	# unlocked_floors 1: 3 missions, distinct types, hunt targets in species_of_floor(1),
	# deliver targets in materials_of_floor(1), reach target 2

func test_hunt_counts_kills() -> void:
	# hunt slime: on_kill(&"slime", false) x 6 -> is_done; claim adds 6 * 8 gold

func test_deliver_takes_materials_on_claim() -> void:
	# deliver 4 old leather with 4 in the bag: claim removes them and pays price * 4 * 2

func test_bonus_needs_room() -> void:
	# mission with bonus relic, backpack and relic slots full: block_reason "Mochila cheia", claim false

func test_leaving_mid_floor_keeps_kills_resets_reach() -> void:
	# missions: hunt slime 6, reach 2, elite
	# on_trip_start(1); 3 slime kills; leave (no call) -> begin_visit:
	#   hunt replaced (unfinished), so its kills do not carry over to the new one
	# board with hunt done (6 kills) and unclaimed -> begin_visit keeps it, still done
	# on_trip_start(1); on_floor_entered(1); leave; on_trip_start(2) (teleport to floor 2):
	#   reach 2 not done
	# on_trip_start(1); on_floor_entered(2): reach 2 done

func test_death_resets_board() -> void:
	# die(): missions.missions.is_empty() until the next begin_visit
```

- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** `begin_visit` keeps done-unclaimed missions and draws the rest (types not already on the board); reach target is `mini(run.unlocked_floors + 1, 3)`, done only when entered on a floor greater than the trip's start floor; `on_kill` counts hunt kills of its target and elite kills; deliver progress reads the bag in `is_done`. Bonus: 50/50 a relic (`roll_rarity(unlocked_floors, 0)`) or `mat_tower_crystal`. `RunState.record_kill` calls `missions.on_kill`. `Dungeon._ready` calls `on_trip_start(requested floor)` (not for `--room`), `enter_floor` calls `on_floor_entered`.
- [ ] **Step 4: Run tests.** Expected: `PASS N / FAIL 0`.
- [ ] **Step 5: Commit**

```bash
git add game/logic/mission_board.gd game/logic/run_state.gd game/world/dungeon.gd game/tests/unit/test_missions.gd
git commit -m "feat: missões que contam abates, entregas, elites e andares"
```

### Task 24: Mission board in town

**Files:**
- Create: `art-src/gen/r3/town-mission-board.png`, `game/assets/town/board.png`, `game/ui/board_panel.gd`
- Modify: `art-src/build_town.py`, `game/world/town.tscn` (`Props/Board` sprite with `Footprint`, `Spots/Board` marker with `Ring`, near the shop), `game/world/town.gd`, `game/world/town_logic.gd`, `docs/assets.md`
- Test: `game/tests/unit/test_town_ui.gd`

**Interfaces:**
- Consumes: Task 23.
- Produces: `class_name BoardPanel extends UiPanel` with `var claim_buttons: Array[Button]`; town spot id `&"board"` (`SPOT_NAMES` "Quadro", `GLOW_TARGETS` `^"Props/Board"`); `TownLogic.can_act(id, item_count, can_forge = false, can_claim = false)` and `cta_visible(id, near, item_count, can_forge = false, can_claim = false)`, the board acting only when `can_claim` (any mission done); `Town` calls `Game.run.missions.begin_visit(_rng, Game.run)` in `_ready`.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_board_panel_lists_three_missions() -> void:
	# town, open_panel(&"board"): 3 rows, each with text, "3/6" progress and reward "48 ouro"

func test_claim_with_e_pays_and_refreshes() -> void:
	# a done hunt: claim_buttons[i] enabled; press -> gold rises, row shows "Entregue"

func test_board_ring_only_when_something_to_claim() -> void:
	T.ok(not TownLogic.cta_visible(&"board", &"board", 0, false, false))
	T.ok(TownLogic.cta_visible(&"board", &"board", 0, false, true))
```

- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Generate the prop.** `cinzel-town-mission-board` (`generate_styled_image`, preset `cinzel-pixel`, role `gameplayProps`, project `asset-gen`, reference `town-props`): wooden notice board on two posts, small roof, three pinned papers, on magenta; built by `build_town.py` like the other props (baseline 4 px above the bottom, embedded shadow, outline).
- [ ] **Step 4: Implement.** Scene nodes edited in `town.tscn` (Y-sorted under `Props`), panel rows: mission text, progress, reward ("+ relíquia" or "+ Cristal da Torre" when there is a bonus), "Entregar" button enabled when done, disabled with `block_reason`. Shopkeeper-side bubble line not needed; the board's ring pings when a mission can be claimed.
- [ ] **Step 5: Run tests.** Expected: `PASS N / FAIL 0`.
- [ ] **Step 6: Visual check.** `--screenshot=res://world/town.tscn --out=/tmp/town_board.png` (board sits near the shop, same light and outline as other props, player can walk to it) and `--panel=board --out=/tmp/board_panel.png` (text fits).
- [ ] **Step 7: Commit**

```bash
git add art-src/gen/r3 art-src/build_town.py game/assets/town/board.png game/ui/board_panel.gd game/world/town.tscn game/world/town.gd game/world/town_logic.gd docs/assets.md game/tests/unit/test_town_ui.gd
git commit -m "feat: quadro de missões na cidade"
```

### Task 25: Bestiary and titles logic

**Files:**
- Create: `game/logic/bestiary.gd`, `game/logic/titles.gd`
- Modify: `game/logic/run_state.gd`, `game/world/dungeon.gd` (`_win`)
- Test: `game/tests/unit/test_bestiary_titles.gd`

**Interfaces:**
- Consumes: `RunState.record_kill`, `RunState.mastery_up`, `MonsterDB` rows (`hunter_title`, `title`).
- Produces: `class_name Bestiary` with `var kills: Dictionary[StringName, int]`, `func record(species: StringName) -> int` (new total), `func seen(species: StringName) -> bool`, `func pages() -> Array[StringName]` (in `MonsterDB.SPECIES` order, seen only); `class_name Titles` with `HUNT_KILLS := 100`, `TOWER_TITLE := "Vencedor da Torre"`, `MASTER_TITLE: Dictionary[StringName, String]` ("Mestre da Espada", "Mestre da Espada Longa", "Mestre do Machado", "Mestre da Lança", "Mestre da Adaga", "Mestre do Arco", "Mestre do Rolamento", "Mestre da Cura", "Mestre das Lâminas Gêmeas"), `var earned: Array[StringName]`, `var chosen: StringName`, `func grant(id: StringName) -> bool`, `func choose(id: StringName) -> bool`, `static func display(id: StringName) -> String`; title ids `&"hunter_<species>"`, `&"master_<style>"`, `&"slayer_<rare>"`, `&"tower"`; `RunState.bestiary`, `RunState.titles`, `signal title_earned(id: StringName)`.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_first_kill_opens_the_page() -> void:
	T.ok(not run.bestiary.seen(&"slime"))
	run.record_kill(&"slime")
	T.ok(run.bestiary.seen(&"slime"))
	T.eq(run.bestiary.kills[&"slime"], 1)

func test_hundred_kills_gives_hunter_title() -> void:
	# 99 kills: not earned; 100th: earned &"hunter_slime", display "Caçador de Slimes", one title_earned emit

func test_rare_and_mastery_and_tower_titles() -> void:
	# record_kill(&"king_slime"): &"slayer_king_slime" -> "Destronador do Rei Gosma"
	# add_mastery_xp(&"spear", 5400): &"master_spear" -> "Mestre da Lança"
	# Dungeon._win path grants &"tower"

func test_choose_needs_earned() -> void:
	T.ok(not run.titles.choose(&"tower"))

func test_death_resets_bestiary_and_titles_but_keeps_outfits() -> void:
	# kills, a title chosen, an outfit unlocked; die(): bestiary.kills empty, titles.earned empty,
	# chosen &"", the outfit still unlocked
```

- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** `record_kill` updates the bestiary, then grants hunter titles at `HUNT_KILLS` and slayer titles for rares; `add_mastery_xp` grants master titles at level 10; `Dungeon._win` grants `&"tower"` before the scene change. Every grant toasts "Título: <nome>" through `Game.toast`.
- [ ] **Step 4: Run tests.** Expected: `PASS N / FAIL 0`.
- [ ] **Step 5: Commit**

```bash
git add game/logic/bestiary.gd game/logic/titles.gd game/logic/run_state.gd game/world/dungeon.gd game/tests/unit/test_bestiary_titles.gd
git commit -m "feat: bestiário e títulos por feitos, zerados na morte"
```

### Task 26: Bestiary screen and the chosen title

**Files:**
- Create: `game/ui/bestiary_screen.gd`
- Modify: `game/ui/pause.gd` (button "Bestiário", title line), `game/ui/inventory_screen.gd` (title at the top)
- Test: `game/tests/unit/test_bestiary_ui.gd`

**Interfaces:**
- Consumes: Task 25, `MonsterDB` rows, enemy sheets.
- Produces: `class_name BestiaryScreen extends UiPanel` with `tab: StringName` (`&"monsters"` | `&"titles"`), `var page_buttons: Array[Button]`, `func show_page(species: StringName) -> void`, `var title_buttons: Array[Button]`; `PauseMenu.bestiary_button: Button`, `PauseMenu.title_label: Label`; `InventoryScreen.title_label: Label`.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_only_seen_monsters_have_pages() -> void:
	# record slime and king_slime: page_buttons.size() == 2

func test_page_shows_the_facts() -> void:
	# show_page(&"slime"): labels include "Andar 1", the attack text, the weakness text,
	# "Couro Velho" and "Abates: 3"; a TextureRect with an AtlasTexture of crawler.png frame 0

func test_choosing_a_title_shows_on_pause_and_backpack() -> void:
	# earn and choose tower: pause.title_label.text == "Vencedor da Torre",
	# inventory title_label.text the same; no title chosen: both hidden
```

- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** The pause menu gains "Bestiário" between "Mochila" and the exit buttons (allowed whenever the pause opens). Monstros tab: list on the left (rares marked with a small gold dot), page on the right; Títulos tab: earned titles as buttons, the chosen one highlighted, "Nenhum título ainda." when empty.
- [ ] **Step 4: Run tests.** Expected: `PASS N / FAIL 0`.
- [ ] **Step 5: Visual check.** A debug `--bestiary` (PauseMenu opens the screen) with `--kills=slime:3,king_slime:1,stump:100` (Game) `--out=/tmp/bestiary.png`, and the Títulos tab `--tab=titles --out=/tmp/titles.png`: sprite crisp at integer scale, texts wrap inside the frame.
- [ ] **Step 6: Commit**

```bash
git add game/ui game/autoload/game.gd game/tests/unit/test_bestiary_ui.gd
git commit -m "feat: tela do bestiário e título escolhido na pausa e na mochila"
```

### Task 27: Balance pass and docs

**Files:**
- Modify: `game/tools/qa_autopilot.gd` (RESULT gains `mastery=<style>:<level>,...` and `potions=<n>`), `game/logic/mastery.gd`, `game/logic/special_charge.gd`, `game/data/item_catalog.gd` (prices), `game/logic/loot_table.gd`, `game/logic/mission_board.gd`, `docs/balance.md`, `docs/gdd.md`
- Test: existing suites (numbers are read from consts, so they keep passing)

- [ ] **Step 1: Measure.** `--floors=3 --skill=0.8` 5 runs with the starter kit and one weapon. Targets from the spec: weapon mastery level 3 near the end of floor 1, level 6 during floor 2, level 10 only for a full tower in one style; roll and heal reach level 4 to 6 by the end of floor 3. A potion costs more than the gold of one room, so idle healing stays the cheap way.
- [ ] **Step 2: Adjust** `XP_TO_REACH`, `DODGE_XP`, `ROLL_XP`, `HEAL_XP_PER_HP`, `TIER_COOLDOWN`, consumable `base_price`, `ELITE_RELIC_CHANCE` and mission gold only where a target misses; rerun the measurement until they hold.
- [ ] **Step 3: Run tests.** Expected: `PASS N / FAIL 0`.
- [ ] **Step 4: Document.** `docs/balance.md` section "Maestria, consumíveis e missões (15/11)" with before/after tables; `docs/gdd.md`: monsters per floor, elites, rares, mastery, special tiers, style relics, consumables, refine, board, bestiary and titles, and the death rule.
- [ ] **Step 5: Commit**

```bash
git add game/tools/qa_autopilot.gd game/logic game/data/item_catalog.gd docs/balance.md docs/gdd.md
git commit -m "docs: balanço da maestria e camada MMORPG no GDD"
```
