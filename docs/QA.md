# QA log

## Automated
* `./check.sh`: selene 0 errors/warnings, `rojo build` (library `.rbxm` + example place), `luau-lsp analyze`
  in strict mode with 0 errors, 88 Lune tests, a 3 000-iteration fuzz pass, example export.

## Adversarial review (code) — findings and fixes
| Finding | Fix |
| --- | --- |
| Diamond-shaped prefab graphs (P40 uses P39 twice, …) made validation exponential | memoised per-prefab part counts; test validates a 2^40-part graph in < 1 s and rejects it via `maxParts` |
| Self-referencing node tables (`n.children = { n }`) | depth limit reports `nesting deeper than 32` instead of overflowing the stack |
| Sizes / truss heights of 1e9 were accepted (Roblox clamps parts to 2048) | size, height and length are checked against 2048; character pieces against 64 |
| `scaleRange` on a scatter of `use` prefabs silently did nothing | `Build.scaleNode` resolves prefabs and scales size/pos/offsets/lengths recursively |
| Sparse or map-shaped `children` lists dropped entries silently | rejected with `children must be a dense list` |
| Typos (`szie`, `childern`, `colour`) were ignored | every node, root, face/hair/outfit/pose table rejects unknown fields |
| `-0.0000` vs `0.0000` made determinism fingerprints flaky after rbxm round-trips | fingerprints normalise signed zero |
| Lune has no `PivotTo`/`GetPivot` | builders take `opts.origin` and set `WorldPivot` directly, same path in Studio |
| Fuzzing: 3 000 random, mostly malformed object specs + character + anim specs | `validate` never throws; every accepted spec builds; every rejected spec fails `build` with the full error list |

## Adversarial visual QA (Roblox Studio, win11-main) — findings and fixes
Round 1 (`docs/img` before fixes, not kept):
| Finding | Fix |
| --- | --- |
| A "lighting technology migration" modal blocked the viewport | preview place sets `Lighting.Technology = ShadowMap` |
| Floating Humanoid name tags over every rig | rigs set `DisplayDistanceType = None` |
| Spiky hair read as a black beanie | spikes now radiate from the crown in two rows (front fan + back row) |
| Straw hat rendered dark brown and tall like a top hat (Fabric texture) | flatter crown, wider brim, SmoothPlastic, lighter straw |
| Katana pointed down/forward and read as a stick | blade raised 50° from the fist, guard, pommel and a faint edge glow |
| Cape rendered grey/checkered | SmoothPlastic cape with a hem |
| Belts showed a dark camo pattern | belts are SmoothPlastic |
| Platform "trim" covered the whole top (CheckpointPad was all white) | trim is now a 4-strip border; test asserts it covers < 25 % of the top |
| JumpTower: last ledge 7 studs below the checkpoint, rope floating in the air | 9 ledges, a rope arm from the core |
| PirateDock: stairs climbed away from the floating deck; lookout floated | stairs face the deck, deck and lookout have posts, ladder moved to the lookout edge |
| Chat, player list and top bar over the shots | preview LocalScript hides CoreGui and chat |

Round 3 (final, `docs/img`): no floating parts, all look pieces stay welded to the rigs in Play mode,
poses from `Anim.apply` render as authored. Known cosmetic limits: blocky silhouettes only,
close-up shots include neighbouring characters at the frame edge.
