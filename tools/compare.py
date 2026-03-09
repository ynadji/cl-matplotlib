#!/usr/bin/env python3
"""Visual comparison tool for cl-matplotlib vs Python matplotlib.

Compares reference images against CL-generated images using SSIM,
generates 4-panel comparison sheets and an HTML report with JSON summary.

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


def generate_html_report(results, threshold, output_dir):
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

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>CL-Matplotlib Visual Comparison Report</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
           max-width: 1200px; margin: 2em auto; padding: 0 1em;
           background: #fafafa; color: #171717; }}
    h1 {{ border-bottom: 2px solid #e5e5e5; padding-bottom: 0.5em; }}
    .summary {{ display: flex; gap: 2em; margin: 1.5em 0; }}
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
    .footer {{ margin-top: 2em; font-size: 0.8em; color: #a3a3a3; text-align: center; }}
  </style>
</head>
<body>
  <h1>CL-Matplotlib Visual Comparison Report</h1>

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
    Generated by <code>tools/compare.py</code> | Threshold: {threshold:.2f}
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

def main():
    parser = argparse.ArgumentParser(
        description='Compare CL matplotlib output vs Python matplotlib reference images.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  %(prog)s --reference reference_images/ --actual examples/ --output comparison_report/
  %(prog)s --reference ref/ --actual examples/ --format svg --output report/
  %(prog)s --reference ref/ --actual examples/ --allowlist allow.json --output report/

SVG DPI note:
  SVG rasterization defaults to 96 DPI (CSS px = 1/96 inch).
  PDF rasterization defaults to 100 DPI. Override with --dpi N.

Exit codes:
  0  All compared examples pass or are allowlisted
  1  One or more examples fail the SSIM threshold
  2  No reference images found or other error
""",
    )
    parser.add_argument(
        '--reference', required=True,
        help='Directory containing reference PNG images (Python matplotlib)',
    )
    parser.add_argument(
        '--actual', required=True,
        help='Directory containing actual PNG images (CL matplotlib)',
    )
    parser.add_argument(
        '--threshold', type=float, default=0.90,
        help='SSIM pass threshold (default: 0.90)',
    )
    parser.add_argument(
        '--output', required=True,
        help='Output directory for comparison report',
    )
    parser.add_argument(
        '--format', choices=['png', 'svg', 'pdf'], default='png',
        help='Format of actual images to compare (default: png). SVG/PDF are rasterized first.',
    )
    parser.add_argument(
        '--dpi', type=int, default=None,
        help='DPI for SVG/PDF rasterization (default: 96 for SVG, 100 for PDF)',
    )
    parser.add_argument(
        '--allowlist', default=None,
        help='JSON file mapping example names to allow reasons. Matched FAILs become ALLOW.',
    )
    args = parser.parse_args()

    # Format-specific DPI defaults (SVG/PDF/PNG: 100)
    if args.dpi is None:
        args.dpi = 100

    # Load allowlist
    allowlist = {}
    if args.allowlist:
        try:
            with open(args.allowlist) as f:
                allowlist = json.load(f)
            if not isinstance(allowlist, dict):
                print(f"ERROR: Allowlist must be a JSON object, got {type(allowlist).__name__}", file=sys.stderr)
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

    ref_ext = {'svg': '*.svg', 'pdf': '*.pdf', 'png': '*.png'}.get(args.format, '*.png')
    ref_images = sorted(ref_dir.glob(ref_ext))
    if not ref_images:
        print(f"ERROR: No {args.format.upper()} files found in {ref_dir}", file=sys.stderr)
        sys.exit(2)

    print(f"Found {len(ref_images)} reference images in {ref_dir}")
    print(f"Comparing against {act_dir}")
    print(f"SSIM threshold: {args.threshold:.2f}")
    print(f"Output: {out_dir}")
    print()

    results = []
    for ref_path in ref_images:
        name = ref_path.stem
        print(f"  {name:.<30s} ", end='', flush=True)

        act_path = find_matching_actual(name, act_dir, fmt=args.format)
        if act_path is None:
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
            if args.format in ('svg', 'pdf'):
                # Rasterize reference
                ref_rast_path, ref_rast_err = rasterize_to_png(ref_path, args.dpi, args.format)
                if ref_rast_err:
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

                # Rasterize actual
                act_rast_path, act_rast_err = rasterize_to_png(act_path, args.dpi, args.format)
                if act_rast_err:
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
            passed = ssim_score >= args.threshold
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

    print()

    html_path = generate_html_report(results, args.threshold, out_dir)
    json_path = generate_summary_json(results, args.threshold, out_dir)

    scored = [r for r in results if r['ssim'] is not None]
    passed_count = sum(1 for r in results if r['status'] == 'PASS')
    failed_count = sum(1 for r in results if r['status'] == 'FAIL')
    allowed_count = sum(1 for r in results if r['status'] == 'ALLOW')
    skipped_count = sum(1 for r in results if r['status'] == 'SKIP')

    print(f"Results: {passed_count} passed, {failed_count} failed, {allowed_count} allowed, {skipped_count} skipped")
    if scored:
        ssim_vals = [r['ssim'] for r in scored]
        print(f"SSIM: mean={np.mean(ssim_vals):.4f}  min={np.min(ssim_vals):.4f}  max={np.max(ssim_vals):.4f}")
    print(f"Report: {html_path}")
    print(f"Summary: {json_path}")

    if failed_count > 0:
        sys.exit(1)
    sys.exit(0)


if __name__ == '__main__':
    main()
