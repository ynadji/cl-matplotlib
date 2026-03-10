#!/usr/bin/env python3
"""Visual comparison tool for cl-matplotlib vs Python matplotlib.

Compares reference images against CL-generated images using SSIM,
generates 4-panel comparison sheets and an HTML report with JSON summary.

Supports --format all to run PNG, SVG, and PDF comparisons into a unified
report directory with per-format subdirectories and a root index.html.

Exit code 0 = all pass; non-zero = failures or errors.
"""
import argparse
import json
import os
import sys
import shutil
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from skimage.metrics import structural_similarity


def load_image_rgb(path):
    """Load image, composite alpha on white, return uint8 RGB numpy array."""
    img = Image.open(path)
    if img.mode == 'RGBA':
        bg = Image.new('RGB', img.size, (255, 255, 255))
        bg.paste(img, mask=img.split()[3])
        return np.array(bg)
    return np.array(img.convert('RGB'))


def resize_to_match(img1, img2):
    """Resize smaller image to match larger dimensions. Returns (img1, img2)."""
    if img1.shape == img2.shape:
        return img1, img2
    h = max(img1.shape[0], img2.shape[0])
    w = max(img1.shape[1], img2.shape[1])
    if img1.shape[:2] != (h, w):
        img1 = np.array(Image.fromarray(img1).resize((w, h), Image.LANCZOS))
    if img2.shape[:2] != (h, w):
        img2 = np.array(Image.fromarray(img2).resize((w, h), Image.LANCZOS))
    return img1, img2


def compute_ssim(img1, img2):
    """Compute SSIM between two uint8 RGB arrays. Resizes if shapes differ.

    Returns (ssim_score, warning_message_or_None).
    """
    warning = None
    if img1.shape != img2.shape:
        warning = (
            f"Dimension mismatch: {img1.shape[:2]} vs {img2.shape[:2]}; "
            f"resized smaller to match larger"
        )
        img1, img2 = resize_to_match(img1, img2)
    score = structural_similarity(img1, img2, data_range=255, channel_axis=-1)
    return score, warning


def generate_comparison_sheet(name, ref_arr, act_arr, ssim_score, output_dir):
    """Generate 4-panel comparison PNG: reference, actual, diff x10, SSIM heatmap.

    Returns path to the saved comparison image.
    """
    ref_arr, act_arr = resize_to_match(ref_arr, act_arr)

    diff = np.abs(ref_arr.astype(int) - act_arr.astype(int))
    diff_amplified = np.clip(diff * 10, 0, 255).astype(np.uint8)

    ssim_maps = []
    for c in range(3):
        _, ssim_map = structural_similarity(
            ref_arr[:, :, c], act_arr[:, :, c],
            data_range=255, full=True
        )
        ssim_maps.append(ssim_map)
    ssim_heatmap = np.mean(ssim_maps, axis=0)

    fig, axes = plt.subplots(1, 4, figsize=(20, 5))

    axes[0].imshow(ref_arr)
    axes[0].set_title('Reference\n(Python matplotlib)')
    axes[0].axis('off')

    axes[1].imshow(act_arr)
    axes[1].set_title('Actual\n(CL matplotlib)')
    axes[1].axis('off')

    axes[2].imshow(diff_amplified)
    axes[2].set_title('Abs Diff x10')
    axes[2].axis('off')

    im = axes[3].imshow(ssim_heatmap, cmap='RdYlGn', vmin=0, vmax=1)
    axes[3].set_title(f'SSIM Local Map\n(score={ssim_score:.4f})')
    axes[3].axis('off')
    plt.colorbar(im, ax=axes[3], fraction=0.046)

    plt.suptitle(f'{name}  |  SSIM = {ssim_score:.4f}', fontsize=14)
    plt.tight_layout()

    out_path = Path(output_dir) / f'{name}-comparison.png'
    plt.savefig(out_path, dpi=80, bbox_inches='tight')
    plt.close(fig)
    return str(out_path)


