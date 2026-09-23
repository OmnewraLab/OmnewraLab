# Creature Lab — prototype v0.1

An OmnewraLab Roblox game. Collect glowing creatures, fuse pairs into rarer tiers, grow your lab's Energy — even while you're offline.

## Play it in 2 minutes
1. Install **Roblox Studio** (free) and sign in with your OmnewraLab account.
2. Double-click **CreatureLab.rbxlx** (or File → Open in Studio).
3. Press **Play** (F5). Press **Test → Clients and Servers → 2 players** to try visiting and boosting another lab.

Everything (map, labs, creatures, UI) is built by the scripts when the game starts, so the place looks empty until you press Play.

## What's in the prototype
| Feature | Why it's there (research) |
|---|---|
| Start with 1 creature already making Energy, a hint tells you to Hatch then Fuse | First-play bounce in the first 60 s is one of Roblox's top discovery signals |
| Hatch → Fuse all → watch Energy climb | One simple loop that visibly grows (Grow a Garden's loop was built in 3 days) |
| Offline income (8 h cap, half speed) | Roblox now weights return days 2–7 and 8–28 |
| Daily streak rewards (7-day cycle) | Reason to return each day |
| Featured species of the week (+25%) | Weekly reason to return for everyone at once |
| LAB SURGE: server-wide 2x every 15 min | A shared, clip-worthy moment (top games grew through TikTok/YouTube moments) |
| Boost a friend's lab: both get 60 s of income | Co-play days are a ranking signal |
| Leaderboard: Lab Power + Best creature | Social comparison |
| Game passes: 2x Energy, Bigger Lab (+3 pads), VIP Glow; product: 1 hour of Energy | Fair monetisation, no paid random items (those need odds + alternatives) |

## Before publishing
- Game Settings → Security → turn on **Enable Studio Access to API Services** to test saving (then set the `AllowStudioSaves` attribute on ServerStorage to true).
- Create the passes/product in the Creator Dashboard and paste their ids into `src/shared/Config.luau`.
- Make a proper icon and thumbnails that honestly show the lab (misleading icons raise bounce).
- Balance numbers live in `src/shared/Config.luau` only.

## Developing with Rojo (optional)
Install the Rojo plugin in Studio, run `rojo serve` in this folder, click Connect — edits to the `.luau` files sync into Studio live. `rojo build -o CreatureLab.rbxlx` rebuilds the place file.

## Files
- `src/shared/Config.luau` — all tuning numbers, tiers, species
- `src/server/Main.server.luau` — game loop, actions, surge, boosts, purchases
- `src/server/DataService.luau` — saving (DataStore with retries, never overwrites on a failed load)
- `src/server/LabWorld.luau` — builds the hub, 8 labs and creature visuals
- `src/client/LabUI.client.luau` — mobile-first UI
