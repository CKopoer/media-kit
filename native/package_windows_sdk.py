"""Add pinned dependency notices to the CI SDK without changing native binaries."""

import argparse
import hashlib
import json
from pathlib import Path
import zipfile


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--sha256", required=True)
    args = parser.parse_args()
    if args.output.exists() or args.output.resolve() == args.input.resolve():
        raise ValueError("Use a new output archive")
    raw = args.input.read_bytes()
    if sha256(raw) != args.sha256:
        raise ValueError("CI SDK archive SHA-256 mismatch")
    owner = Path(__file__).parent
    source = json.loads((owner / "builds.lock.json").read_text(encoding="utf-8"))["windows"]["commit"]
    with zipfile.ZipFile(args.input) as archive:
        entries = {name: archive.read(name) for name in archive.namelist() if not name.endswith("/")}
    if entries["provenance/mpv.commit"].decode().strip() != source:
        raise ValueError("CI SDK source does not match builds.lock.json")
    native_digests = {name: sha256(data) for name, data in entries.items() if name.endswith((".dll", ".a", ".h", ".jar"))}
    for path in sorted((owner / "windows-sdk-notices").rglob("*")):
        if path.is_file():
            name = "provenance/licenses/pinned-sources/" + path.relative_to(owner / "windows-sdk-notices").as_posix()
            if name in entries:
                raise ValueError("Duplicate SDK notice")
            entries[name] = path.read_bytes()
    entries["provenance/repack.json"] = (json.dumps({
        "ciArchiveSha256": args.sha256,
        "mpvSource": source,
        "packagingScriptSha256": sha256(Path(__file__).read_bytes()),
        "nativeFilesUnchanged": native_digests,
    }, indent=2) + "\n").encode()
    with zipfile.ZipFile(args.output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(entries.items()):
            info = zipfile.ZipInfo(name, date_time=(2000, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, data, compresslevel=9)
    with zipfile.ZipFile(args.output) as archive:
        for name, expected in native_digests.items():
            if sha256(archive.read(name)) != expected:
                raise ValueError("Packaging changed a native SDK file")
    print(f"{sha256(args.output.read_bytes())}  {args.output.name}")


if __name__ == "__main__":
    main()
