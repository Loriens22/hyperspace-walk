# Hyperspace Walk: the mathematics behind the game

This file lists every mathematical model the game uses, where it lives in the code, and the source it comes from.
Reference keys like **[Coxeter 1973]** match the in-game **Research Log** (press **J**), which is generated from `gen/content.py`.
All references are listed at the end of this file.

---

## 1. Four-dimensional Euclidean space

A point is `p = (x, y, z, w) ∈ ℝ⁴`. The **w** axis is perpendicular to x, y and z. Distance is the usual
`|p − q| = √(Δx² + Δy² + Δz² + Δw²)`. Hinton named the two directions along the fourth axis
**ana** (+w) and **kata** (−w) [Hinton 1888; Wikipedia: 4D space]. In the game, **E** moves ana and **Q** moves kata.

In this game w is a flat, *spatial* fourth axis. It is **not** time, and it is not the curled-up extra dimension
of Kaluza–Klein theory (see §8).

---

## 2. Rotations in ℝ⁴: six planes (`game/scripts/p4.gd`, `game/shaders/edge4d.gdshader`)

In any dimension a rotation happens *in a plane*. ℝ⁴ has C(4,2) = **6 coordinate planes**:
xy, xz, xw, yz, yw, zw [Wikipedia: 4D rotations]. Keys **1–6** pick a plane.

The rotation by angle θ in the plane of axes (i, j) is the identity matrix with four entries changed:

```
q_i = cos θ · p_i − sin θ · p_j
q_j = sin θ · p_i + cos θ · p_j        (all other coordinates unchanged)
```

For example, the xw rotation is

```
        ⎡ cos θ  0  0  −sin θ ⎤
R_xw =  ⎢   0    1  0     0   ⎥
        ⎢   0    0  1     0   ⎥
        ⎣ sin θ  0  0   cos θ ⎦
```

* **Simple rotation:** one plane turns and the *orthogonal plane stays fixed pointwise* (an xy rotation fixes the
  whole zw plane, not just an axis).
* **Double rotation:** `R = R_xy(α) · R_zw(β)`. Two completely orthogonal planes turn at once by different angles.
  This has no 3D equivalent. In general only the origin is fixed.
* **Isoclinic rotation:** the special case |α| = |β|. Every point moves through the same angle
  [Wikipedia: 4D rotations; Coxeter 1973].

Implementation: `P4.plane_rot(i, j, θ)` builds the 4×4 matrix. Rotations are accumulated by left-multiplication,
and the matrix is re-orthonormalised with Gram–Schmidt (`P4.orthonormalize`) so rounding errors don't build up.
The matrix goes to the GPU as a `mat4` uniform. The vertex shader rotates both 4D endpoints of every edge.
(Edges are stored as vertex attributes `CUSTOM0`/`CUSTOM1`.) Player-controlled turns are animated 15° steps (R/F).

---

## 3. Projections from 4D to 3D (`edge4d.gdshader`, `vert4d.gdshader`)

**Perspective** (eye on the w axis at distance d, projecting onto the hyperplane w = 0):

```
(x, y, z, w) ↦ d / (d − w) · (x, y, z)
```

This is the direct analogue of a camera's 3D→2D perspective. Points farther along w (smaller d − w) are drawn
smaller. That's why a tesseract looks like "a cube inside a cube" [Noll 1967; Banchoff 1990, ch. 4 and 6].
In the shader, `eye` is d, and the denominator is clamped (`max(d − w, 0.15)`) to avoid dividing by zero.

**Orthographic:** `(x, y, z, w) ↦ (x, y, z)` (w is simply dropped). Looking straight down w, the two cubes of a
tesseract coincide. Tilting the object in an xw plane first makes the hidden cube visible.
Lesson A morphs smoothly between the two with `f = mix(d/(d−w), 1, morph)`.

**Schlegel diagram:** a perspective projection with the eye placed just outside one cell. That cell becomes the
outer frame and all the other cells nest inside it [Schlegel 1886; Coxeter 1973].
In the game, the eye distance is reduced until it is close to a cell.

