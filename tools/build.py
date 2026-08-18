#!/usr/bin/env python3
"""Build DIErrorX.rbxmx from src/, for installing without Rojo.

    python3 tools/build.py [--out build/DIErrorX.rbxmx]

The result is a model file containing one Script (the plugin) with the lettered
ModuleScripts inside it.  Drop it in your Studio plugins folder, or right-click
it in Studio and choose "Save as Local Plugin".
"""
import argparse
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
ENTRY = "init.server.luau"


def cdata(text: str) -> str:
    # A CDATA section cannot contain "]]>", so split it across two sections.
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(class_name: str, name: str, source: str, referent: int, children: str = "") -> str:
    props = [
        f"<string name=\"Name\">{name}</string>",
        f"<ProtectedString name=\"Source\">{cdata(source)}</ProtectedString>",
    ]
    if class_name == "Script":
        # Legacy run context: plugin scripts run because of where they live.
        props.append('<token name="RunContext">0</token>')
        props.append('<bool name="Disabled">false</bool>')
    body = "\n\t\t\t".join(props)
    return (
        f'\t<Item class="{class_name}" referent="RBX{referent}">\n'
        f"\t\t<Properties>\n\t\t\t{body}\n\t\t</Properties>\n"
        f"{children}"
        f"\t</Item>\n"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default=str(ROOT / "build" / "DIErrorX.rbxmx"))
    args = parser.parse_args()

    entry = SRC / ENTRY
    if not entry.exists():
        print(f"missing {entry}", file=sys.stderr)
        return 1

    modules = sorted(path for path in SRC.glob("*.luau") if path.name != ENTRY)

    children = []
    for index, path in enumerate(modules, start=1):
        children.append(
            item("ModuleScript", path.stem, path.read_text(), index)
            .replace("\n\t", "\n\t\t")
        )

    xml = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" '
        'version="4">\n'
        + item("Script", "DIErrorX", entry.read_text(), 0, "".join(children))
        + "</roblox>\n"
    )

    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(xml)

    total = sum(len(path.read_text().splitlines()) for path in [entry, *modules])
    print(f"{out}  --  {len(modules) + 1} scripts, {total} lines, {len(xml) // 1024} KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
