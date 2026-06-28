# machin-game-demo-softbody

**Two 3×3×3 cubes that hold their rest shape via pull-toward-COM+rest_offset, drop onto a jagged floor of pinned spikes, squash visibly, spring back.** In [machin](https://github.com/javimosch/machin) (MFL) over raylib. Pure composition on [`machin-game-demo-physics`](https://github.com/javimosch/machin-game-demo-physics).

Part of [**awesome-machin**](https://github.com/javimosch/awesome-machin). One of four sibling demos expanding the base: [cloth](https://github.com/javimosch/machin-game-demo-cloth) · [ropes](https://github.com/javimosch/machin-game-demo-ropes) · [sand](https://github.com/javimosch/machin-game-demo-sand) · **softbody** (this).

```
       ▒ ▒                  machin — softbody
       ▒                       (shape-matching pull-toward-COM)
  ⬛ ▒ ▒ ▒ ⬛                  2 cubes of 27 particles each
┌──┴─────┴──┐                COM pull K = 0.18 per substep-iter
│ ▒ ▒ ▒ ▒ ▒ │              Jagged floor: 11 pinned spikes
│ ▒ ▒▒▒▒ ▒ │                Gravity g = -22 u/s²
│ ▒▒▒▒▒▒▒ │                 Damping = 0.95
└─▒▒▒▒▒▒▒─┘                Substeps × iters = 3 × 3
          ▒▒ ▒▒              = 9 shape-match pulls per tick
                            Pure MFL · raylib FFI · 65 particles
```

## Why it exists

The base physics demo is **all positional**: gravity + zero-stick constraints + collision. Every "body" is a point. To get a *body* (a thing that holds its shape and reacts to deformation), we need **shape-matching** — a per-substep spring that pulls each particle of a soft body toward its rest position relative to the body's current center of mass.

This demo adds it as a thin composition (no new FFI, no new machin feature): `Particle` gains two fields (`rest_offset Vec3` + `body_id int`); `phys_shape_match(w)` iterates each distinct body_id once per substep, computes the body's COM, and lerps every particle toward `(COM + rest_offset)` by a fraction `K = 0.18`. Two cubes of 27 particles each drop onto 11 pinned spikes; the cubes compress on contact with the spikes and spring back to their rest shape. The pull is `K * (target − pos)` per substep-iteration, so the system is **softer** than a hard spring and the squish is clearly visible — you see the under-side flatten against a spike while the upper half holds its roughly-cubic shape.

## Build

```bash
./build.sh                          # → ./machin-game-demo-softbody
./machin-game-demo-softbody
```

Needs `machin` **v0.48.0+**, a C compiler, **raylib**, and a display. `build.sh` vendors raylib 5.0 linux_amd64 into `vendor/` if no system raylib is installed.

## Controls

| key | action |
|---|---|
| WASD / mouse | fly camera |
| Q / E | fly down / up |
| R | reset camera |
| Esc | quit |

Softbody is observed (no yank keys); you watch the cubes fall, squash, and recover.

## How it works

### The deltas vs. the base

| delta | where | what |
|---|---|---|
| `Particle` gains `rest_offset Vec3` and `body_id int` | top-level | the two new fields that make a particle part of a soft body |
| `part_new` takes 6 args | copy of base | constructs a Particle with the new fields included |
| `phys_add_particle` defaults `body_id = -1`, `rest_offset = zero` | copy of base | "regular" particle is non-soft; flagged body_id = -1 |
| `phys_add_soft_particle(w, pos, radius, mass, body_id)` | new | adds a soft-body particle (sets `body_id`, defaults `rest_offset` to zero until 2nd-pass back-fill) |
| `phys_shape_match(w)` | new (~60 LOC) | iterates each body_id, computes COM, pulls each particle lerp-ward |
| `build_soft_cube(w, center, spacing, radius, mass, body_id)` | new | emits 27 particles then back-fills `rest_offset = pos − COM` |
| `build_jagged_floor(w, n, y_lo, y_hi, x_lo, x_hi, z, radius, mass)` | new | n pinned particles at random Y in [y_lo, y_hi] forming the spikes |
| `phys_tick` calls `phys_shape_match` inside its relaxation loop | copy of base | one extra call per substep-iteration |
| Render: per-body color + rest-target debuglines | main | pink for body 0, teal for body 1; thin grey lines from each particle to its current rest target |

### Why shape-matching instead of distance constraints

A 3×3×3 cube has 27 particles; with **structural** distance constraints we'd need 54 (~3·n) to keep the mesh connected and ~110 (~4·n) to prevent shear. That's a lot of constraints to solve per substep, AND it's rigid — the cube would *not* visibly squish on contact.

Shape-matching instead: particles are *spring-pulled* toward their rest pose (which is `COM + rest_offset` at build time). When a cube hits a spike, the lower half compresses against the spike but the spring-to-rest keeps pulling the cube back toward a recognizable 3×3×3. The cube is **rigid enough to hold its identity but soft enough to visibly deform**. Tunable stiffness via `K`:
- `K = 0.05` (molasses — slow spring-back)
- `K = 0.18` (default — clear squish + recognizable spring-back)
- `K = 0.30` (oscillating)

### Why a 2nd pass to capture `rest_offset`

When `build_soft_cube` adds the 27 particles in the 3×3×3 grid, they are positioned at world-space coordinates (e.g. a cube centered at (-3.5, 10.5, 0)). For shape-matching to work, each particle needs to know "where I should be **relative to my body's COM** at rest" — i.e. the cube's own local frame. That's exactly `p.pos − COM`. The 2nd pass computes the body's COM (averaging its particles' positions) and assigns each particle its `rest_offset`. After this, even if the cube is rotated or displaced, `rest_offset` stays constant in the cube's local frame, and the spring pulls it back to the right spot.

### Why the *only* constraint is shape-matching (no distance constraints)

Soft bodies in PBD/Müller-style literature are usually a *combination* of distance constraints + shape-matching. Pure shape-matching (this demo) is the simplest formulation and gives a clear spring-back behavior. A follow-on could add 12 distance constraints along the cube's edges — that gives a *stiffer* soft body with less squish and a more "bouncy ball" feel. Trade the demo's K value for a slightly more rigid cube.

## License

MIT
