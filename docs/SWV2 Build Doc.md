# SWV2 Build Doc — SongWars Vol. 2

**Property of LiveLayer Technology LLC.**
Ownership / metadata rule: all builds are Property of LiveLayer Technology LLC. All code is scrubbed of all metadata except that — no other metadata or ownership marks are retained.

Compiled 2026-11-08 from the Part Two planning (Grok conversation, 797 messages) and the Muse continuation decisions 1–86 (2026-11-07/08). This document contains only decisions currently in force. Superseded material — the tier system, the 18-fighter full-import roster, select-screen stat bars — has been removed and must not be built.

---

## 1. The game

- Vol. 2 of SongWars (Vol. 1: play.songwars5.com, pixel-art fighter). Direction: better mechanics, better graphics, better control, better overall game.
- Phone-first (keyboard/controller after). Easy basics, deep mastery. Fast, aggressive pace.
- Art direction: illustrated style (the Cin City Vol. 2 set is the reference), not pixel art.
- Match format: best of 3 rounds, 99-second rounds (host may choose custom match settings online). Win by KO or more health at timeout.
- Modes at full launch: Story, Online (private / quick match / public rooms), Training, Player vs CPU.
- The game is free. Monetization is donations only (Section 13) plus optional rewarded ads later, only if an ad network is set up first.

### First playable (the prototype build)

- 4 fighters: **Cin City, Rico Ruffino, Big Hood Tha King, Bank Sinatra**.
- 1 stage: **Rooftop, redrawn illustrated**.
- Private online matches by room code/link. No spectating yet.
- One story chapter: the **Prologue** (Section 7). Temporary illustrated scene art (real story video assets come later).
- Fighter-specific story upgrades working. No monetization.
- No public accounts: progress saves on the testing device; authorized testers can bypass the 3-attempt story limit. Cross-device saves come with accounts.

## 2. Controls

- Movement pad: walk, jump (Up / up-forward / up-back). Full air steering, including reversing direction mid-jump. No dashes (double-taps are reserved for special prompts). No air blocking.
- Blocking: hold back (standing), down-back (low attacks). High/low attacks must be blocked in the matching position.
- Two touch layouts ship; the player switches in Settings. A layout is an input skin, never a power difference — both feed the same move system at the same strength and timing.
  - **Simplified:** movement pad + Punch + Kick. Low attacks = Down + Punch/Kick.
  - **Traditional:** movement pad + 4 attack buttons (Light Punch / Low Punch / Kick / Heavy Kick), Vol. 1 style, plus Throw and Special as Vol. 1 had them.
- No silent default: on first launch the player picks their layout; the pick saves as their layout; training teaches the picked layout.
- Switching is between matches only — never mid-fight, not via pause, not between rounds.
- Portrait menus; landscape recommended for fights, portrait fighting available by choice. Tested touch presets per orientation; no free button repositioning.

## 3. Combat system

### Damage — no scaling, ever

There is **no damage scaling anywhere**. Every hit deals full listed damage in any combo position; specials deal full totals cold or combo'd in. The 5-hit knockdown limit is the only anti-meltdown rule.

Base ladder (before damage class):

| Move | Damage |
|---|---|
| Light Punch | 4 |
| Low Punch | 5 |
| Kick | 6 |
| Heavy Kick | 9 |

Standard mixed 5-hit combo (Light, Light, Low, Kick, Heavy) = 28.

### Damage classes (regular moves only)

| Class | Light / Low / Kick / Heavy | 5-hit combo |
|---|---|---|
| Light | 3 / 4 / 5 / 8 | 23 |
| Standard | 4 / 5 / 6 / 9 | 28 |
| Power | 5 / 6 / 7 / 10 | 33 |

Specials and throws are **universal** — damage class never applies to them: minor special 14, big special 45, throws 10/15/20 for every fighter.

### Health, speed, reach

- Health on the 100 scale, wide range, assigned in 5-point steps only: 80 / 85 / 90 / 95 / 100 / 105 / 110 / 115 / 120 / 125. Design rule: a low-health fighter must be paid back in speed, damage, or reach.
- Speed classes (movement; jump travel scales with it): Slow 90% / Standard 100% / Fast 110%. Attack speed is animation, governed by the universal timing table (Section 4).
- Reach classes (regular attacks only): Short 90% / Standard 100% / Long 110%.
- **No tiers. No strength indications anywhere** — no labels, badges, or stat displays. Strength is shown by the eye test and gameplay.

