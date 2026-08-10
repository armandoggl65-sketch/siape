#!/usr/bin/env python
"""CLI: genera el reporte ejecutivo (Opción 1) a partir de un archivo de periodo.

Uso:
    python scripts/run_analysis.py --period-file data/periodo_ejemplo.json
    python scripts/run_analysis.py --period-file data/periodo_ejemplo.json --output reporte.md
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from siape.analysis.engine import run_analysis  # noqa: E402
from siape.reports.executive import render_markdown  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--period-file", required=True, help="Ruta al JSON de datos del periodo")
    parser.add_argument("--output", help="Ruta donde guardar el reporte Markdown (por defecto, stdout)")
    args = parser.parse_args()

    reporte = run_analysis(args.period_file)
    markdown = render_markdown(reporte)

    if args.output:
        Path(args.output).write_text(markdown, encoding="utf-8")
        print(f"Reporte guardado en {args.output}")
    else:
        print(markdown)


if __name__ == "__main__":
    main()
