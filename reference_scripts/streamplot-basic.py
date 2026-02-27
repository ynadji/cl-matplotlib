import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import math
from matplotlib.collections import LineCollection
from matplotlib.patches import FancyArrowPatch

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42


def cl_streamplot(ax, x_arr, y_arr, U, V, color='C0', linewidth=1.0,
                  density=1.0, arrowsize=1.0):
    nx_data = len(x_arr)
    ny_data = len(y_arr)
    x0, x1 = float(x_arr[0]), float(x_arr[-1])
    y0, y1 = float(y_arr[0]), float(y_arr[-1])

    n_mask = max(1, round(density * 30))
    mask = np.zeros((n_mask, n_mask), dtype=int)

    def mask_occupied(ixi, iyi):
        if 0 <= ixi < n_mask and 0 <= iyi < n_mask:
            return mask[iyi, ixi] == 1
        return False

    def mask_occupy(ixi, iyi):
        for dy in range(-1, 2):
            for dx in range(-1, 2):
                xx, yy = ixi + dx, iyi + dy
                if 0 <= xx < n_mask and 0 <= yy < n_mask:
                    mask[yy, xx] = 1

    def grid2data(xi, yi):
        x = x0 if nx_data <= 1 else x0 + xi * (x1 - x0) / (nx_data - 1)
        y = y0 if ny_data <= 1 else y0 + yi * (y1 - y0) / (ny_data - 1)
        return x, y

    def interp_velocity(xi, yi):
        xi_c = max(0.0, min(float(nx_data - 1), xi))
        yi_c = max(0.0, min(float(ny_data - 1), yi))
        ix0 = min(int(math.floor(xi_c)), nx_data - 2)
        iy0 = min(int(math.floor(yi_c)), ny_data - 2)
        ix1, iy1 = ix0 + 1, iy0 + 1
        fx = xi_c - ix0
        fy = yi_c - iy0
        u = (U[iy0, ix0] * (1 - fx) * (1 - fy) + U[iy0, ix1] * fx * (1 - fy) +
             U[iy1, ix0] * (1 - fx) * fy + U[iy1, ix1] * fx * fy)
        v = (V[iy0, ix0] * (1 - fx) * (1 - fy) + V[iy0, ix1] * fx * (1 - fy) +
             V[iy1, ix0] * (1 - fx) * fy + V[iy1, ix1] * fx * fy)
        return float(u), float(v)

    def rk12_step(xi, yi, dt):
        u1, v1 = interp_velocity(xi, yi)
        k1x, k1y = dt * u1, dt * v1
        u2, v2 = interp_velocity(xi + 0.5 * k1x, yi + 0.5 * k1y)
        k2x, k2y = dt * u2, dt * v2
        err = math.sqrt((k2x - k1x) ** 2 + (k2y - k1y) ** 2)
        return xi + k2x, yi + k2y, err

    def integrate(xi0, yi0, direction, max_length=4.0, tolerance=0.1):
        points = [grid2data(xi0, yi0)]
        xi, yi = float(xi0), float(yi0)
        total_length = 0.0
        for _ in range(1000):
            if total_length >= max_length:
                break
            if xi < 0.0 or xi >= float(nx_data) or yi < 0.0 or yi >= float(ny_data):
                break
            ixi, iyi = round(xi), round(yi)
            if mask_occupied(ixi, iyi):
                break
            u, v = interp_velocity(xi, yi)
            speed = math.sqrt(u * u + v * v)
            if speed < 1e-8:
                break
            step_size = 0.1 / speed
            dt = direction * step_size
            new_xi, new_yi, err = rk12_step(xi, yi, dt)
            if err > tolerance:
                continue
            mask_occupy(ixi, iyi)
            xi, yi = new_xi, new_yi
            total_length += step_size
            points.append(grid2data(xi, yi))
        if direction == 1:
            return points
        else:
            return list(reversed(points))

    n_seeds = max(2, round(density * 30))
    seeds = []
    for i in range(n_seeds):
        for j in range(n_seeds):
            xi = float(i) * (nx_data - 1) / max(1, n_seeds - 1)
            yi = float(j) * (ny_data - 1) / max(1, n_seeds - 1)
            seeds.append((xi, yi))
    cx = 0.5 * (nx_data - 1)
    cy = 0.5 * (ny_data - 1)
    seeds.sort(key=lambda s: (s[0] - cx) ** 2 + (s[1] - cy) ** 2)

    all_trajectories = []
    for xi0, yi0 in seeds:
        ixi, iyi = round(xi0), round(yi0)
        if mask_occupied(ixi, iyi):
            continue
        fwd = integrate(xi0, yi0, 1)
        bwd = integrate(xi0, yi0, -1)
        trajectory = list(reversed(bwd)) + (fwd[1:] if len(fwd) > 1 else [])
        if len(trajectory) >= 2:
            all_trajectories.append(trajectory)

    if all_trajectories:
        segments = [np.array(traj) for traj in all_trajectories]
        lc = LineCollection(segments, colors=[color], linewidths=[linewidth], zorder=2)
        ax.add_collection(lc)

        for traj in all_trajectories:
            n = len(traj)
            mid_idx = n // 2
            next_idx = min(mid_idx + 1, n - 1)
            mid_pt = traj[mid_idx]
            next_pt = traj[next_idx]
            if mid_pt != next_pt:
                arrow = FancyArrowPatch(
                    posA=mid_pt, posB=next_pt,
                    arrowstyle='->', mutation_scale=arrowsize * 10,
                    color=color, linewidth=0.5,
                    shrinkA=0, shrinkB=0, zorder=3)
                ax.add_patch(arrow)

        all_x = [p[0] for t in all_trajectories for p in t]
        all_y = [p[1] for t in all_trajectories for p in t]
        ax.update_datalim(np.column_stack([all_x, all_y]))
        ax.autoscale_view()


n = 20
x = np.linspace(-3, 3, n)
y = np.linspace(-3, 3, n)
X, Y = np.meshgrid(x, y)
U = -Y
V = X

fig, ax = plt.subplots(figsize=(8, 6))
cl_streamplot(ax, x, y, U, V, color='C0', linewidth=1.0, density=1.0)
ax.set_title('Streamplot \u2014 Rotational Flow')
ax.set_xlabel('X')
ax.set_ylabel('Y')
fig.savefig('reference_images/streamplot-basic.png')
fig.savefig('reference_images/streamplot-basic.svg')
print('Saved reference_images/streamplot-basic.svg')
fig.savefig('reference_images/streamplot-basic.pdf')
print('Saved reference_images/streamplot-basic.pdf')
print('Saved reference_images/streamplot-basic.png')