### Combos

- Fully manual, no auto-chains. **5 consecutive regular hits force a knockdown** and end the combo.
- Specials are the only way past 5 hits; a special completes its full hit count, then causes the knockdown. A player may transition from a regular combo into a special before hit 5.
- Knocked-down fighters take no damage and cannot be grabbed through get-up, until they can act again.

### Meter (3 notches)

- Internal unit: 1 notch = 20 points; full meter = 60.
- Landed regular hit: **4 points** (5 hits = 1 notch; every clean 5-hit combo earns exactly 1 notch).
- Well-timed block: **10 points (½ notch), once per engagement** — later hits blocked while holding in the same combo pay nothing.
- Taking damage pays 0. Special hits pay 0.
- At most 1 notch carries between rounds.
- **Minor special (1 notch):** double-tap back → prompted button, 2-second window; missing the window costs nothing.
- **Big special (3 notches):** double-tap forward → prompted button shown to that player only, 2-second window; missing the window drops meter 3 → 2.

### Blocking and chip

- Timed-block window (regular attacks): block starts within **0.25s** before the hit = timed block: zero chip + 10 meter points.
- Held block vs regular attacks: **1 chip per hit, 2 for Heavy Kick**. Chip can KO.
- Minor special blocked in the correct position: **3 chip total** (multi-hit spreads it across hits), including on a timed block. Chip can KO. Wrong-position block = the special lands clean for 14.
- Big special defense: defender-only timed Block prompt — tap at the right moment and **keep holding**. Success: 50% damage reduction and a guaranteed minimum of 1 HP if held through the whole special. Releasing early ends protection for the remaining hits; no second attempt within that special.
  - Prompt window: **1.0s base, 0.5s floor**, shrinking **0.1s per full 5 damage** already dealt in the current combo (0 dmg → 1.0s · 5 → 0.9 · 10 → 0.8 · 15 → 0.7 · 20 → 0.6 · 25+ → 0.5s).
  - No connect is needed to start a big special; it works from any distance. Startup has an animation + sound cue; there is no on-screen Jump prompt.
  - Airborne defenders get no Block prompt, but a correctly timed jump before capture evades it: the whiffed big special refunds 2 notches (net cost 1) and the attacker is stuck in **1.5s recovery**.
  - A big special cannot be activated while the opponent is knocked down or getting up.

### Throws

- Input: back → forward → punch, close range. **Universal grab distance** for every fighter (reach class does not apply).
- Requires at least 1 notch; spends none. Damage by meter HELD at connect: **10 (1 notch) / 15 (2) / 20 (3)**.
- Breakable: after the grab connects, the defender completes back → back → down within **0.6s** (same window at every meter level; this input takes priority over the double-back minor-special trigger while grabbed). Successful break: no damage, fighters separate, no guaranteed follow-up.
- A throw counts as 1 hit toward the 5-hit limit, can end a regular combo, and causes a knockdown if unbroken.
- Whiffed throw: attacker cannot move or block for **0.8s**.

### Specials

- **Minor special: 14 damage total**, same for all three molds — close-range multi-hit, ranged projectile, lunging attack. Delivery differs; the total never does.
- **Big special: 45 damage total**, unique per fighter (Section 6). Hit splits are freeform per fighter — there is no universal rounding rule: per-hit halving on a held Block (fractions dropped) must land the blocked total at **22 or 23**. Every specced special must be checked against this.

## 4. Universal timing table (locked)

One frame-data table for every fighter in the first build. Fighters differ by stats, never by hidden timing. Per-fighter timing is a later polish layer only. 60 fps; frames = startup / active / recovery on whiff, then hitstun / blockstun inflicted, and hitstop.