**Stereographic:** each point on an edge is pushed radially onto the unit 3-sphere, `s = q/|q|`, and then projected
from the pole (0,0,0,1): `s ↦ (s_x, s_y, s_z) / (1 − s_w)`. Edges therefore look curved, as in
Hanson & Heng's 4D renderings [Hanson & Heng 1992]. Press **C** near a polytope to switch projection modes.

**Extrusion (point → segment → square → cube → tesseract):** a per-axis scale `extent = (e_x, e_y, e_z, e_w)` is
applied to the tesseract's vertices (±½)⁴ before rotation. Growing each component from 0 to 1, one after another,
sweeps the previous figure along a new perpendicular axis. Element counts follow `V_n = 2ⁿ`; the tesseract has
16 vertices, 32 edges, 24 squares and 8 cubes [Coxeter 1973; Wikipedia: Regular 4-polytope].

---

## 4. Slicing with the hyperplane w = h (`P4.slice` in `p4.gd`)

We live in the 3D slice `w = h` (h = the player's w). A 4D polytope that meets the slice is drawn **exactly**:

* **slice vertex:** each edge (a, b) with `(a_w − h)(b_w − h) < 0` crosses the hyperplane at
  `t = (h − a_w)/(b_w − a_w)`, `p = a + t (b − a)`;
* **slice edge:** each 2-face (polygon) that crosses the hyperplane contributes the segment joining its two
  crossing points;
* **slice face:** each 3-cell that crosses contributes a polygon. Its crossing points are chained into a loop and
  fan-triangulated for the translucent fill.

So a 4D solid passing through our space appears as a 3D solid that grows, changes shape and vanishes
[Banchoff 1990, ch. 3; Abbott 1884]. The puzzle lock tesseract (Station III gate) is solved by rotating it so that
its slice at w = 0 becomes a 1 × √2 × 1 box. A yw rotation of 45° does it: the unit cube's y and w extents combine
into the diagonal √2.

**Flatland analogy (Station II):** a sphere of radius R passing through a plane at height h leaves a circle of radius
`r(h) = √(R² − h²)` for |h| ≤ R, and nothing otherwise [Abbott 1884].

---

## 5. The 3-sphere (hypersphere) (`game/scripts/hypersphere.gd`)

`S³(R) = {(x,y,z,w) : x² + y² + z² + w² = R²}`. Slicing at `w = h` gives `x² + y² + z² = R² − h²`, an ordinary
sphere of radius

```
r(h) = √(R² − h²),   |h| ≤ R
```

It grows from a point (h = −R) to radius R (h = 0) and shrinks back [Banchoff 1990, ch. 3]. The background
"bubbles" are 3-spheres with different centres w₀ and radii. Each one is drawn at the slice radius
`√(R² − (w_player − w₀)²)`, or hidden when it does not meet the player's slice.

---

## 6. The six convex regular 4-polytopes (`gen/polytopes.py` → `game/data/polytopes.json`)

There are exactly six convex regular 4-polytopes, first enumerated by Schläfli (1850–52, published 1901)
[Schläfli 1852/1901; Coxeter 1973]. All are generated procedurally and normalised to circumradius 1:

| name | Schläfli | V | E | F | C | cells | coordinates used (before scaling) |
|---|---|---|---|---|---|---|---|
| 5-cell | {3,3,3} | 5 | 10 | 10 | 5 | tetrahedra | (1,1,1,−1/√5), (1,−1,−1,−1/√5), (−1,1,−1,−1/√5), (−1,−1,1,−1/√5), (0,0,0,4/√5) |
| tesseract (8-cell) | {4,3,3} | 16 | 32 | 24 | 8 | cubes | (±1, ±1, ±1, ±1) |
| 16-cell | {3,3,4} | 8 | 24 | 32 | 16 | tetrahedra | permutations of (±1, 0, 0, 0) |
| 24-cell | {3,4,3} | 24 | 96 | 96 | 24 | octahedra | permutations of (±1, ±1, 0, 0) |
| 600-cell | {3,3,5} | 120 | 720 | 1200 | 600 | tetrahedra | (±½,±½,±½,±½), perms of (±1,0,0,0), even perms of ½(±φ, ±1, ±1/φ, 0) |
| 120-cell | {5,3,3} | 600 | 1200 | 720 | 120 | dodecahedra | perms of (0,0,±2,±2), (±1,±1,±1,±√5), (±φ⁻²,±φ,±φ,±φ), (±φ⁻¹,±φ⁻¹,±φ⁻¹,±φ²) and even perms of (0,±φ⁻²,±1,±φ²), (0,±φ⁻¹,±φ,±√5), (±φ⁻¹,±1,±φ,±2) |

φ = (1 + √5)/2. Edges are found as all vertex pairs at the minimum distance. 2-faces are the 3-, 4- or 5-cycles
of the edge graph, and the script checks that each one is planar. Cells are the faces lying on a supporting
hyperplane whose normal points to a vertex of the dual polytope. For the 600-cell those normals are the centroids
of its tetrahedra; for the 120-cell they are the vertices of a 600-cell (in the matching orientation). The script checks every polytope against
the published counts and checks Euler's relation for 4-polytopes, `V − E + F − C = 0`. The output is in
`docs/polytope_verification.txt`:

```
5cell      {3,3,3}  (5, 10, 10, 5)        edge=1.581139  euler=0  OK
tesseract  {4,3,3}  (16, 32, 24, 8)       edge=1.000000  euler=0  OK
16cell     {3,3,4}  (8, 24, 32, 16)       edge=1.414214  euler=0  OK
24cell     {3,4,3}  (24, 96, 96, 24)      edge=1.000000  euler=0  OK
600cell    {3,3,5}  (120, 720, 1200, 600) edge=0.618034  euler=0  OK
120cell    {5,3,3}  (600, 1200, 720, 120) edge=0.270091  euler=0  OK
```

The edge lengths for circumradius 1 match known values: 600-cell 1/φ ≈ 0.618034; 120-cell 1/(φ²√2) ≈ 0.270091;
5-cell √(5/2) ≈ 1.581139 [Wikipedia: Regular 4-polytope; Coxeter 1973].
Duality pairs: tesseract ↔ 16-cell, 600-cell ↔ 120-cell; the 5-cell and 24-cell are self-dual.
The 24-cell has no 3D analogue.

---

## 7. Curvature and parallel transport (Station V, `game/scripts/station_e.gd`)

On a sphere of radius R, carry a tangent vector without turning it (parallel transport) around the geodesic
triangle *north pole → equator → 90° along the equator → back to the pole*. The vector comes back rotated by

```
Δθ = ∬_A K dA = A / R²,   with A = 4πR²/8  ⇒  Δθ = π/2 = 90°
```

This is Gauss's angle-excess theorem (the triangle's three right angles add up to 270°, which is 90° over the
flat-plane 180°) [Gauss 1827]. Levi-Civita's parallel transport generalises it to any curved manifold
[Levi-Civita 1917]. The tensor calculus behind it is [Ricci & Levi-Civita 1900]. The game animates this exact path.

