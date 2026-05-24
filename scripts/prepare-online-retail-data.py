import argparse
import zipfile
from pathlib import Path

import pandas as pd


REQUIRED_COLUMNS = [
    "Invoice",
    "StockCode",
    "Description",
    "Quantity",
    "InvoiceDate",
    "Price",
    "Customer ID",
    "Country",
]


def clean_text(value):
    if pd.isna(value):
        return ""
    return str(value).replace("\r", " ").replace("\n", " ").strip()


def main():
    parser = argparse.ArgumentParser(description="Convert Online Retail II XLSX zip to Hadoop-friendly CSV.")
    parser.add_argument("zip_path", help="Path to online+retail+ii.zip")
    parser.add_argument("output_csv", help="Output CSV path")
    args = parser.parse_args()

    zip_path = Path(args.zip_path)
    output_csv = Path(args.output_csv)
    output_csv.parent.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(zip_path) as archive:
        xlsx_names = [name for name in archive.namelist() if name.lower().endswith(".xlsx")]
        if not xlsx_names:
            raise SystemExit("No .xlsx file found inside the zip archive.")

        with archive.open(xlsx_names[0]) as workbook_file:
            sheets = pd.read_excel(workbook_file, sheet_name=None, dtype=object)

    frames = []
    for sheet_name, frame in sheets.items():
        missing = [column for column in REQUIRED_COLUMNS if column not in frame.columns]
        if missing:
            raise SystemExit(f"Sheet {sheet_name!r} is missing columns: {', '.join(missing)}")

        frame = frame[REQUIRED_COLUMNS].copy()
        for column in REQUIRED_COLUMNS:
            frame[column] = frame[column].map(clean_text)
        frames.append(frame)

    merged = pd.concat(frames, ignore_index=True)
    merged.to_csv(output_csv, index=False)
    print(f"Wrote {len(merged)} rows to {output_csv}")


if __name__ == "__main__":
    main()