| Move | Startup | Active | Recovery | Hitstun | Blockstun | Hitstop |
|---|---|---|---|---|---|---|
| Light Punch | 5 | 3 | 8 | 12 | 8 | 2 |
| Low Punch | 6 | 3 | 10 | 13 | 9 | 2 |
| Kick | 8 | 4 | 12 | 15 | 10 | 3 |
| Heavy Kick | 12 | 4 | 18 | 18 | 12 | 5 |
| Throw (grab) | 6 | 3 | whiff total = 0.8s (48f) | — | — | — |
| Minor special — multi-hit | 10 | per design | 16 | per design | per design | 3 |
| Minor special — projectile | 12 | projectile travel | 16 | 14 on hit | 10 | 3 |
| Minor special — lunge | 9 | travel | 16 | 14 on hit | 10 | 3 |
| Jump | air ≈ 42f (0.7s) | — | 4 on landing | — | — | — |

Chain check (verified): every hitstun ≥ the next move's startup, so the standard 5-hit combo chains at every step; a minor special (startup 9–12) also chains from a 4th regular hit's stun (13–15). Nothing starts faster than 5 frames (touch-input lag floor). Heavy Kick is the punishable power button: biggest regular damage, slowest startup, longest whiff recovery. Big specials have no frame-startup row — their startup is the animation cue + Block prompt system. The walk-speed base value (the 100% the classes scale) is engine tuning, not a design lock.

## 5. Roster — the Legacy Players

The 10 starting fighters are **the Legacy Players**, the founding group. Any later additions will not be as strong as this group (fence below).

| Fighter | HP | Damage | Speed | Reach | Minor mold |
|---|---|---|---|---|---|
| Tyshawn Smash | 125 | Power | Fast | Long | Multi-hit |
| Big Hood Tha King | 105 | Power | Slow | Long | Lunge |
| Loe Budda | 105 | Power | Slow | Standard | Projectile |
| Bank Sinatra | 100 | Standard | Standard | Standard | Projectile |
| Cin City | 100 | Standard | Fast | Short | Lunge (dog) |
| Rico Ruffino | 100 | Standard | Standard | Long | Multi-hit |
| J.O NextLevel | 100 | Light | Fast | Standard | Multi-hit |
| Rock Out Ali | 95 | Standard | Fast | Standard | Projectile |
| Zayy Bizz | 95 | Light | Fast | Short | Lunge |
| LMSCURT | 95 | Power | Fast | Short | Multi-hit |

- **Tyshawn Smash is the strongest fighter and it is not close.** Sole 125 health; Power damage, Fast speed, Long reach — he starts at the ceiling of all three upgradeable stats. Nothing in the game labels this; it is felt in gameplay.
- Availability: the other nine are selectable from the start. **Smash is the only locked fighter**: he is the story's final boss, and beating him in story mode unlocks him as playable in all modes, including online. The unlock lives on the player's account (guests save nothing and cannot hold it).
- Select screen: **portrait + name only** — no stat bars, numbers, or strength indications.
- On hold, not cut (later additions): Sticky Money, Taf Nixon, Invincible Chef, NSC Krew, Hublo, Baby Kocaine, John Blaze, Nyte Fye.
- **Additions fence (checkable rule):** later additions are built to base health **85–95** and may **never hold Power damage and Fast speed together**. The rule governs base stats (online plays base stats); story upgrades still climb to the shared ceilings in story mode only. Each addition's stat sheet is written when it is built, inside this fence.
- **Mirror matches are allowed in every mode** — story, CPU, and online. The second player in a mirror uses the fighter's alternate colorway (palette work, not new art).

## 6. Big specials (45 total each; blocked total in parentheses)

Names marked (user) are the user's own and locked, with spellings exactly as given. Names marked (working) are accepted working names, renameable by the user at any time.

| Fighter | Name | Hit split | Blocked |
|---|---|---|---|
| Tyshawn Smash | System Shut Down (user) | 5 → 10 → 10 → 20 | 22 |
| Big Hood Tha King | KING'S VERDICT (working) | shoulder charge 10 → slam 15 → crown drop 20 | 22 |
| Loe Budda | ENLIGHTENMENT (working) | 5 → 10 → 10 → 10 → 10 | 22 |
| Bank Sinatra | Droppin Jewelz (user) | 10 → 10 → money finisher 25 | 22 |
| Cin City | Off The Leash (user) | dog nip 4 → punch 6 → kick 5 → dog pulls off balance 10 → rising uppercut with the dog 20 | 22 |
| Rico Ruffino | The Wolf Flip (user) | 6 / 6 / 6 / 7 → finisher 20 | 22 |
| J.O NextLevel | Stand On Buisness (user) | 4 / 4 / 4 / 4 / 4 / 5 → finisher 20 | 22 |
| Rock Out Ali | GUITAR SMASH (Vol. 1 name) | 10 / 10 / 10 → guitar smash 15 | 22 |
| Zayy Bizz | BIZZ FINALE (working) | 5 → 10 → huge finisher 30 | 22 |
| LMSCURT | CURT CALL (working) | 8 / 8 / 9 → finisher 20 | 22 |

