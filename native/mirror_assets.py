"""Fetch immutable native assets and verify their complete SHA-256 digests."""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
from pathlib import Path
import shutil
from urllib.request import Request, urlopen


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def fetch(asset: dict, cache: Path, bootstrap: Path | None, origin: bool) -> Path:
    target = cache / asset["name"]
    if not target.exists():
        partial = target.with_suffix(target.suffix + ".partial")
        source = bootstrap / asset["bootstrapCache"] if bootstrap and "bootstrapCache" in asset else None
        if source and source.is_file():
            shutil.copyfile(source, partial)
        else:
            request = Request(asset["origin"] if origin else asset["url"], headers={"User-Agent": "media-kit-native-assets"})
            with urlopen(request, timeout=180) as response, partial.open("wb") as output:
                shutil.copyfileobj(response, output, 1024 * 1024)
        if digest(partial) != asset["sha256"]:
            raise ValueError(f"Native asset hash mismatch: {asset['name']}")
        partial.replace(target)
    if digest(target) != asset["sha256"]:
        raise ValueError(f"Cached native asset hash mismatch: {asset['name']}")
    return target


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", required=True, type=Path)
    parser.add_argument("--bootstrap-root", type=Path)
    parser.add_argument("--origin", action="store_true", help="Bootstrap from recorded upstream origins")
    args = parser.parse_args()
    lock = json.loads(Path(__file__).with_name("assets.lock.json").read_text(encoding="utf-8"))
    names = [asset["name"] for asset in lock["assets"]]
    if len(set(names)) != len(names) or any(Path(name).name != name for name in names):
        raise ValueError("Native asset names must be unique basenames")
    args.cache.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=4) as executor:
        pending = [executor.submit(fetch, asset, args.cache, args.bootstrap_root, args.origin) for asset in lock["assets"]]
        for future in as_completed(pending):
            print(f"Verified {future.result().name}", flush=True)
    shutil.copyfile(Path(__file__).with_name("assets.lock.json"), args.cache / "assets.lock.json")


if __name__ == "__main__":
    main()
