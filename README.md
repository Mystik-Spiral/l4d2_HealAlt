---
> ### `Healing Alternative` <sub>(l4d2_HealAlt) by</sub> ***Mystik Spiral***
>
> #### Left4Dead2 Sourcemod plugin to improve when healing items (first aid kits, pain pills, and adrenaline shots) are used.
---

#### Summary of healing behavioral changes:  

- Bots prefer to use/give pills/adrenaline instead of first aid kits.
- Bots will wait longer to use first aid kits on self or others.
- Bots will never heal another player that has their own healing items.
- Survivors with a first aid kit are healed using the standard algorithm during map changes.
- Survivors without a first aid kit are healed to 50, same as a respawned dead player, during map changes.
- All survivors are given a first aid kit during map changes.
<br>

#### Options:  

For proper operation, set the following [Valve ConVars](https://developer.valvesoftware.com/wiki/List_of_L4D2_Cvars) in your server.cfg file:

sb_toughness_buffer 0  
sb_temp_health_consider_factor 0.0  
pain_pills_health_threshold 90
<br><br>  

#### Notes:  

By default, this plugin will only run in the cooperative (coop) gamemode and is intended to be used on dedicated servers that have not modified the default values of player health or healing items.

I plan to eventually add handling for first aid kits found outside of safe rooms.  
I will not be adding support for L4D1.

Please let me know if you find any bugs, but before reporting, connect to the dedicated server system console and type:

***sm plugins list;sm_cvar mp_gamemode***

Check that the gamemode is "coop" and whether you see "[L4D2] Healing Alternative" or error messages, especially errors related to missing prerequisites.
<br><br>  

#### Code/Discussion:

[GitHub](https://github.com/Mystik-Spiral/l4d2_HealAlt)  
[AlliedModders](https://forums.alliedmods.net/showthread.php?t=xxxxxx)
<br><br>  

#### Acknowledgements and Thanks:  

**Silvers**: For the original [Bot Healing Values](https://forums.alliedmods.net/showthread.php?t=338889) plugin this is forked from, Left4DHooks, gamedata, Allowed Game Modes code, and many code examples.  
**BHaType**: For help and code examples for custom Actions, and the Actions plugin.  
**nosoop**: For the Source Scramble plugin.  
**Spirit_12**: For help with determing navigation flow distance.  
**BRU7US**: For help with the map_transition event.
<br><br>  

#### Changelog:  

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
Download the l4d2_HealAlt.zip file, place it in the addons/sourcemod directory, unzip.

**Manual**:  
Extract the l4d2_HealAlt.smx file to the "plugins" directory.  
Extract the l4d2_HealAlt.txt file to the "gamedata" directory.  
Extract the l4d2_HealAlt.phrases.txt file to the "translations" directory.  
Extract the l4d2_HealAlt.sp file to the "scripting" directory.
