from pathlib import Path

import pandas as pd


SOURCE_DIR = Path("/home/song/projects/ib-qlib-pipeline/data/raw/prices")
TARGET_DIR = Path("/home/song/projects/Kronos-learn/data")


def convert_file(source_path: Path, target_path: Path) -> int:
    df = pd.read_csv(source_path)
    required_cols = ["date", "open", "high", "low", "close", "volume"]
    missing = [col for col in required_cols if col not in df.columns]
    if missing:
        raise ValueError(f"{source_path.name} missing columns: {missing}")

    out_df = pd.DataFrame(
        {
            "timestamps": pd.to_datetime(df["date"]),
            "open": pd.to_numeric(df["open"], errors="coerce"),
            "high": pd.to_numeric(df["high"], errors="coerce"),
            "low": pd.to_numeric(df["low"], errors="coerce"),
            "close": pd.to_numeric(df["close"], errors="coerce"),
            "volume": pd.to_numeric(df["volume"], errors="coerce"),
            "amount": 0.0,
        }
    ).dropna()

    out_df.to_csv(target_path, index=False, date_format="%Y-%m-%d")
    return len(out_df)


def main() -> None:
    TARGET_DIR.mkdir(parents=True, exist_ok=True)
    converted = 0
    total_rows = 0

    for source_path in sorted(SOURCE_DIR.glob("*.csv")):
        target_name = f"{source_path.stem}_daily_kronos.csv"
        target_path = TARGET_DIR / target_name
        total_rows += convert_file(source_path, target_path)
        converted += 1

    print(f"converted_files={converted}")
    print(f"total_rows={total_rows}")
    print(f"target_dir={TARGET_DIR}")


if __name__ == "__main__":
    main()