### 6.1 Cin City and the dog

- The dog is a separately targetable partner. Cin City and the dog share **one health bar**; a single attack hit damages the shared health only once even if it hits both.
- The dog is automatic — no extra button. Dog hits count in the shared 5-hit regular combo count and pay **half meter (2 points)** per landed hit.
- The dog keeps attacking while Cin City is grabbed, knocked down, or captured, and can interrupt regular attacks and throws — but **cannot interrupt a big special**.
- The dog does not block or auto-dodge. Knockdown/get-up protection is shared (no damage through the dog while Cin City is protected).
- Her big special (sequence locked): the dog distracts at the opening, assists between Cin City's fast punches and kicks, pulls the opponent off balance, and Cin City finishes with a **rising uppercut with the dog** — the dog is part of the finish; Cin City lands the main blow.

## 7. Story mode

- Premise: fighters are pulled from real life into the game universe and must fight in a tournament hiding a larger conflict, or their music, content, and public identities will be erased and the world will forget they existed. The **only truly real element is the SongWars5 event** (Sunday, November 22, 2026, 7:00–11:00 PM EST) — the story's road leads to it. All character stories and rivalries are fictional. The event is a fiction anchor only: no build deadline, no dated in-game event mechanics. **Standing fiction rule: no body switching, doubles, or copies — with exactly one exception:** Smash's fighter chapter ends against the bound copy the cause kept at the gate (see the Fighter Chapter Lineups draft). That beat stands alone; the concept appears nowhere else in the fiction. (Mirror matches in Section 5 are otherwise a match rule only and carry no fiction.)
- The cause behind it stays hidden at first and is revealed gradually. **The full reveal lands at the finale, through Smash himself.**
- **Smash is the cause's prisoner-guard.** The strongest fighter is held as the gate's guard; he fights because he is bound to. Beating him **frees him — and the freeing is the playable unlock**.
- Structure: a shared main story + individual fighter chapters. The player chooses which fighter to use in each main-story match.
- **Main story: 3 chapters × 3 fights, then the Smash finale — 10 fights.**
  - Chapter 1: Zayy Bizz · Rock Out Ali · J.O NextLevel
  - Chapter 2: Cin City · Rico Ruffino · Bank Sinatra
  - Chapter 3: LMSCURT · Loe Budda · Big Hood Tha King
  - Finale: Tyshawn Smash
- **Prologue (ships in the first playable, permanent content before Chapter 1):** the pull-in opening; fights in order Bank Sinatra → Rico Ruffino → Big Hood Tha King; short scenes between fights; ends on the Smash tease in two beats — first his **voice** (heard, unseen), then his **silhouette at the gate** as the prologue closes — no Smash fight.
- If the player's pick is the scheduled opponent, the match is a **mirror match** (Section 5).
- **Fighter chapters:** one per fighter, **3 fights each, played AS that fighter**; **a fighter's chapter unlocks the moment you beat that fighter in the main story** (per-fighter trigger, not chapter-completion batches). Optional side stories, not required to advance the main story. Smash's chapter unlocks at the finale win — the same event that frees him and unlocks him as playable. **Opponent lineups are LOCKED** (full version with per-fight rationales in the "Fighter Chapter Lineups" document in this folder):
  - Zayy Bizz → Rock Out Ali · Rico Ruffino · Big Hood Tha King
  - Rock Out Ali → J.O NextLevel · Cin City · Loe Budda
  - J.O NextLevel → Zayy Bizz · LMSCURT · Rico Ruffino
  - Cin City → LMSCURT · J.O NextLevel · Loe Budda
  - Rico Ruffino → Bank Sinatra · Zayy Bizz · Loe Budda
  - Bank Sinatra → Rock Out Ali · Rico Ruffino · LMSCURT
  - LMSCURT → Zayy Bizz · Cin City · Big Hood Tha King
  - Loe Budda → Bank Sinatra · Big Hood Tha King · J.O NextLevel
  - Big Hood Tha King → Rock Out Ali · LMSCURT · Cin City
  - Tyshawn Smash → Rico Ruffino · Bank Sinatra · Smash (mirror — the bound copy at the gate; the one exact concept of its kind, per the standing fiction rule above)
