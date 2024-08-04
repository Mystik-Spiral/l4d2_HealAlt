---
> ## `Healing Alternative` <sub>(l4d2_HealAlt) by</sub> ***Mystik Spiral***
>
> #### Left4Dead2 Sourcemod plugin to improve when healing items (first aid kits, pain pills, and adrenaline shots) are used.
---

#### `Summary of healing behavioral changes`:  

- Bots prefer to use pills/adrenaline before first aid kits, except in safe rooms.
- As long as they are available, bots will keep using pills/adrenaline instead of first aid kits when health < 40.
- When pills or adrenaline are not available, bots will heal with first aid kits when health < 35.
- Bots with a first aid kit will heal immediately when on third strike, regardless of health or other healing items.
- Bots behavioral action redirection is relaxed (closer to standard behavior) for finale maps.
- Bots will not use their first aid kit on a player that has their own first aid kit.
- Bots with a first aid kit and health < 80 will automatically heal on map transition.
- Survivors without a first aid kit and health < 40 will receive a minimal heal to 40 health on map transition.
<br>

#### `Notes`:  

By default, this plugin will only run in the cooperative (coop) gamemode and will automatically enable/disable itself based on the active gamemode.  It is intended to be used on dedicated servers that have not modified the default values of player health or healing items.

Bots will not usually try to heal self/others when they are under heavy attack and typically wait for some calm, so the actual health where they heal may vary slightly.

Previous versions removed first aid kits from ending saferooms then gave them out automatically on map transition including bots healing other players.  Many players were confused by this and it has been reverted... first aid kits in safe rooms now behave normally.

These [Valve ConVars](https://developer.valvesoftware.com/wiki/List_of_Left_4_Dead_2_console_commands_and_variables) will automatically be set when this plugin is active:

- sb_temp_health_consider_factor 1
- sb_toughness_buffer 0
- pain_pills_health_threshold 90

The ConVars above will revert to their normal values whenever this plugin is not active.

I might add some new features in the future, but I will not be adding support for L4D1.

When reporting a bug, provide a description of the problem and the steps to reproduce it, and provide the output from this command on the dedicated server system console:

***sm plugins list;sm exts list;meta list;sm_cvar mp_gamemode***
<br><br>

#### `Code / Discussion`:

[GitHub](https://github.com/Mystik-Spiral/l4d2_HealAlt)  
[AlliedModders](https://forums.alliedmods.net/showthread.php?t=347667)
<br><br>

#### `Acknowledgements and Thanks`:  

**Silvers**: For the original [Bot Healing Values](https://forums.alliedmods.net/showthread.php?t=338889) plugin this is forked from, Left4DHooks, gamedata, Allowed Game Modes code, and many code examples.  
**BHaType**: For help and code examples for custom Actions, and the Actions plugin.  
**nosoop**: For the Source Scramble plugin.  
**Spirit_12**: For help with determing navigation flow distance.  
**BRU7US**: For help with the map_transition event.  
**Blueberryy**: Improved Russian translation.
<br><br>

#### `Changelog`:  

04-Aut-2024 v1.1
- Added a few tweaks/fixes regarding when healing is allowed or redirected.<br>
-- When possible, redirect healing behavior, mostly using pain pills instead of first aid kits.<br>
-- When not redirected, do not block healing behavior except when target can heal themselves.<br>
-- Healing redirection now includes some randomness/chance so the healing behavior seems more natural.<br>
- Simplified bot healing during map transition for greater compatibility and less confusion.<br>
-- Bots with a first aid kit and < 80 health will heal self.<br>
-- Survivors without a first aid kit and < 40 health will receive a minimal heal to 40 health.<br>
-- No longer removes first aid kits in ending safe areas and they can be used normally.<br>
- Improved healing reliablity/timing when behavioral action is redirected.<br>
- Added a few miscellaneous code improvements.<br>
- Adjusted healing target values<br>
-- Pills/Adrenaline < 40<br>
-- First Aid Kit < 35<br>
- The translation file ueses fewer entries now but it is not required to update it.<br>

19-May-2024 v1.0.1  
- Minor code fixes.<br>
-- Detect player healing someone else when map transition begins.<br>
-- Improvements to late loading.<br>
- Improved Russian translation (Спасибо Blueberryy)<br>

12-May-2024 v1.0  
- Initial release.
<br><br>

#### `Prerequisites`:  

[Actions extension by BHaType](https://forums.alliedmods.net/showthread.php?t=336374)  
[Source Scramble plugin by nosoop](https://forums.alliedmods.net/showthread.php?t=317175)  
[Left 4 DHooks Direct by Silvers](https://forums.alliedmods.net/showthread.php?t=321696)
<br><br>

#### `Installation`:

**Easiest**:  
Download the [l4d2_HealAlt.zip](https://forums.alliedmods.net/showthread.php?t=347667) file, place it in the addons/sourcemod directory, unzip.

**Manual**:  
Extract the l4d2_HealAlt.smx file to the "plugins" directory.  
Extract the l4d2_HealAlt.txt file to the "gamedata" directory.  
Extract the l4d2_HealAlt.phrases.txt file to the "translations" directory.  
Extract the l4d2_HealAlt.sp file to the "scripting" directory.