def generate_html_report(results, threshold, output_dir, fmt='png'):
    """Generate index.html report with SSIM scores table and embedded comparison images."""
    output_dir = Path(output_dir)
    passed = sum(1 for r in results if r['status'] == 'PASS')
    failed = sum(1 for r in results if r['status'] == 'FAIL')
    skipped = sum(1 for r in results if r['status'] == 'SKIP')
    allowed = sum(1 for r in results if r['status'] == 'ALLOW')
    total = len(results)
    all_pass = failed == 0

    rows_html = []
    for r in results:
        status = r['status']
        if status == 'PASS':
            status_html = '<span style="color:#22c55e;font-weight:bold">PASS</span>'
        elif status == 'FAIL':
            status_html = '<span style="color:#ef4444;font-weight:bold">FAIL</span>'
        elif status == 'ALLOW':
            status_html = '<span style="color:#f59e0b;font-weight:bold">ALLOW</span>'
        else:
            status_html = '<span style="color:#a3a3a3;font-weight:bold">SKIP</span>'

        ssim_str = f"{r['ssim']:.4f}" if r['ssim'] is not None else "N/A"
        note_str = r.get('note', '') or ''

        img_cell = ''
        if status != 'SKIP':
            img_file = f"{r['name']}-comparison.png"
            img_cell = (
                f'<a href="{img_file}" target="_blank">'
                f'<img src="{img_file}" style="max-width:600px;max-height:150px" />'
                f'</a>'
            )

        rows_html.append(f"""        <tr>
          <td>{r['name']}</td>
          <td style="text-align:center">{status_html}</td>
          <td style="text-align:center;font-family:monospace">{ssim_str}</td>
          <td>{img_cell}</td>
          <td style="font-size:0.85em;color:#737373">{note_str}</td>
        </tr>""")

    overall_color = '#22c55e' if all_pass else '#ef4444'
    overall_text = 'ALL PASS' if all_pass else f'{failed} FAILURE(S)'
    fmt_label = fmt.upper()

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>{fmt_label} Comparison Report</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
           max-width: 1200px; margin: 2em auto; padding: 0 1em;
           background: #fafafa; color: #171717; }}
    h1 {{ border-bottom: 2px solid #e5e5e5; padding-bottom: 0.5em; }}
    .summary {{ display: flex; gap: 2em; margin: 1.5em 0; flex-wrap: wrap; }}
    .summary-card {{ background: white; border: 1px solid #e5e5e5; border-radius: 8px;
                     padding: 1em 1.5em; min-width: 120px; text-align: center; }}
    .summary-card .value {{ font-size: 1.8em; font-weight: bold; }}
    .summary-card .label {{ font-size: 0.85em; color: #737373; margin-top: 0.3em; }}
    table {{ width: 100%; border-collapse: collapse; background: white;
             border: 1px solid #e5e5e5; border-radius: 8px; overflow: hidden; }}
    th {{ background: #f5f5f5; padding: 0.8em 1em; text-align: left;
         border-bottom: 2px solid #e5e5e5; font-size: 0.9em; text-transform: uppercase;
         letter-spacing: 0.03em; color: #525252; }}
    td {{ padding: 0.8em 1em; border-bottom: 1px solid #f0f0f0; vertical-align: middle; }}
    tr:hover {{ background: #fafafa; }}
    a.back {{ display: inline-block; margin-bottom: 1em; color: #525252;
              text-decoration: none; font-size: 0.9em; }}
    a.back:hover {{ color: #171717; }}
    .footer {{ margin-top: 2em; font-size: 0.8em; color: #a3a3a3; text-align: center; }}
  </style>
</head>
<body>
  <a class="back" href="../index.html">&larr; Back to overview</a>
  <h1>{fmt_label} Comparison Report</h1>

  <div class="summary">
    <div class="summary-card">
      <div class="value" style="color:{overall_color}">{overall_text}</div>
      <div class="label">Overall Result</div>
    </div>
    <div class="summary-card">
      <div class="value">{total}</div>
      <div class="label">Total Examples</div>
    </div>
    <div class="summary-card">
      <div class="value" style="color:#22c55e">{passed}</div>
      <div class="label">Passed</div>
    </div>
    <div class="summary-card">
      <div class="value" style="color:#ef4444">{failed}</div>
      <div class="label">Failed</div>
    </div>
    <div class="summary-card">
      <div class="value" style="color:#f59e0b">{allowed}</div>
      <div class="label">Allowed</div>
    </div>
    <div class="summary-card">
      <div class="value" style="color:#a3a3a3">{skipped}</div>
      <div class="label">Skipped</div>
    </div>
    <div class="summary-card">
      <div class="value">{threshold:.2f}</div>
      <div class="label">SSIM Threshold</div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th>Example</th>
        <th style="text-align:center">Status</th>
        <th style="text-align:center">SSIM</th>
        <th>Comparison</th>
        <th>Notes</th>
      </tr>
    </thead>
    <tbody>
{chr(10).join(rows_html)}
    </tbody>
  </table>

  <div class="footer">
    Generated by <code>tools/compare.py</code> | Format: {fmt_label} | Threshold: {threshold:.2f}
  </div>
</body>
</html>"""

    html_path = output_dir / 'index.html'
    html_path.write_text(html)
    return str(html_path)


def generate_summary_json(results, threshold, output_dir):
    """Generate summary.json with machine-readable results."""
    output_dir = Path(output_dir)
    scored = [r for r in results if r['ssim'] is not None]
    ssim_values = [r['ssim'] for r in scored]

    summary = {
        "threshold": threshold,
        "overall": {
            "total": len(results),
            "passed": sum(1 for r in results if r['status'] == 'PASS'),
            "failed": sum(1 for r in results if r['status'] == 'FAIL'),
            "skipped": sum(1 for r in results if r['status'] == 'SKIP'),
            "allowed": sum(1 for r in results if r['status'] == 'ALLOW'),
            "mean_ssim": float(np.mean(ssim_values)) if ssim_values else 0.0,
            "min_ssim": float(np.min(ssim_values)) if ssim_values else 0.0,
            "max_ssim": float(np.max(ssim_values)) if ssim_values else 0.0,
        },
        "examples": results,
    }

    json_path = output_dir / 'summary.json'
    json_path.write_text(json.dumps(summary, indent=2) + '\n')
    return str(json_path)


def find_matching_actual(name, actual_dir, fmt='png'):
    """Find the matching file in the actual directory based on format.

    Looks for exact name match: <name>.<ext>
    Returns path if found, None otherwise.
    """
    ext = fmt if fmt != 'png' else 'png'
    actual_path = Path(actual_dir) / f'{name}.{ext}'
    if actual_path.exists():
        return actual_path
    return None


def rasterize_to_png(src_path, dpi, fmt):
    """Rasterize SVG or PDF to a temp PNG. Returns (temp_path, error_str_or_None).
    Caller is responsible for deleting temp_path.
    """
    tmp = tempfile.NamedTemporaryFile(suffix='.png', delete=False)
    tmp.close()
    tmp_path = tmp.name

    if fmt == 'svg':
        # Try resvg first (--dpi ensures pt-unit SVGs match reference PNG dimensions)
        tool = shutil.which('resvg')
        if not tool:
            cargo_path = os.path.expanduser('~/.cargo/bin/resvg')
            if os.path.isfile(cargo_path):
                tool = cargo_path
        if tool:
            cmd = [tool, '--dpi', str(dpi), str(src_path), tmp_path]
        else:
            # Fallback to headless Chrome
            chrome = (shutil.which('google-chrome')
                      or shutil.which('chromium-browser')
                      or shutil.which('chromium'))
            if not chrome:
                try: os.unlink(tmp_path)
                except OSError: pass
                return None, "No SVG rasterizer found; install resvg (cargo install resvg)"
            cmd = [chrome, '--headless', '--disable-gpu',
                   f'--screenshot={tmp_path}',
                   '--window-size=1920,1200',
                   f'file://{os.path.abspath(src_path)}']
        try:
            subprocess.run(cmd, check=True, capture_output=True, timeout=60)
        except subprocess.CalledProcessError as e:
            try: os.unlink(tmp_path)
            except OSError: pass
            return None, f"SVG rasterization failed: {e.stderr.decode()[:200]}"
        except FileNotFoundError:
            try: os.unlink(tmp_path)
            except OSError: pass
            return None, "SVG rasterizer not found"
        return tmp_path, None
    elif fmt == 'pdf':
        tool = shutil.which('pdftoppm')
        if not tool:
            try: os.unlink(tmp_path)
            except OSError: pass
            return None, "Poppler 'pdftoppm' not found; install poppler-utils"
        # pdftoppm adds extension, so use a prefix and rename
        prefix = tmp_path[:-4]  # remove .png
        cmd = [tool, '-r', str(dpi), '-png', '-singlefile', str(src_path), prefix]
        try:
            subprocess.run(cmd, check=True, capture_output=True, timeout=60)
        except subprocess.CalledProcessError as e:
            try: os.unlink(tmp_path)
            except OSError: pass
            return None, f"pdftoppm failed: {e.stderr.decode()[:200]}"
        except FileNotFoundError:
            try: os.unlink(tmp_path)
            except OSError: pass
            return None, "pdftoppm not found"
        # pdftoppm creates prefix.png
        result_path = prefix + '.png'
        if not os.path.exists(result_path):
            try: os.unlink(tmp_path)
            except OSError: pass
            return None, f"pdftoppm did not create {result_path}"
        if result_path != tmp_path:
            try: os.unlink(tmp_path)
            except OSError: pass
        return result_path, None
    else:
        try: os.unlink(tmp_path)
        except OSError: pass
        return None, f"Unsupported format for rasterization: {fmt}"


# ── Per-format comparison runner ────────────────────────────────

def run_comparison(ref_dir, act_dir, out_dir, fmt, threshold, dpi, allowlist,
                   quiet=False):
    """Run comparison for a single format.

    Returns (results_list, passed_count, failed_count, allowed_count, skipped_count).
    """
    ref_dir = Path(ref_dir)
    act_dir = Path(act_dir)
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    ref_ext = {'svg': '*.svg', 'pdf': '*.pdf', 'png': '*.png'}.get(fmt, '*.png')
    ref_images = sorted(ref_dir.glob(ref_ext))
    if not ref_images:
        if not quiet:
            print(f"  WARNING: No {fmt.upper()} files found in {ref_dir}",
                  file=sys.stderr)
        return [], 0, 0, 0, 0

    if not quiet:
        print(f"\n{'='*60}")
        print(f"  {fmt.upper()} comparison  ({len(ref_images)} examples, threshold={threshold:.2f})")
        print(f"{'='*60}")

    results = []
    for ref_path in ref_images:
        name = ref_path.stem
        if not quiet:
            print(f"  {name:.<30s} ", end='', flush=True)

        act_path = find_matching_actual(name, act_dir, fmt=fmt)
        if act_path is None:
            if not quiet:
                print("SKIP (no matching actual image)")
            results.append({
                'name': name,
                'reference': str(ref_path),
                'actual': None,
                'ssim': None,
                'status': 'SKIP',
                'note': 'No matching actual image found',
            })
            continue

        ref_tmp_path = None
        act_tmp_path = None
        try:
            # Rasterize SVG/PDF to temp PNG if needed (both reference AND actual)
            if fmt in ('svg', 'pdf'):
                ref_rast_path, ref_rast_err = rasterize_to_png(ref_path, dpi, fmt)
                if ref_rast_err:
                    if not quiet:
                        print(f"SKIP (rasterize ref: {ref_rast_err})")
                    results.append({
                        'name': name,
                        'reference': str(ref_path),
                        'actual': str(act_path) if act_path else None,
                        'ssim': None,
                        'status': 'SKIP',
                        'note': f'Reference rasterization failed: {ref_rast_err}',
                    })
                    continue
                ref_tmp_path = ref_rast_path
                ref_load_path = ref_rast_path

                act_rast_path, act_rast_err = rasterize_to_png(act_path, dpi, fmt)
                if act_rast_err:
                    if not quiet:
                        print(f"SKIP (rasterize actual: {act_rast_err})")
                    results.append({
                        'name': name,
                        'reference': str(ref_path),
                        'actual': str(act_path),
                        'ssim': None,
                        'status': 'SKIP',
                        'note': f'Rasterization failed: {act_rast_err}',
                    })
                    continue
                act_tmp_path = act_rast_path
                act_load_path = act_rast_path
            else:
                ref_load_path = ref_path
                act_load_path = act_path

            try:
                ref_arr = load_image_rgb(ref_load_path)
                act_arr = load_image_rgb(act_load_path)
            except Exception as e:
                if not quiet:
                    print(f"SKIP (load error: {e})")
                results.append({
                    'name': name,
                    'reference': str(ref_path),
                    'actual': str(act_path),
                    'ssim': None,
                    'status': 'SKIP',
                    'note': f'Image load error: {e}',
                })
                continue

            ssim_score, warning = compute_ssim(ref_arr, act_arr)
            passed = ssim_score >= threshold
            status = 'PASS' if passed else 'FAIL'

            # Allowlist override: FAIL -> ALLOW
            allow_reason = None
            if status == 'FAIL' and name in allowlist:
                status = 'ALLOW'
                allow_reason = allowlist[name]

            generate_comparison_sheet(name, ref_arr, act_arr, ssim_score, out_dir)

            note = warning or ''
            if allow_reason:
                note = f"ALLOW: {allow_reason}" + (f" | {note}" if note else '')
            if not quiet:
                print(f"{ssim_score:.4f}  {status}", end='')
                if allow_reason:
                    print(f"  ({allow_reason})", end='')
                if warning:
                    print(f"  (warning: {warning})", end='')
                print()

            results.append({
                'name': name,
                'reference': str(ref_path),
                'actual': str(act_path),
                'ssim': round(float(ssim_score), 6),
                'status': status,
                'note': note,
            })
        finally:
            for tmp in (ref_tmp_path, act_tmp_path):
                if tmp:
                    try: os.unlink(tmp)
                    except OSError: pass

    generate_html_report(results, threshold, out_dir, fmt=fmt)
    generate_summary_json(results, threshold, out_dir)

    passed_count = sum(1 for r in results if r['status'] == 'PASS')
    failed_count = sum(1 for r in results if r['status'] == 'FAIL')
    allowed_count = sum(1 for r in results if r['status'] == 'ALLOW')
    skipped_count = sum(1 for r in results if r['status'] == 'SKIP')

    if not quiet:
        scored = [r for r in results if r['ssim'] is not None]
        print(f"  {fmt.upper()}: {passed_count} passed, {failed_count} failed, "
              f"{allowed_count} allowed, {skipped_count} skipped")
        if scored:
            vals = [r['ssim'] for r in scored]
            print(f"  SSIM: mean={np.mean(vals):.4f}  min={np.min(vals):.4f}  "
                  f"max={np.max(vals):.4f}")

    return results, passed_count, failed_count, allowed_count, skipped_count


# ── Root index.html for --format all ────────────────────────────

def generate_root_html_report(format_summaries, output_dir):
    """Generate a root index.html that links to each per-format sub-report.

    format_summaries is a list of dicts:
        {'fmt': 'png', 'threshold': 0.95, 'passed': 76, 'failed': 0,
         'allowed': 3, 'skipped': 0, 'total': 79, 'mean_ssim': 0.96}
    """
    output_dir = Path(output_dir)

    total_passed = sum(s['passed'] for s in format_summaries)
    total_failed = sum(s['failed'] for s in format_summaries)
    total_allowed = sum(s['allowed'] for s in format_summaries)
    total_skipped = sum(s['skipped'] for s in format_summaries)
    total_examples = sum(s['total'] for s in format_summaries)
    all_pass = total_failed == 0

    # Format cards
    format_cards_html = []
    for s in format_summaries:
        fmt = s['fmt'].upper()
        f_all_pass = s['failed'] == 0
        card_border = '#22c55e' if f_all_pass else '#ef4444'
        status_text = 'ALL PASS' if f_all_pass else f"{s['failed']} FAIL"
        status_color = '#22c55e' if f_all_pass else '#ef4444'

        format_cards_html.append(f"""
    <a href="{s['fmt']}/index.html" class="format-card" style="border-color:{card_border}">
      <div class="format-header">{fmt}</div>
      <div class="format-status" style="color:{status_color}">{status_text}</div>
      <div class="format-stats">
        <span class="stat"><span class="stat-value" style="color:#22c55e">{s['passed']}</span> pass</span>
        <span class="stat"><span class="stat-value" style="color:#ef4444">{s['failed']}</span> fail</span>
        <span class="stat"><span class="stat-value" style="color:#f59e0b">{s['allowed']}</span> allow</span>
      </div>
      <div class="format-detail">
        Threshold: {s['threshold']:.2f} | Mean SSIM: {s['mean_ssim']:.4f}
      </div>
    </a>""")

    overall_color = '#22c55e' if all_pass else '#ef4444'
    overall_text = 'ALL FORMATS PASS' if all_pass else f'{total_failed} TOTAL FAILURE(S)'

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>CL-Matplotlib Visual Comparison Report</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
           max-width: 1000px; margin: 2em auto; padding: 0 1em;
           background: #fafafa; color: #171717; }}
    h1 {{ border-bottom: 2px solid #e5e5e5; padding-bottom: 0.5em; }}
    .overall {{ display: flex; gap: 2em; margin: 1.5em 0; flex-wrap: wrap; }}
    .overall-card {{ background: white; border: 1px solid #e5e5e5; border-radius: 8px;
                     padding: 1em 1.5em; min-width: 100px; text-align: center; }}
    .overall-card .value {{ font-size: 1.8em; font-weight: bold; }}
    .overall-card .label {{ font-size: 0.85em; color: #737373; margin-top: 0.3em; }}
    .formats {{ display: flex; gap: 1.5em; margin: 2em 0; flex-wrap: wrap; }}
    .format-card {{ display: block; background: white; border: 2px solid #e5e5e5;
                    border-radius: 12px; padding: 1.5em 2em; min-width: 260px;
                    flex: 1; text-decoration: none; color: inherit;
                    transition: box-shadow 0.15s, transform 0.15s; }}
    .format-card:hover {{ box-shadow: 0 4px 12px rgba(0,0,0,0.08); transform: translateY(-2px); }}
    .format-header {{ font-size: 1.4em; font-weight: bold; margin-bottom: 0.4em; }}
    .format-status {{ font-size: 1.1em; font-weight: bold; margin-bottom: 0.8em; }}
    .format-stats {{ display: flex; gap: 1.2em; margin-bottom: 0.6em; }}
    .stat {{ font-size: 0.9em; color: #525252; }}
    .stat-value {{ font-weight: bold; font-size: 1.1em; }}
    .format-detail {{ font-size: 0.8em; color: #a3a3a3; }}
    .footer {{ margin-top: 2em; font-size: 0.8em; color: #a3a3a3; text-align: center; }}
  </style>
</head>
<body>
  <h1>CL-Matplotlib Visual Comparison Report</h1>

  <div class="overall">
    <div class="overall-card">
      <div class="value" style="color:{overall_color}">{overall_text}</div>
      <div class="label">Overall</div>
    </div>
    <div class="overall-card">
      <div class="value">{total_examples}</div>
      <div class="label">Total Comparisons</div>
    </div>
    <div class="overall-card">
      <div class="value" style="color:#22c55e">{total_passed}</div>
      <div class="label">Passed</div>
    </div>
    <div class="overall-card">
      <div class="value" style="color:#ef4444">{total_failed}</div>
      <div class="label">Failed</div>
    </div>
    <div class="overall-card">
      <div class="value" style="color:#f59e0b">{total_allowed}</div>
      <div class="label">Allowed</div>
    </div>
  </div>

  <h2>By Format</h2>
  <div class="formats">
{''.join(format_cards_html)}
  </div>

  <div class="footer">
    Generated by <code>tools/compare.py --format all</code>
  </div>
</body>
</html>"""

    html_path = output_dir / 'index.html'
    html_path.write_text(html)
    return str(html_path)


# ── CLI ─────────────────────────────────────────────────────────

# Default per-format thresholds used by --format all
FORMAT_DEFAULTS = {
    'png': {'threshold': 0.95, 'dpi': 100},
    'svg': {'threshold': 0.90, 'dpi': 100},
    'pdf': {'threshold': 0.88, 'dpi': 100},
}


def main():
    parser = argparse.ArgumentParser(
        description='Compare CL matplotlib output vs Python matplotlib reference images.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  %(prog)s --reference reference_images/ --actual examples/ --output comparison_report/
  %(prog)s --reference ref/ --actual examples/ --format svg --output report/
  %(prog)s --reference ref/ --actual examples/ --format all --output comparison_report/
  %(prog)s --reference ref/ --actual examples/ --allowlist allow.json --output report/

--format all:
  Runs PNG, SVG, and PDF comparisons with calibrated per-format thresholds
  (PNG=0.95, SVG=0.90, PDF=0.88).  Results go into <output>/{png,svg,pdf}/
  with a root <output>/index.html linking to each sub-report.

Exit codes:
  0  All compared examples pass or are allowlisted
  1  One or more examples fail the SSIM threshold
  2  No reference images found or other error
""",
    )
    parser.add_argument(
        '--reference', required=True,
        help='Directory containing reference images (Python matplotlib)',
    )
    parser.add_argument(
        '--actual', required=True,
        help='Directory containing actual images (CL matplotlib)',
    )
    parser.add_argument(
        '--threshold', type=float, default=None,
        help='SSIM pass threshold (default: 0.95 for png, 0.90 for svg, 0.88 for pdf)',
    )
    parser.add_argument(
        '--output', required=True,
        help='Output directory for comparison report',
    )
    parser.add_argument(
        '--format', choices=['png', 'svg', 'pdf', 'all'], default='png',
        help='Format to compare (default: png). Use "all" for combined report.',
    )
    parser.add_argument(
        '--dpi', type=int, default=None,
        help='DPI for SVG/PDF rasterization (default: 100)',
    )
    parser.add_argument(
        '--allowlist', default=None,
        help='JSON file mapping example names to allow reasons. Matched FAILs become ALLOW.',
    )
    args = parser.parse_args()

    # DPI default
    if args.dpi is None:
        args.dpi = 100

    # Load allowlist
    allowlist = {}
    if args.allowlist:
        try:
            with open(args.allowlist) as f:
                allowlist = json.load(f)
            if not isinstance(allowlist, dict):
                print(f"ERROR: Allowlist must be a JSON object, got {type(allowlist).__name__}",
                      file=sys.stderr)
                sys.exit(2)
            print(f"Allowlist: {len(allowlist)} entries from {args.allowlist}")
        except (json.JSONDecodeError, OSError) as e:
            print(f"ERROR: Failed to load allowlist: {e}", file=sys.stderr)
            sys.exit(2)

    ref_dir = Path(args.reference)
    act_dir = Path(args.actual)
    out_dir = Path(args.output)

    if not ref_dir.is_dir():
        print(f"ERROR: Reference directory not found: {ref_dir}", file=sys.stderr)
        sys.exit(2)
    if not act_dir.is_dir():
        print(f"ERROR: Actual directory not found: {act_dir}", file=sys.stderr)
        sys.exit(2)

    out_dir.mkdir(parents=True, exist_ok=True)

    # ── --format all: combined multi-format report ──────────────
    if args.format == 'all':
        print(f"Running combined comparison (PNG + SVG + PDF)")
        print(f"Reference: {ref_dir}")
        print(f"Actual:    {act_dir}")
        print(f"Output:    {out_dir}")

        total_failed = 0
        format_summaries = []

        for fmt in ('png', 'svg', 'pdf'):
            defaults = FORMAT_DEFAULTS[fmt]
            threshold = args.threshold if args.threshold is not None else defaults['threshold']
            dpi = args.dpi or defaults['dpi']
            fmt_out_dir = out_dir / fmt

            results, passed, failed, allowed, skipped = run_comparison(
                ref_dir, act_dir, fmt_out_dir, fmt, threshold, dpi, allowlist)

            total_failed += failed
            scored = [r for r in results if r['ssim'] is not None]
            mean_ssim = float(np.mean([r['ssim'] for r in scored])) if scored else 0.0

            format_summaries.append({
                'fmt': fmt,
                'threshold': threshold,
                'passed': passed,
                'failed': failed,
                'allowed': allowed,
                'skipped': skipped,
                'total': len(results),
                'mean_ssim': mean_ssim,
            })

        root_html = generate_root_html_report(format_summaries, out_dir)

        print(f"\n{'='*60}")
        print(f"  Combined Results")
        print(f"{'='*60}")
        for s in format_summaries:
            status = 'PASS' if s['failed'] == 0 else 'FAIL'
            print(f"  {s['fmt'].upper():>4s}: {s['passed']:>2d} pass, {s['failed']:>2d} fail, "
                  f"{s['allowed']:>2d} allow  (threshold={s['threshold']:.2f}, "
                  f"mean={s['mean_ssim']:.4f})  [{status}]")
        print(f"\n  Root report: {root_html}")
        print(f"  Sub-reports: {out_dir}/{{png,svg,pdf}}/index.html")

        sys.exit(1 if total_failed > 0 else 0)

    # ── Single-format mode ──────────────────────────────────────
    if args.threshold is None:
        args.threshold = FORMAT_DEFAULTS.get(args.format, {}).get('threshold', 0.95)

    print(f"Found reference images in {ref_dir}")
    print(f"Comparing against {act_dir}")
    print(f"Format: {args.format.upper()}")
    print(f"SSIM threshold: {args.threshold:.2f}")
    print(f"Output: {out_dir}")

    results, passed_count, failed_count, allowed_count, skipped_count = run_comparison(
        ref_dir, act_dir, out_dir, args.format, args.threshold, args.dpi, allowlist)

    print(f"\nResults: {passed_count} passed, {failed_count} failed, "
          f"{allowed_count} allowed, {skipped_count} skipped")
    scored = [r for r in results if r['ssim'] is not None]
    if scored:
        ssim_vals = [r['ssim'] for r in scored]
        print(f"SSIM: mean={np.mean(ssim_vals):.4f}  min={np.min(ssim_vals):.4f}  "
              f"max={np.max(ssim_vals):.4f}")
    print(f"Report: {out_dir / 'index.html'}")
    print(f"Summary: {out_dir / 'summary.json'}")

    if failed_count > 0:
        sys.exit(1)
    sys.exit(0)


if __name__ == '__main__':
    main()
