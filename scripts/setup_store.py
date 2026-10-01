#!/usr/bin/env python3
"""Create the game's Game Passes and Developer Products on Roblox.

Reads assets/store.json. For every item without an id it first looks for an
existing pass/product in the universe with the same name (so re-runs and
items made by hand in Creator Hub are reused, never duplicated), otherwise
creates it through Open Cloud with its price and Higgsfield icon. Ids are
written back to assets/store.json and src/shared/Monetization.luau is
regenerated from it.

Environment:
  ROBLOX_API_KEY      Open Cloud key with game-pass:read/write and
                      developer-product:read/write on the experience
  ROBLOX_UNIVERSE_ID  the experience's universe id

Usage:
  python3 scripts/setup_store.py            # create missing items + regenerate
  python3 scripts/setup_store.py --codegen  # only regenerate Monetization.luau
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STORE = ROOT / "assets" / "store.json"
MONETIZATION_LUAU = ROOT / "src" / "shared" / "Monetization.luau"

API = "https://apis.roblox.com"
LABELS = {"game_passes": "game pass", "developer_products": "developer product"}
KINDS = {
    # store.json section: (create/list path, list response key, id field)
    "game_passes": ("/game-passes/v1/universes/{universe}/game-passes", "gamePasses", "gamePassId"),
    "developer_products": (
        "/developer-products/v2/universes/{universe}/developer-products",
        "developerProducts",
        "productId",
    ),
}


class ApiError(RuntimeError):
    def __init__(self, status: int, body: str):
        super().__init__(f"HTTP {status}: {body}")
        self.status = status


def request(method: str, url: str, api_key: str, data: bytes | None = None, content_type: str | None = None) -> dict:
    headers = {"x-api-key": api_key}
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            return json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as err:
        raise ApiError(err.code, err.read().decode("utf-8", "replace")) from err


def list_existing(kind: str, universe: str, api_key: str) -> dict[str, int]:
    path, list_key, id_field = KINDS[kind]
    found: dict[str, int] = {}
    token = ""
    while True:
        url = f"{API}{path.format(universe=universe)}/creator?pageSize=100"
        if token:
            url += f"&pageToken={token}"
        page = request("GET", url, api_key)
        for entry in page.get(list_key) or []:
            if entry.get("name") and entry.get(id_field):
                found.setdefault(entry["name"], int(entry[id_field]))
        token = page.get("nextPageToken") or ""
        if not token:
            return found


def multipart(fields: dict[str, str], image: tuple[str, bytes, str] | None) -> tuple[bytes, str]:
    boundary = uuid.uuid4().hex
    parts: list[bytes] = []
    for name, value in fields.items():
        parts += [
            f"--{boundary}\r\n".encode(),
            f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode(),
            value.encode(),
            b"\r\n",
        ]
    if image:
        filename, data, mime = image
        parts += [
            f"--{boundary}\r\n".encode(),
            f'Content-Disposition: form-data; name="imageFile"; filename="{filename}"\r\n'.encode(),
            f"Content-Type: {mime}\r\n\r\n".encode(),
            data,
            b"\r\n",
        ]
    parts.append(f"--{boundary}--\r\n".encode())
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def download_icon(url: str | None) -> tuple[str, bytes, str] | None:
    if not url:
        return None
    try:
        with urllib.request.urlopen(url, timeout=60) as response:
            data = response.read()
    except Exception as err:  # an icon is nice to have, never a blocker
        print(f"::warning::Could not download icon {url}: {err}")
        return None
    ext = Path(url.split("?")[0]).suffix.lower() or ".png"
    mime = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg"}.get(ext, "image/png")
    return f"icon{ext}", data, mime


def create(kind: str, item: dict, universe: str, api_key: str) -> int:
    path, _, id_field = KINDS[kind]
    fields = {
        "name": item["name"],
        "description": item.get("description", ""),
        "isForSale": "true",
        "price": str(int(item["price"])),
    }
    icon = download_icon(item.get("icon_url"))
    url = f"{API}{path.format(universe=universe)}"
    try:
        body, content_type = multipart(fields, icon)
        created = request("POST", url, api_key, body, content_type)
    except ApiError as err:
        if not icon or err.status != 400:
            raise
        # Retry without the icon if Roblox rejected the image; it can be set later in Creator Hub.
        print(f"::warning::{item['name']}: icon rejected ({err}); creating without icon")
        body, content_type = multipart(fields, None)
        created = request("POST", url, api_key, body, content_type)
    return int(created[id_field])


def luau_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def write_luau(store: dict) -> None:
    def block(items: list[dict]) -> list[str]:
        out = []
        for item in items:
            out += [
                "\t{",
                f"\t\tKey = {luau_string(item['key'])},",
                f"\t\tId = {int(item.get('id') or 0)},",
                f"\t\tName = {luau_string(item['name'])},",
                f"\t\tDescription = {luau_string(item.get('description', ''))},",
                f"\t\tPrice = {int(item['price'])},",
                "\t},",
            ]
        return out

    lines = [
        "--!strict",
        "-- GENERATED by scripts/setup_store.py from assets/store.json. Do not edit by hand.",
        "-- Items with Id = 0 are not on Roblox yet: the shop shows them as \"Soon\".",
        "",
        "export type Item = {",
        "\tKey: string,",
        "\tId: number,",
        "\tName: string,",
        "\tDescription: string,",
        "\tPrice: number, -- Robux, as configured in assets/store.json",
        "}",
        "",
        "local GamePasses: { Item } = {",
        *block(store["game_passes"]),
        "}",
        "",
        "local Products: { Item } = {",
        *block(store["developer_products"]),
        "}",
        "",
        "local byKey: { [string]: Item } = {}",
        "for _, item in GamePasses do",
        "\tbyKey[item.Key] = item",
        "end",
        "for _, item in Products do",
        "\tbyKey[item.Key] = item",
        "end",
        "",
        "return {",
        "\tGamePasses = GamePasses,",
        "\tProducts = Products,",
        "\tByKey = byKey,",
        "}",
        "",
    ]
    MONETIZATION_LUAU.write_text("\n".join(lines), encoding="utf-8")


def save_store(store: dict) -> None:
    STORE.write_text(json.dumps(store, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--codegen", action="store_true", help="only regenerate Monetization.luau")
    args = parser.parse_args()

    store = json.loads(STORE.read_text(encoding="utf-8"))
    if args.codegen:
        write_luau(store)
        return 0

    api_key = os.environ.get("ROBLOX_API_KEY")
    universe = os.environ.get("ROBLOX_UNIVERSE_ID")
    missing = [item for kind in KINDS for item in store[kind] if not item.get("id")]
    if not missing:
        print("Store already set up; nothing to create.")
    elif not api_key or not universe:
        print("ROBLOX_API_KEY / ROBLOX_UNIVERSE_ID not set; skipping store setup.")
    else:
        for kind in KINDS:
            pending = [item for item in store[kind] if not item.get("id")]
            if not pending:
                continue
            try:
                existing = list_existing(kind, universe, api_key)
            except ApiError as err:
                hint = " (add game-pass / developer-product read+write scopes to the API key)" if err.status in (401, 403) else ""
                print(f"::warning::Could not list {kind}{hint}: {err}")
                continue
            for item in pending:
                try:
                    if item["name"] in existing:
                        item["id"] = existing[item["name"]]
                        print(f"Reusing existing {LABELS[kind]} '{item['name']}' -> {item['id']}")
                    else:
                        item["id"] = create(kind, item, universe, api_key)
                        print(f"Created {LABELS[kind]} '{item['name']}' ({item['price']} R$) -> {item['id']}")
                except ApiError as err:
                    print(f"::warning::Could not create '{item['name']}': {err}")
                    continue
                save_store(store)

    write_luau(store)
    return 0


if __name__ == "__main__":
    sys.exit(main())
