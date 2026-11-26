# Changelog

## 0.3.6
- Priests: removed Cup Check's own Power Word: Shield icon. In a party or raid, Blizzard's frames draw the shield and update it as soon as it breaks, so only the Weakened Soul timer is added.
- The solo frame shows Weakened Soul but not the shield. The client blocks reading your own buffs in combat, so the solo frame cannot tell when a shield breaks mid-fight, and a timer-based icon would be wrong. Your default buff bar still shows it.

## 0.3.5
- Priests: the Weakened Soul icon now uses the real debuff's icon and a red tint, so it no longer looks like the shield. A Power Word: Shield buff icon is shown beside it. Both are driven by your own casts in combat and read the real auras out of combat.
- Fixed the Weakened Soul and Shield icons not showing in combat (the cast target name did not match the unit name).
- Icon layout is now measured under protection and falls back to the last good size, so it cannot error in combat.
- Icons no longer draw cooldown countdown numbers.
- Added `/cupcheck wsdebug` to print shield and Weakened Soul tracking events.

## 0.3.4
- A "Camp Benefits" buff now counts as the class buffs that camp objects substitute for (Fortitude, Mark of the Wild, Arcane Intellect, Divine Spirit, Might, Kings, Wisdom, Strength of Earth). Those icons no longer show as missing when the camp buff covers them. Toggle: "Camp Benefits counts as class buffs" in the options window.
- Priests: a Weakened Soul timer icon appears on a member's frame after you cast Power Word: Shield on them. It is driven by your own casts, so it works with "Display Only Dispellable Debuffs" on and in combat. Toggle in the options window; length via `/cupcheck ws <seconds>` (default 15).

## 0.3.3
- Removed Omen of Clarity from the Druid buff list. It is a passive on the Forever client, so there is nothing to track.
- Icons no longer re-read buffs while you, the player being checked, or a boss encounter is in combat, even before the combat lockdown flag is set. This fixes icons showing on buffed players during some group and raid fights.

## 0.3.2
- The solo frame is now also hidden and shown from group roster events (out of combat), as a fallback for clients where the `[group]` state driver condition does not hide it in a party.
- `/cupcheck debug` now also prints group and raid state and whether the solo frame is shown.

## 0.3.1
- Per-class default tracked buffs: Druid (Mark of the Wild, Omen of Clarity), Priest (Power Word: Fortitude, Divine Spirit, Inner Fire), Mage (Arcane Intellect), Warrior (Battle Shout), Paladin (Blessings of Might, Wisdom and Kings), Shaman (Lightning Shield), Hunter (Aspect of the Hawk).
- Mutually exclusive buffs track only the best known one by default: Mage Armor, then Ice Armor, then Frost Armor; Demon Armor, then Demon Skin.
- Buffs you already enabled or disabled in the options window keep your choice.

## 0.3.0
- Class buff list is now matched by spell name, so it finds whichever rank the character knows instead of relying on a fixed spell ID. Fixes missing entries such as Power Word: Shield and Thorns on the Forever client.
- Added the full set of Classic-era party and self buffs for every class: Druid, Priest, Mage, Warrior, Paladin (blessings and auras), Shaman (Lightning Shield, water spells, totem auras), Hunter, Rogue and Warlock.
- Group versions (Gift of the Wild, Prayer of Fortitude, Prayer of Spirit, Prayer of Shadow Protection, Arcane Brilliance) count as the single-target buff being present.
- Self-only buffs (armors, Inner Fire, Lightning Shield, Omen of Clarity and similar) are checked only on your own frame.
- Default tracked buffs are Mark of the Wild, Power Word: Fortitude, Arcane Intellect and Battle Shout; everything else is listed as untracked until enabled in the options window.
- Added /cupcheck debug, which prints how each buff resolved for the current character.

## 0.2.0
- First public release.
- Missing class buff icons on Blizzard raid frames, with a configurable corner.
- Solo frame shown when not in a group, hidden automatically on joining one.
- Options window (/cupcheck): tracked and untracked buffs per class, custom spells by ID or name, minimap button, class-colored solo frame.
