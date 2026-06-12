"""
compare_heatmaps.py
Fixation heatmap viewer — overlays new fixations (from CSV) on stimulus images.

Left panel : stimulus image (clean)
Right panel: stimulus image + fixation density heatmap overlay

Controls
--------
← / →  arrow keys  or  Prev / Next buttons : navigate scenes
Radio buttons                               : filter All / Stimulation / Blank
"""

import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from matplotlib.widgets import Button, RadioButtons
from PIL import Image
from scipy.ndimage import gaussian_filter

# ---------------------------------------------------------------------------
# CONFIGURE THESE PATHS
# ---------------------------------------------------------------------------
CSV_PATH  = r'D:\Ripple_data\090925\matlab\secondary_data\fvstim1_fixations.csv'
IMG_DIR   = r'D:\Ripple_data\090925\Session1'   # stimulus images
SCREEN_W  = 1928
SCREEN_H  = 1080
SIGMA     = 40     # Gaussian blur radius in pixels
OVERLAY_ALPHA = 0.70   # heatmap opacity over image (0 = invisible, 1 = opaque)
# ---------------------------------------------------------------------------

CMAP = plt.cm.jet      # blue → green → yellow → red (classic eye-tracking)
NORM = mcolors.Normalize(vmin=0, vmax=1)


def build_heatmap(x_arr, y_arr, dur_arr, w=SCREEN_W, h=SCREEN_H, sigma=SIGMA):
    """Duration-weighted fixation density, Gaussian-smoothed, normalised 0–1."""
    canvas = np.zeros((h, w), dtype=np.float64)
    xi = np.clip(x_arr.astype(int), 0, w - 1)
    yi = np.clip(y_arr.astype(int), 0, h - 1)
    np.add.at(canvas, (yi, xi), dur_arr)
    smoothed = gaussian_filter(canvas, sigma=sigma)
    if smoothed.max() > 0:
        smoothed /= smoothed.max()
    return smoothed


def overlay_heatmap_on_image(stim_img, heatmap):
    """
    Blend a normalised heatmap (H×W float) onto an RGB stimulus image.
    Returns an H×W×3 uint8 array.
    """
    # Resize stimulus to match canvas size if needed
    h, w = heatmap.shape
    if stim_img.shape[:2] != (h, w):
        pil = Image.fromarray(stim_img).resize((w, h), Image.LANCZOS)
        stim_img = np.array(pil)

    # Map heatmap values to RGBA colours
    hm_rgba = CMAP(NORM(heatmap))          # H×W×4, float32 in [0,1]
    hm_rgb  = hm_rgba[..., :3]
    alpha   = heatmap[..., np.newaxis]     # brighter where more fixations

    # Only blend where there is signal (mask out near-zero areas)
    blend_alpha = (alpha ** 0.3) * OVERLAY_ALPHA   # sharper falloff keeps low-density areas transparent

    base = stim_img.astype(np.float32) / 255.0
    blended = base * (1 - blend_alpha) + hm_rgb * blend_alpha
    return (np.clip(blended, 0, 1) * 255).astype(np.uint8)


# ---------------------------------------------------------------------------
# Load CSV data
# ---------------------------------------------------------------------------
df = pd.read_csv(CSV_PATH)
scenes   = sorted(df['Scene'].unique())
n_scenes = len(scenes)

_stim_cache = {}

def load_stimulus(scene):
    if scene not in _stim_cache:
        path = os.path.join(IMG_DIR, f'{scene}.jpg')
        if os.path.exists(path):
            _stim_cache[scene] = np.array(Image.open(path).convert('RGB'))
        else:
            _stim_cache[scene] = None
    return _stim_cache[scene]


# ---------------------------------------------------------------------------
# Build figure
# ---------------------------------------------------------------------------
fig = plt.figure(figsize=(19, 9))
fig.patch.set_facecolor('#1a1a1a')

ax_left  = fig.add_axes([0.01,  0.12, 0.465, 0.83])
ax_right = fig.add_axes([0.515, 0.12, 0.465, 0.83])
ax_cbar  = fig.add_axes([0.982, 0.12, 0.010, 0.83])

for ax in (ax_left, ax_right):
    ax.set_facecolor('#1a1a1a')
    ax.axis('off')

# Navigation buttons
ax_prev  = fig.add_axes([0.31, 0.025, 0.08, 0.055])
ax_next  = fig.add_axes([0.61, 0.025, 0.08, 0.055])
ax_radio = fig.add_axes([0.02, 0.010, 0.22, 0.090])

