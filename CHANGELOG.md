# Changelog

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
