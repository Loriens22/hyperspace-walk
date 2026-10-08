"""Render the equation overlays (matplotlib mathtext) to game/eq/*.png (white on transparent)."""
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
plt.rcParams['mathtext.fontset'] = 'cm'
C = '#e8fbff'
def save(name, fig):
    fig.savefig(f'game/eq/{name}.png', transparent=True, dpi=110, bbox_inches='tight', pad_inches=0.08); plt.close(fig); print(name)
def simple(name, lines, w=7.2, fs=24):
    h = 0.62 * len(lines) + 0.2
    fig = plt.figure(figsize=(w, h))
    for i, (txt, size) in enumerate(lines):
        fig.text(0.5, 1 - (i + 0.6) / len(lines), txt, ha='center', va='center', fontsize=size or fs, color=C)
    save(name, fig)
simple('R4', [(r'$\mathbb{R}^4=\{(x,y,z,w)\;:\;x,y,z,w\in\mathbb{R}\}$', 0),
              (r'$|p|=\sqrt{x^2+y^2+z^2+w^2}$', 22)])
simple('persp', [(r"$(x,y,z,w)\;\mapsto\;\frac{d}{d-w}\,(x,y,z)$", 26),
                 (r'perspective from a 4D eye at $w=d$', 16), (r"orthographic: $(x,y,z,w)\mapsto(x,y,z)$", 18)])
simple('slice2', [(r'$r(h)=\sqrt{R^2-h^2}$', 30), (r'sphere $x^2+y^2+z^2=R^2$ cut by the plane $z=h$', 16)])
simple('s3', [(r'$S^3=\{\,p\in\mathbb{R}^4:\;x^2+y^2+z^2+w^2=R^2\,\}$', 24)])
simple('slicew', [(r'$x^2+y^2+z^2=R^2-w^2$', 26), (r'$r(w)=\sqrt{R^2-w^2},\quad |w|\leq R$', 24)])
simple('planes', [(r'$\binom{4}{2}=6:\quad xy,\;xz,\;xw,\;yz,\;yw,\;zw$', 26)])
simple('schlafli', [(r'$\{p,q,r\}$: cells $\{p,q\}$, $r$ cells around each edge', 22),
                    (r'$\{3,3,3\}\;\{4,3,3\}\;\{3,3,4\}\;\{3,4,3\}\;\{3,3,5\}\;\{5,3,3\}$', 22)])
simple('holonomy', [(r'$\Delta\theta=\iint_A K\,dA=\frac{A}{R^2}$', 28), (r'$A=\frac{4\pi R^2}{8}\;\Rightarrow\;\Delta\theta=\frac{\pi}{2}=90^\circ$', 24)])
def matrix(name, title, rows, w=6.4):
    fig = plt.figure(figsize=(w, 2.6))
    fig.text(0.03, 0.5, title, ha='left', va='center', fontsize=24, color=C)
    x0, x1 = 0.42, 0.96
    for r, row in enumerate(rows):
        for c, e in enumerate(row):
            fig.text(x0 + 0.03 + (c + 0.5) * (x1 - x0 - 0.06) / 4, 0.86 - r * 0.24, e if e.startswith('$') else '$'+e+'$', ha='center', va='center', fontsize=19, color=C)
    for x, d in ((x0, 1), (x1, -1)):
        fig.add_artist(plt.Line2D([x + 0.015 * d, x, x, x + 0.015 * d], [0.97, 0.97, 0.03, 0.03], color=C, lw=2))
    save(name, fig)
c, s, ms = r'$\cos\theta$', r'$\sin\theta$', r'$-\sin\theta$'
matrix('Rxy', r'$R_{xy}(\theta)=$', [[c, ms, '0', '0'], [s, c, '0', '0'], ['0', '0', '1', '0'], ['0', '0', '0', '1']])
matrix('Rxw', r'$R_{xw}(\theta)=$', [[c, '0', '0', ms], ['0', '1', '0', '0'], ['0', '0', '1', '0'], [s, '0', '0', c]])
ca, sa, msa = r'$\cos\alpha$', r'$\sin\alpha$', r'$-\sin\alpha$'
cb, sb, msb = r'$\cos\beta$', r'$\sin\beta$', r'$-\sin\beta$'
matrix('Rdouble', r'$R_{xy}(\alpha)R_{zw}(\beta)=$', [[ca, msa, '0', '0'], [sa, ca, '0', '0'], ['0', '0', cb, msb], ['0', '0', sb, cb]], w=8.2)
