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
    total = len(results)
    all_pass = failed == 0

    rows_html = []
    for r in results:
        status = r['status']
        if status == 'PASS':
            status_html = '<span style="color:#22c55e;font-weight:bold">PASS</span>'
        elif status == 'FAIL':
            status_html = '<span style="color:#ef4444;font-weight:bold">FAIL</span>'
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
            "mean_ssim": float(np.mean(ssim_values)) if ssim_values else 0.0,
            "min_ssim": float(np.min(ssim_values)) if ssim_values else 0.0,
            "max_ssim": float(np.max(ssim_values)) if ssim_values else 0.0,
        },
        "examples": results,
    }

    json_path = output_dir / 'summary.json'
    json_path.write_text(json.dumps(summary, indent=2) + '\n')
    return str(json_path)


def find_matching_actual(name, actual_dir):
    """Find the matching PNG in the actual directory.

    Looks for exact name match: <name>.png
    Returns path if found, None otherwise.
    """
    actual_path = Path(actual_dir) / f'{name}.png'
    if actual_path.exists():
        return actual_path
    return None


def main():
    parser = argparse.ArgumentParser(
        description='Compare CL matplotlib output vs Python matplotlib reference images.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  %(prog)s --reference reference_images/ --actual examples/ --output comparison_report/
  %(prog)s --reference reference_images/ --actual examples/ --threshold 0.85 --output report/

Exit codes:
  0  All compared examples pass the SSIM threshold
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
    args = parser.parse_args()

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

    ref_images = sorted(ref_dir.glob('*.png'))
    if not ref_images:
        print(f"ERROR: No PNG files found in {ref_dir}", file=sys.stderr)
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

        act_path = find_matching_actual(name, act_dir)
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

        try:
            ref_arr = load_image_rgb(ref_path)
            act_arr = load_image_rgb(act_path)
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

        generate_comparison_sheet(name, ref_arr, act_arr, ssim_score, out_dir)

        note = warning or ''
        status_indicator = 'PASS' if passed else 'FAIL'
        print(f"{ssim_score:.4f}  {status_indicator}", end='')
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

    print()

    html_path = generate_html_report(results, args.threshold, out_dir)
    json_path = generate_summary_json(results, args.threshold, out_dir)

    scored = [r for r in results if r['ssim'] is not None]
    passed_count = sum(1 for r in results if r['status'] == 'PASS')
    failed_count = sum(1 for r in results if r['status'] == 'FAIL')
    skipped_count = sum(1 for r in results if r['status'] == 'SKIP')

    print(f"Results: {passed_count} passed, {failed_count} failed, {skipped_count} skipped")
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