btn_prev = Button(ax_prev, '◀  Prev', color='#2e2e2e', hovercolor='#484848')
btn_next = Button(ax_next, 'Next  ▶', color='#2e2e2e', hovercolor='#484848')
for btn in (btn_prev, btn_next):
    btn.label.set_color('white')
    btn.label.set_fontsize(10)

radio = RadioButtons(ax_radio, ('All', 'Stimulation', 'Blank'), activecolor='#f0a500')
ax_radio.set_facecolor('#262626')
for lbl in radio.labels:
    lbl.set_color('white')
    lbl.set_fontsize(9)

# Colorbar
sm = plt.cm.ScalarMappable(cmap=CMAP, norm=NORM)
sm.set_array([])
cb = fig.colorbar(sm, cax=ax_cbar)
cb.set_label('Norm. fixation density', color='#aaaaaa', fontsize=7.5)
cb.ax.yaxis.set_tick_params(color='#aaaaaa')
plt.setp(cb.ax.yaxis.get_ticklabels(), color='#aaaaaa', fontsize=7)

# Titles / counter
title_obj   = fig.text(0.50, 0.975, '', ha='center', va='top',
                       fontsize=13, color='white', fontweight='bold')
counter_obj = fig.text(0.50, 0.055, '', ha='center', va='center',
                       fontsize=9, color='#888888')

state = {'idx': 0, 'filter': 'All'}


def update():
    scene = scenes[state['idx']]
    filt  = state['filter']

    sub = df[df['Scene'] == scene]
    if filt != 'All':
        sub = sub[sub['TrialType'] == filt]
    n_fix = len(sub)

    stim = load_stimulus(scene)

    # ---- Left: clean stimulus image ----------------------------------------
    ax_left.clear()
    ax_left.axis('off')
    if stim is not None:
        ax_left.imshow(stim, aspect='auto',
                       extent=[0, SCREEN_W, SCREEN_H, 0], origin='upper')
    else:
        ax_left.text(0.5, 0.5, 'Image not found',
                     ha='center', va='center', transform=ax_left.transAxes,
                     color='#666666', fontsize=11)
    ax_left.set_title('Stimulus image', color='#cccccc', fontsize=11, pad=5)

    # ---- Right: heatmap overlaid on stimulus --------------------------------
    ax_right.clear()
    ax_right.axis('off')

    if n_fix >= 1 and stim is not None:
        hm      = build_heatmap(sub['x'].values, sub['y'].values,
                                sub['Duration'].values)
        blended = overlay_heatmap_on_image(stim, hm)
        ax_right.imshow(blended, aspect='auto',
                        extent=[0, SCREEN_W, SCREEN_H, 0], origin='upper')
        # Subtle fixation-centre dots
        ax_right.scatter(sub['x'], sub['y'],
                         s=6, c='white', alpha=0.35, linewidths=0, zorder=5)
    elif stim is not None:
        ax_right.imshow(stim, aspect='auto',
                        extent=[0, SCREEN_W, SCREEN_H, 0], origin='upper')
        ax_right.text(0.5, 0.5, f'No fixations\n({filt})',
                      ha='center', va='center', transform=ax_right.transAxes,
                      color='white', fontsize=11,
                      bbox=dict(fc='#00000088', ec='none', pad=6))
    else:
        ax_right.text(0.5, 0.5, 'Image not found',
                      ha='center', va='center', transform=ax_right.transAxes,
                      color='#666666', fontsize=11)

    ax_right.set_title(f'Fixation overlay  ({n_fix} fixations, {filt})',
                       color='#cccccc', fontsize=11, pad=5)

    title_obj.set_text(f'{scene}')
    counter_obj.set_text(f'Scene {state["idx"] + 1} of {n_scenes}')
    fig.canvas.draw_idle()


def on_prev(_):
    state['idx'] = (state['idx'] - 1) % n_scenes
    update()

def on_next(_):
    state['idx'] = (state['idx'] + 1) % n_scenes
    update()

def on_filter(label):
    state['filter'] = label
    update()

def on_key(event):
    if event.key == 'right':
        on_next(None)
    elif event.key == 'left':
        on_prev(None)

btn_prev.on_clicked(on_prev)
btn_next.on_clicked(on_next)
radio.on_clicked(on_filter)
fig.canvas.mpl_connect('key_press_event', on_key)

update()
plt.show()