- Attempts: **3 attempts per individual match per 12-hour period**. Attempts belong to the match, not the fighter (switching fighters does not reset them). Refresh at two fixed server reset times 12 hours apart (not personal cooldowns). A player must win the current match to advance; after attempts run out, story progression pauses until the next reset but saved progress remains, and the player is directed to training and online (the rest of the game is not locked). Completed fights may be replayed inside the same match's 3-attempt allowance and still earn points.
- Returning to Story lands the player at the next unfinished match's preview (continue or browse chapters). After a loss with attempts remaining, results offer Retry or Return to Story; fighter changes happen at the match preview and keep the same attempt count.
- Scenes/video: short pre-match videos, skippable after a set point; major chapter scenes unskippable, carrying both in-world branding and clearly labeled sponsor video spots. On a loss/retry, pre-match video does not replay — retries go straight to the fight with an optional Replay Story button. Subtitles on by default, toggle available. The soundtrack keeps playing very quietly under story videos/sponsor spots, video audio in front.

## 8. Story upgrades and economy

- Winning story fights earns **upgrade points: 1 per win; replay wins also pay 1**.
- Points are **fighter-specific** (only the fighter who earned them can spend them), permanent, with an exact-change confirmation before committing. Points save automatically after a win and are spent later in a separate upgrade menu reachable from both the roster and Story; the roster opens from inside the player profile.
- Upgradeable stats: health, damage, movement speed. **Same final ceilings for every fighter** (base stats only set the starting point):
  - Damage: **class jumps** (Light → Standard → Power), **3 points per jump**, ceiling Power. A Power fighter has no damage purchase.
  - Speed: **class jumps** (Slow → Standard → Fast), **3 points per jump**, ceiling Fast.
  - Health: **+5 HP per point**, ceiling **125** for everyone.
- Earned story upgrades apply in **story mode only**. Online uses base stats. (Donor boosts are the exception — Section 9.)
- Reference: the most expensive full build (Zayy Bizz) costs 12 points; a cleared fighter chapter is worth exactly 3 points = one class jump. Smash starts at all three ceilings and has nothing to buy.

## 9. Donor system

Donations run through **pay.livelayertech.net** (Section 13). Donor rewards are permanent and **donor-only — they cannot be earned through gameplay**:

- **Extra story attempts:** a qualifying donation adds **3 attempts** to the player's current story match.
- **Cosmetics** (all three unlock together on the first qualifying donation): an exclusive fighter outfit/color variation, a post-match victory effect, and a profile badge. Fighter cosmetics and victory effects are equipped from the roster; badges from the profile.
- **Stat power-up that works in ALL modes, including competitive online:**
  - Before each match the donor chooses **one stat** to boost; the choice stays hidden from the opponent. The game must still disclose publicly that donor boosts can apply in online matches.
  - The boost applies across the donor's whole roster and speaks the story-upgrade language (health steps of +5; damage/speed class jumps) — but **donor steps can push past the story ceilings**.
  - **Caps on the donor contribution:** health **+15** (absolute max 140); damage **+2 steps** (a Power fighter tops out at 7 / 8 / 9 / 12); speed **+2 steps** (a Fast fighter tops out at 130%). Only one stat is boosted per match, so no fighter is beyond-ceiling in everything at once.
  - **Specials are never donor-boosted** — minor 14 / big 45 stay universal.
  - **Milestone ladder (cumulative lifetime donations, not single gifts): Step 1 at $10 · Step 2 at $30 · Step 3 at $60.** A donor's step count is how many steps of boost they may apply to their chosen stat, subject to the per-stat caps (health needs 3 steps to cap; damage and speed cap at 2). Beyond $60, milestones are cosmetics/status only. The first qualifying donation also fires the attempts + cosmetics bundle above.