---

## 8. Kaluza–Klein (theory, clearly labelled THEORY in-game)

Kaluza (1921) added a fifth dimension to general relativity to unify gravity and electromagnetism [Kaluza 1921].
Klein (1926) proposed that this extra dimension is curled into a tiny circle [Klein 1926]. String theory later
used six compact dimensions (Calabi–Yau spaces) [Candelas et al. 1985].
The garden-hose picture (a thin hose looks 1D from far away, but an ant can walk around it) is only an analogy.
**No extra dimension has been detected experimentally.** The game says this explicitly and keeps it separate
from the flat w axis the player walks along.

---

## 9. Gameplay models

* **Objects with a w-extent.** Ordinary architecture is extruded over all w (a prism `B × ℝ` in ℝ⁴), so it exists
  in every slice. The Flatland wall is `B × [−0.6, 0.6]`, and the bridge is `B × [1.4, 2.6]`. An object collides
  only when the player's w lies in its interval. Moving along w into an occupied region is blocked.
  This is the 4D version of stepping over a line that a Flatlander cannot get around [Abbott 1884].
* **Sky and fog** shift colour with w. This is an artistic cue only, not a physical claim.
* **Music** crossfades between a "3D" and a "4D" procedural pad according to |w|.

---

## References

* **[Hinton 1888]** C. H. Hinton, *A New Era of Thought*, Swan Sonnenschein, London, 1888. Coins "tessaract", "ana", "kata". https://www.gutenberg.org/ebooks/60607
* **[Hinton 1904]** C. H. Hinton, *The Fourth Dimension*, Swan Sonnenschein, London, 1904 (spelling "tesseract"). https://www.gutenberg.org/ebooks/67153
* **[Abbott 1884]** E. A. Abbott, *Flatland: A Romance of Many Dimensions*, Seeley & Co., London, 1884. https://www.gutenberg.org/ebooks/201
* **[Schläfli 1852/1901]** L. Schläfli, *Theorie der vielfachen Kontinuität*, written 1850–52, published 1901. https://mathshistory.st-andrews.ac.uk/Biographies/Schlafli/
* **[Schlegel 1886]** V. Schlegel, *Ueber Projectionsmodelle der regelmässigen vier-dimensionalen Körper*, Waren, 1886. https://en.wikipedia.org/wiki/Schlegel_diagram
* **[Coxeter 1973]** H. S. M. Coxeter, *Regular Polytopes*, 3rd ed., Dover, New York, 1973 (ch. 7–8; §8.7 Cartesian coordinates).
* **[Banchoff 1990]** T. F. Banchoff, *Beyond the Third Dimension*, Scientific American Library / W. H. Freeman, 1990. https://archive.org/details/beyondthirddimen0000banc_l3o2
* **[Noll 1967]** A. M. Noll, "A computer technique for displaying n-dimensional hyperobjects", *Communications of the ACM* 10(8):469–473, 1967.
* **[Hanson & Heng 1992]** A. J. Hanson, P. A. Heng, "Illuminating the fourth dimension", *IEEE CG&A* 12(4):54–62, 1992. doi:10.1109/38.144827
* **[Ricci & Levi-Civita 1900]** G. Ricci, T. Levi-Civita, "Méthodes de calcul différentiel absolu et leurs applications", *Math. Ann.* 54:125–201, 1900. doi:10.1007/BF01454201
* **[Levi-Civita 1917]** T. Levi-Civita, "Nozione di parallelismo in una varietà qualunque…", *Rend. Circ. Mat. Palermo* 42:173–205, 1917.
* **[Gauss 1827]** C. F. Gauss, *Disquisitiones generales circa superficies curvas*, 1827. https://www.gutenberg.org/ebooks/36856
* **[Kaluza 1921]** Th. Kaluza, "Zum Unitätsproblem der Physik", *Sitzungsber. Preuss. Akad. Wiss.* 1921:966–972. English translation: arXiv:1803.08616
* **[Klein 1926]** O. Klein, "Quantentheorie und fünfdimensionale Relativitätstheorie", *Z. Phys.* 37:895–906, 1926. doi:10.1007/BF01397402
* **[Candelas et al. 1985]** P. Candelas, G. T. Horowitz, A. Strominger, E. Witten, "Vacuum configurations for superstrings", *Nucl. Phys. B* 258:46–74, 1985. doi:10.1016/0550-3213(85)90602-9
* **[Wikipedia: 4D rotations]** "Rotations in 4-dimensional Euclidean space", accessed Oct 2026.
* **[Wikipedia: Regular 4-polytope]** "Regular 4-polytope" and "600-cell", accessed Oct 2026.
* **[Wikipedia: 4D space]** "Four-dimensional space", accessed Oct 2026.
