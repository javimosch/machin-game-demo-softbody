---
name: machin-game-demo-softbody
description: Build, run, and modify machin-game-demo-softbody — a pair of 3×3×3 cubes held by shape-matching pull-toward-COM+rest_offset, dropping onto a jagged floor in machin (MFL). Use when working on this repo, or as the reference example of soft-body shape-matching dynamics built on machin-game-demo-physics. Covers the new `Particle` fields (rest_offset, body_id), the `phys_shape_match(w)` solver, the `build_soft_cube` 2-pass builder, and the spring-stiffness K constant.
---

# machin-game-demo-softbody

**Two 3×3×3 cubes + jagged floor + shape-matching dynamics** — pure composition on [`machin-game-demo-physics`](https://github.com/javimosch/machin-game-demo-physics).

> Shared game-dev substrate (raylib FFI, FlyCam, math module, build/vendoring raylib) lives in the canonical **[machin-gamedev skill](https://github.com/javimosch/machin/blob/main/skills/machin-gamedev/SKILL.md)**.

## Build & run

```bash
./build.sh                            # → ./machin-game-demo-softbody
./machin-game-demo-softbody
```

Needs `machin` **v0.48.0+**, a C compiler, **raylib**, and a display.

## Architecture

### The shared substrate

Inherited *verbatim* from the base:
- `math3d` (Vec3 + 11 ops)
- raylib FFI (`DrawSphere`, `DrawLine3D`, `DrawGrid`, `Camera3D` cstruct, mouse/keyboard helpers)
- Verlet integrator (`phys_integrate` extended to preserve `rest_offset` and `body_id` through the struct-literal replacement)
- ground + sphere-sphere collisions
- `FlyCam`, RNG

### The softbody deltas

#### 1. `Particle` gains two fields

```
type Particle struct {
    pos         Vec3
    old         Vec3
    radius      float
    mass        float
    pinned      int
    rest_offset Vec3
    body_id     int
}
```

`rest_offset` = position relative to the body's COM at REST. `body_id = -1` for non-soft particles (jagged floor, balls).

`part_new` now takes 6 args. `phys_add_particle` defaults `body_id = -1, rest_offset = zero` so it stays a "regular particle" call.

#### 2. `phys_shape_match(w)` — the spring layer

```
K := 0.18  // spring stiffness per substep-iteration

for each distinct body_id:
    count, COM := average(positions in that body)
    for each particle p in body_id:
        target := COM + p.rest_offset
        p.pos = v3_lerp(p.pos, target, K)  // K * (target - pos) per pull
```

Called inside `phys_tick`'s relaxation loop, so it runs `iters` times per substep. With `iters = 3` and `K = 0.18`, a deformed cube springs back to its rest shape in 1-2 substeps.

#### 3. `build_soft_cube` — two-pass builder

**Pass 1:** place 27 particles in a 3×3×3 grid at world-space coords.
**Pass 2:** compute the body's COM (averaging positions) and assign each particle `rest_offset = pos - COM`.

`build_jagged_floor` is similar but its particles are pinned (no shape-matching; they're just collision geometry).

#### 4. `phys_tick` calls `phys_shape_match` inside its relaxation loop

`phys_solve_constraints` is preserved verbatim but its loop runs over an empty `constraints` slice in softbody → no-op. The active spring is `phys_shape_match`.

### Patterns worth copying

- **Shape-matching in pure position-based dynamics.** Lerp-toward-target works inside a Verlet integrator because both are position-only — no velocity state to maintain.
- **A 2-pass builder to compute per-body `rest_offset`.** Always capture `rest_offset` after placing particles, so it points relative to the *body's* COM, not the world.
- **Compose visually distinct bodies by `body_id`.** The render color is `soft_color_for(p.body_id)`; the rest-target debug lines are picked by the same id. Easy to add more bodies — just `build_soft_cube` again with a new id.
- **K is the *king knob*.** Changing `K` from 0.05 → 0.18 → 0.30 takes you from molasses → standard → oscillating. Anything you build on this should expose K as a tuning parameter.

## Modifying

- **Stiffer / softer cubes**: edit `K := 0.18` in `phys_shape_match`.
- **More iterations** (deeper spring-back): bump `iters` in `phys_new(0, -22, 0, 0.95, 3, 3)` — e.g. (3, 5) for stronger pull.
- **Bigger / smaller cubes**: scale `spacing` in `build_soft_cube`.
- **More cubes**: just call `build_soft_cube(..., 2)` and `build_soft_cube(..., 3)` — extend `soft_color_for` to color them.
- **Different floor**: replace `build_jagged_floor` with a flat plane (pinned particles at constant Y) or a sine-wave ridge using `noise2`.
- **Distance constraints + shape match**: pre-build n² edges; add them to `phys_solve_constraints`. Both spring layers will run together.

## Future directions

- **Distance constraints on cube edges** — gives a *stiffer* cube that bounces more (less squish, more restore torque).
- **Pressure-volume** — Müller-style: each body has a target volume; the solver adds an outward/inward pressure to keep that volume constant. Result: the cube truly *holds* its shape under compression.
- **Rest pose rotation** — currently `rest_offset` is captured once and frozen. A rotation-aware shape-matcher (compute orientation from two particle pairs) handles tumbling bodies.
- **Multi-body collisions** — two cubes colliding should push each other apart. The base's O(n²) sphere-sphere handles this for free; we just need to test it.