## 10. Online

- Accounts are required for saved progression, check-ins, and online play. Guests can train and play CPU matches. Sign-up/sign-in: email+password or Google. A brand-new player lands on the main menu and chooses a mode immediately (story/training available, not required). If a guest taps Story or Online and then signs in, they go **directly to the mode they selected**.
- **Unlock ladder** — two independent routes; either one unlocks each feature:
  - Play route: finish **3 private matches** (win or lose) → quick match. Win **3 quick matches** → public lobbies + spectating for private matches.
  - Check-in route: check-ins are credited automatically when a signed-in player opens the game in a new 12-hour reset period (one per period). **3 check-ins → quick match; 6 → public lobbies + private spectating.**
  - Locked modes stay visible but greyed out with a lock icon; tapping one shows the requirements and the player's progress on both routes.
- Server-side backend tracks wins, losses, check-ins, unlocks, and XP; match results are validated by the server. Account XP comes from completed matches, story milestones, and daily check-ins, with extra XP for wins.
- **Quick match:** the player chooses their fighter before searching; all fighters legal. Once matched, both players confirm readiness before the match starts. Rematch allowed if both agree, with the same fighters. First version: plain waiting screen while searching. (Later addition, not first version: a "LiveLayer Tetris" minigame while waiting.)
- **Public rooms — winner stays:** players enter as spectators and choose Join Queue ("Put me in line") when ready. A challenger picks a room-legal fighter **before** joining the queue. Stage is random each match. The reigning winner keeps the same fighter while they hold their spot. Hosts can set a consecutive-win cap or let the winner stay until defeated. After losing, a player automatically rejoins the back of the line unless they choose to watch. Queued players see only their own position and are notified when they are next; an unready challenger is skipped to the back of the line.
- Room settings: hosts set a **minimum player level** and the win cap. **There is no fighter-tier filter** — every fighter is legal in every room. Rooms are found by browsing a list showing player counts and entry requirements.
- Host leaving: hosting transfers to the co-host; with no co-host the room closes, but an active match finishes and its result is recorded before everyone returns to the room browser.
- **Spectating:** text chat + preset reactions, with host moderation (mute/remove). Spectator chat overlays the gameplay in a translucent glassmorphic style and cannot be hidden by spectators. **Fighters see neither spectator chat nor reactions during a match**; chat becomes visible to fighters between/after matches. Private-match spectating (once unlocked): anyone with the room code can request to spectate, but the host must approve; if the host will be fighting, a co-host must be selected beforehand to handle approvals. Co-host permissions are host-selected (admissions, moderation, queue management, room rules); the host and co-host cannot fight each other in that room.
- **Disconnects and pause:** a temporary connection drop does not pause the match — it keeps running and the disconnected fighter can take damage until reconnect. Quitting, leaving, or turning the screen off = immediate forfeit. Switching apps / answering a call gets a **15-second return window** while the match keeps running and damage applies; staying away beyond 15 seconds = forfeit.
  - Online pause: each player has **60 seconds of total pause per match**, shared across all their pauses; exceeding it = default loss. Pause is immediate, even mid-combo or mid-special; on return the action resumes from the exact frozen moment with **no countdown**. All gameplay timing windows freeze during pause (special prompts, Block timing, throw-break windows); only the pausing player's allowance keeps counting. Settings opened while paused counts against the allowance. Pause menu: Resume / Settings / Quit Match; Quit Match requires a forfeit confirmation (allowance keeps counting during it).
