# Song Wars 5 Vol. 2 — Pass 1

Property of LiveLayer Technology LLC.

A playable, offline Godot fighting-game prototype built from the SWV2 Build Doc, Fighter Chapter Lineups, and Prologue Scene Script. Requires **Godot 4.3 or newer**; tested with **Godot 4.6.3**, using the Compatibility renderer. No external packages, credentials, or environment configuration are required.

## Run

Open `project.godot` in Godot and press **F5**, or run from this repository:

```sh
godot4 --path .
```

First launch asks you to choose Simplified or Traditional touch controls. Both use the same combat simulation. Menus scroll to fit narrow screens; fights support landscape and portrait windows. Settings and progress save locally to `user://songwars_save.json`, with a previous-generation backup. The Settings screen displays its resolved location. Save failures retain unspent points and expose an error.

For an isolated local playthrough that leaves your regular save alone:

```sh
mkdir -p work
godot4 --path . --log-file "$PWD/work/play.log" -- --save-path=res://work/play_save.json
```

## What ships

- Four selectable fighters: **Cin City, Rico Ruffino, Big Hood Tha King, Bank Sinatra**, including mirror matches and Cin City's independently targetable dog sharing her health.
- The **Rooftop** arena, drawn with temporary illustrated shapes and distinct fighter poses.
- Manual attacks and cancels, high/low blocking, timed blocks, chip damage, three-notch meter, prompted minor and big specials, throws and throw breaks, air steering, knockdown/get-up protection, hitstop, and the five-hit rule. Damage stays unscaled.
- Best-of-three CPU matches, 99-second rounds, round countdowns, and Easy/Standard/Hard settings for one seeded CPU brain.
- Free training with reset, full starting meter, idle/guard/CPU dummy choices, and three short practice challenges: Move & Block, Combos & the 5-Hit Rule, and Survive the Big Special.
- The complete three-fight **Prologue**: Bank → Rico → Big Hood. Story panels follow the supplied script; the ending presents Smash's unseen voice before his silhouette and preserves both locked lines. Text stands in for recorded voices.
- Local story progress, per-match attempts, seen scenes, chapter unlock flags, fighter-specific upgrade points, and confirmed purchases. Health costs one point per +5 HP, damage/speed cost three per class; ceilings are 125 HP, Power, and Fast. Upgrades apply only in Story. Replay wins also earn a point.

Story attempts reset in fixed **00:00/12:00 UTC** device-clock periods for this offline pass. Switching fighter does not reset a match's allowance. Settings includes an explicit tester bypass; CPU and training stay available when attempts run out.

All ten locked fighter chapter lineups are preserved in `scripts/progression/story_data.gd`. Prologue wins save Bank/Rico/Big Hood chapter unlocks immediately. Playing those side chapters, the later main tournament, and the remaining roster is deferred to later passes. Online rooms, rollback transport, accounts, and a backend are also deferred. The simulation provides a deterministic foundation for that work; this pass does not connect to a server.

Art, story panels, and hit tones are placeholders. There are no fabricated fighter tracks, final voice recordings, monetization, or external services.

## Controls

Touch uses an eight-direction pad plus the selected layout. Simplified has Punch/Kick; hold Down for low punch/heavy kick. Traditional exposes four attacks, Throw, and Special. A prompted attack also gets a dedicated touch target. HOLD BLOCK is available in both layouts.

| Keyboard | Action |
|---|---|
| WASD / arrow keys | Walk, crouch, jump; steer in the air |
| J / U | Light punch / low punch |
| K / I | Kick / heavy kick |
| Down + J/K in Simplified | Low punch / heavy kick |
| Space | Hold Block; tap and keep holding when defending a big special |
| L | Throw shortcut |
| O | Special prompt shortcut; hold Back for minor, Forward for big |
| Esc | Pause/resume; combat windows freeze |
| M | Mute/unmute placeholder effects |
| F2 in training | Refill both meters |

