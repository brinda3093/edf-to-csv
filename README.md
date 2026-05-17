# edf-to-csv

MATLAB pipeline that extracts an Eyelink `.edf` recording into a CSV file for
fixations and a 1×3 summary figure (x coordinates, y coordinates, fixation
duration).

Fixations are taken from Eyelink's built-in event detection (`Efix`), filtered
to those that fall inside the on-screen image rectangle, and expressed in
image-local pixel coordinates.

## Repository layout

```
edf-to-csv/
├── edf_to_csv.m              # main entry point
├── helper_fun/
│   ├── extract_fixations.m   # EDF events → CSV
│   └── plot_fixations.m      # CSV → 1×3 histogram figure (PNG)
├── edf-converter-master/     # Edf2Mat converter
└── data/
    ├── sample_data.edf       # example recording
    ├── sample_data.mat       # matching experiment-parameters file
    └── secondary_data/       # outputs land here
        ├── fixations_data.csv
        └── fixations_summary.png
```

## Requirements

- MATLAB (tested on R2023a, Windows). No extra toolboxes needed for the
  default pipeline.
- The bundled `edf-converter-master/` provides the `Edf2Mat` class and the
  platform-specific mex / DLL files for reading `.edf` files (Windows 32/64,
  macOS Intel/ARM). The script adds it to the path automatically.

## Companion `.mat` file

`edf_to_csv.m` expects a `<sessionName>.mat` alongside the `.edf` containing:

- `params.durations.t_freeview` — free-viewing duration per trial (s)
- `Results.TrialSuccess` — logical/0–1 vector marking completed trials
- `Results.ImageShown` — cell array of image filenames per trial
- `Results.ImageRect` — cell array of `[xmin ymin xmax ymax]` per trial (the
  PsychToolbox destination rect of the displayed image)

`sample_data.mat` in `data/` is a working example.

### Coordinate convention

CSV `x` / `y` are **image-local**: `(0, 0)` is the top-left of the displayed
image, and the maxima equal the image width and height. In the example data,
the image is 1440 × 1080 px but the screen is 1920 px wide, so the image was
centered horizontally (`imgRect = [240 0 1680 1080]`). The pipeline subtracts
`imgRect`'s top-left from each Eyelink fixation, so any screen-coordinate
offset from centering is removed automatically and the resulting `x` / `y`
run `0`–`1440` and `0`–`1080` rather than full-screen pixels.

## Usage

1. Drop your recording in `data/` as `<sessionName>.edf` together with the
   matching `<sessionName>.mat`.
2. Open `edf_to_csv.m` and set `sessionName` near the top.
3. Run it (`Run` in the editor, or `matlab -batch "edf_to_csv"`).

Outputs land in `data/secondary_data/`:

- `fixations_data.csv` — columns `Subject, Scene, FixationNumber, x, y, Duration, Task`
- `fixations_summary.png` — 1×3 histogram (x, y, duration) at 300 dpi

## Citation

If you use this code, please cite:

> Soyuhos, O., Hayes, T. R., Hu, W., Hamel, T. P., Sevak, B., Henderson, J. M., & Chen, X. (2026). *Meaning-based guidance of attention in rhesus monkeys during naturalistic scene viewing* (p. 2026.03.11.711223). bioRxiv. https://doi.org/10.64898/2026.03.11.711223

BibTeX:

```bibtex
@article{soyuhos2026meaning,
  title   = {Meaning-based guidance of attention in rhesus monkeys during naturalistic scene viewing},
  author  = {Soyuhos, Orhan and Hayes, Taylor R. and Hu, W. and Hamel, T. P. and Sevak, B. and Henderson, John M. and Chen, X.},
  journal = {bioRxiv},
  pages   = {2026.03.11.711223},
  year    = {2026},
  doi     = {10.64898/2026.03.11.711223}
}
```

## Acknowledgments

The `edf-converter-master/` directory bundles the **Edf2Mat** MATLAB toolbox
(`@Edf2Mat` class and `+edfmex` mex wrappers around SR-Research's `edfapi`)
developed at the University of Zurich. The toolbox is redistributed here under
its original license so the pipeline runs out of the box on Windows and macOS.
Source and updates:

> University of Zurich — Edf2Mat MATLAB converter:
> https://github.com/uzh/edf-converter