- **Leaderboard:** quick matches and public-room results only (private matches never count). Rank by **total wins**; losses are recorded but do not subtract. Every eligible completed win counts, including repeated wins against the same opponent. Lifetime, no seasonal resets.
- **Online results:** one compact screen — winner, round score, earned XP, level progress, new unlocks. In public rooms, results stay up until each player taps Continue while the room moves on; a winner still on results when the next challenger is ready gets a readiness prompt overlaid on results (no response in time = back of the line).
- **Infrastructure (locked):** the backend is a **custom server running on LiveLayer's own server** — accounts, matchmaking, rooms/queues, leaderboard, check-ins/XP/unlocks, spectator chat, and the admin area are all built into it (no third-party game-services platform). LiveLayer owns uptime, scaling, and security.
- **Netcode (locked): rollback.** Both devices run the fight locally and exchange inputs only; late inputs rewind and re-simulate. Numbers: **input delay 2 frames; max rollback 8 frames** (fixed for the first build; adaptive delay is a later candidate). The fight engine must therefore be **deterministic from the first build** (same inputs → same fight on every device). The server does not run live fights; it **verifies results by replaying the recorded input log** — a result that doesn't reproduce doesn't count.
- **Connection quality (locked): NO GATE.** Every connection plays and every completed result counts, in every mode — no quality threshold, no pre-match decline step for counted matches. Rough connections may visibly snap past the 8-frame repair range; the result still counts.

## 11. CPU mode and training

- **One CPU brain, one difficulty dial** (reaction speed, block rate, combo use, special use scale together). No adaptive/rubber-band behavior.
- CPU mode offers three stops on the dial (easy / standard / hard). Story mode sets the same dial per chapter: prologue and Chapter 1 low, rising through Chapters 2–3, Smash finale at maximum. **Fighter chapters climb inside themselves: fight 1 low, fight 2 standard, fight 3 high** — maximum stays unique to the main-story Smash finale.
- CPU match start: pick fighter + opponent + stage, or pick your fighter and randomize the rest. CPU results offer: Rematch, Random Next Opponent, Change Fighter/Opponent/Stage, Main Menu.
- Training ships in the first version with both free practice and guided lessons. Guided format: a quick video demo, then **one** short hands-on challenge, then back to playing — never drawn-out lessons. Training teaches the layout the player picked at first launch. **The guided set is exactly 3 core lessons (locked): (1) Move & Block, (2) Combos & the 5-Hit Rule, (3) Survive the Big Special.** Meter/special inputs and throws/breaks have no guided lesson — they're learned in play through the game's own prompts and free practice.

## 12. Accounts, profiles, safety