Back and Forward are relative to your fighter's facing. Hold Back to block high; Down + Back blocks low. There is no air block. A clean timed regular block starts within 0.25 seconds of impact and earns half a notch once per engagement.

Double-tap **Back** with one notch for a minor prompt, or **Forward** with three for a big prompt; press the shown attack within two seconds. A missed minor prompt costs nothing; a missed big prompt costs one notch. Big-special defense requires a new Block press and a sustained hold; jumping before capture can evade it.

Throw with **Back → Forward → Punch** at close range while holding at least one notch, or use the shortcut. Throws hold rather than spend meter and deal 10/15/20 damage. While grabbed, input **Back → Back → Down** within 0.6 seconds to break free.

## Automated checks

From the repository root:

```sh
bash tests/run.sh
```

Or run the two suites individually:

```sh
mkdir -p work
godot4 --headless --path . --log-file "$PWD/work/tests.log" --script tests/run_tests.gd
godot4 --headless --path . --log-file "$PWD/work/ui-smoke.log" --script tests/ui_smoke.gd -- --save-path=res://work/ui_smoke_save.json
```

Both commands exit with status 0 on success. Progression tests and UI smoke saves use ignored `work/` paths, separate from a player's save. Logs are also ignored. The explicit `--log-file` location is useful in restricted execution sandboxes; it changes no environment settings.

| Suite | Checks |
|---|---|
| Fight simulation | Roster values, attack startup/damage, held/timed and high/low blocks, chip, meter, special molds and splits, big defense/release/evade, throws/breaks/whiffs, five-hit knockdown, dog/shared-health behavior, movement, simultaneous contacts, round rules, CPU behavior, seeded replay and snapshot restoration |
| Progression | Fighter-specific earnings/spending, replay rewards, upgrade quotes/caps, save reload, backup recovery and corrupt data bounds, attempt limits/reset/bypass, sequential progression, chapter unlocks, locked lineups and exact ending dialogue |
| UI smoke | First-run layout, all four selections, CPU stepping, pause, training, multitouch/layout mappings, story panels/results/upgrades, gate staging, disk reload, and screen/control bounds in landscape/portrait phone and desktop sizes |

The smoke test invokes the real menus and simulation. Its story-result fixtures exercise progression wiring; fight outcomes and combat rules are tested separately by the simulation suite.

## Simulation contract

`scripts/combat/fight_sim.gd` is a `RefCounted` simulation, independent of scenes, rendering, audio, wall-clock time, and device input. `setup(p1_id, p2_id, upgrades1, upgrades2, training, seed)` initializes a match. Call `step([p1_input, p2_input])` exactly once per 60 Hz tick. Timers, health, meter, positions, movement remainders, and gameplay RNG state use integers.

Each player's input is a dictionary:

```gdscript
{"move": -1, "down": false, "jump": false,
 "attack": "light", "block": false, "tap": ""}
```

`move` is world-left/right (`-1/0/1`); `attack` is a one-tick press: empty, `light`, `low`, `kick`, `heavy`, `throw`, or `special`. `tap` optionally supplies the relative gesture token `back`, `forward`, or `down`; otherwise direction transitions generate gestures. Held attack buttons do not auto-chain in the UI.

For replay, retain the setup arguments/seed and record both sampled input dictionaries for every tick, including countdown and hitstop ticks. Replay the same ordered pairs through `step`. `snapshot()`/`restore()` round-trip fight state for resimulation. The CPU has its own seeded `setup` and `snapshot`/`restore`; record its emitted inputs alongside the player's inputs, or preserve its state when regenerating decisions. Actual network delay, rollback buffering, server verification, and input-log persistence belong to the later online implementation.

Presentation reads `fighters`, `projectiles`, round/timer fields, and the current tick's `events`. Upgrades are passed into setup only by Story; CPU/training use base stats. Local saves and story content live under `scripts/progression/`, while `scripts/ui/` contains drawing and touch input.