- Public profile: name, avatar, account level, eligible online win total. A private match-history screen is deferred to later (the server still tracks results).
- Display names are **permanent**: a permanent display name linked to a unique player ID, unchangeable after confirmation.
- Avatars: choose a game avatar or upload a custom image. Uploads that pass automatic checks may appear publicly; flagged uploads go to an administrator. In-game reporting covers inappropriate images/names, chat/harassment, suspected cheating/exploits, and room/host misconduct.
- **All reports are reviewed by the owner personally, who makes the final enforcement decision** (no automatic penalties). Admin tools (in a protected in-game admin area, owner account only): dismiss or warn, remove content, restrict chat or uploads, temporarily suspend online access, permanently ban. Penalized players are told the reason and directed to support (Contact Support opens the player's email app with the recipient prefilled; no in-game appeal flow).

## 13. Revenue and support

- Support/donations run through **pay.livelayertech.net** (Vol. 1 used support.songwars5.com — Vol. 2 does not).
- Until/unless an ad network is set up first, monetization is donations behind a **creative paywall**: a dismissible support screen the player can X out of, which must never block play. It appears only occasionally after matches **and** when story attempts run out.
- A clearly visible **"Support LiveLayer" button** stays available at all times. The support screen offers preset donation amounts with listed rewards and progress toward the next donation milestone (Section 9).
- Optional rewarded ads are planned **only if** an ad network is set up first; rewarded ads are separate from the sponsor spots in story videos.
- No monetization of any kind in the first playable.

## 14. Menus, flow, presentation

- Main menu: direct buttons for Story, Online, Training, CPU, plus the always-visible Support LiveLayer button. Illustrated game-world backgrounds with transparent glassmorphic panels.
- Loading screen: both fighters' portraits and names, loading percentage, sometimes a short combat tip, and "LiveLayer Technology LLC" at bottom center with a glowing, pulsing effect. If an online opponent is still loading, the ready player sees the arena/fighters frozen with "Waiting for opponent."
- Rounds start with a 3-second "3, 2, 1, Fight!" countdown; between rounds: brief result, reset, countdown again.
- Soundtrack: the music is **the fighters' own tracks** — the roster is the soundtrack — including tracks the user created himself. The player runs them as an automatic playlist with a mute control; during fights, artist name + song title show in a small persistent, slightly transparent glassmorphic display. (Vol. 1 showed no artist/song information anywhere — this is a Vol. 2 fix.) **Mapping (locked): fighter-led in story** — in story mode, a fighter's own track leads their fights and their fighter chapter; everywhere else the playlist rotates. Every track therefore carries fighter metadata. **Depth (locked): exactly one signature track per fighter** — one track per artist, the one that leads their story fights; the user's own created tracks join the pool alongside the ten. **The user personally picks each fighter's track from their catalog** (not the artist's pick). Each artist's permission for the chosen track is production outreach, still to be collected; the user's own tracks need none.
- Graphics quality is automatic per device; no manual quality selector. A reduced-motion setting is explicitly out of the first version.
- Offline: if the server can't be reached, training, CPU matches, and downloaded story content remain playable; story progress syncs after reconnection. Story chapters save automatically once played; players can also manually download other unlocked chapters in-game. Check-ins and online matches require the server.

## 15. Art and stages

- Fighters and stages use the **illustrated style**. Vol. 1 stages are **redrawn, not replaced**.
- **Fighter art template (locked):** Cin City's 44-image Drive set is the production template for every Legacy Player — idle/walk frames, punch, kick, uppercut, crouch-uppercut, low punch, sweep, roundhouse, lunge, throw, block, crouch, jump, hurt, dizzy, getup, KO/win panels, finisher, minor-special action, big-special sequence, portrait, reference, and move/frame sheets. Fighter-specific items (her dog lunge) map to that fighter's equivalent special actions. No trimmed core set.
- **Launch stages (8):** Rooftop, Historic House, Waterside Park, Bear Den, LOVE Park, Park St Platform, East New York — all redrawn — **plus one brand-new stage**. The new stage's concept is deliberately undecided until the art pass (candidates on record, not chosen: the Gate; a SongWars5 event stage).
- Stages are visual differences only — scenery, lighting, music. No hazards, no combat advantages.

## 16. Vol. 1 → Vol. 2 fixes (from the verified live study of play.songwars5.com, 2026-11-07)

- Select screens must not clip: Vol. 1's fighter/stage select bottom row sat flush/clipped at the panel edge. Every screen must fit its content in both orientations.
- P1 select needs a back control (Vol. 1 had none), and the "Change your fighter" path on the CPU-pick screen must be reachable (in Vol. 1 it sat below the visible panel, unscrollable).
- The mode indicator must reflect the actual mode (Vol. 1's header pill read "MODE PLAYER VS CPU" even on the online screen).
- Meter readability: Vol. 1's HUD did not clearly explain when throws/specials became available; Vol. 2's notch system and prompts (Section 3) are the fix.
- Results screens: Vol. 2 adds the compact online results (XP, level progress, unlocks) — Vol. 1 offered only Play Again / Main Menu.
- Load time: Vol. 1 took ~15 seconds to PRESS START in the study session. Treat load performance as a launch quality bar, not an afterthought.
- **Unverified — do not cite either way:** Vol. 1 keyboard fighter control could not be verified from the remote study browser (synthetic key taps produced no attacks while UI keys worked). A human retest on a real keyboard is required before Vol. 1 control responsiveness is claimed as a flaw or a strength.

## 17. Open items (production and content — not design)

Everything above is decided. The following are deliberately open and must not be guessed by a builder:

1. The brand-new 8th stage's concept (parked until the art pass).
2. Story scene scripts (the fighter-chapter opponent lineups they are written against are locked in Section 7).
3. The soundtrack track list itself, and collecting each fighter-artist's permission for their tracks (source and mapping are locked in Section 14).
4. The custom server's implementation stack (the route is locked in Section 10 — custom server on LiveLayer's own hardware, rollback netcode; language/framework choices are the builder's).
5. Story video asset production (the full game uses video assets; the first playable uses temporary illustrated scenes).
6. The Vol. 1 keyboard human retest (Section 16).

---

*End of SWV2 Build Doc. Sources: Grok "Part Two" planning PDF (Drive), vol2-build-continuation.md decisions 1–86, vol1-to-vol2-correlation.md — all Property of LiveLayer Technology LLC.*
