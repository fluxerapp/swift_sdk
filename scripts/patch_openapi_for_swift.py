#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Normalize OpenAPI patterns that swift-openapi-generator mishandles"""

from __future__ import annotations

import copy
import json
import sys
from typing import Any


def _is_null_schema(node: Any) -> bool:
    return isinstance(node, dict) and node.get("type") == "null"


def _unwrap_nullable_anyof(node: Any) -> Any:
    if not isinstance(node, dict):
        return node

    if "anyOf" in node:
        variants = node["anyOf"]
        if isinstance(variants, list):
            non_null = [v for v in variants if not _is_null_schema(v)]
            if len(non_null) == 1 and len(variants) == 2:
                merged = copy.deepcopy(non_null[0])
                if isinstance(merged, dict):
                    for key, value in node.items():
                        if key != "anyOf":
                            merged.setdefault(key, value)
                return _unwrap_nullable_anyof(merged)

    out: dict[str, Any] = {}
    for key, value in node.items():
        if isinstance(value, dict):
            out[key] = _unwrap_nullable_anyof(value)
        elif isinstance(value, list):
            out[key] = [
                _unwrap_nullable_anyof(item) if isinstance(item, dict) else item
                for item in value
            ]
        else:
            out[key] = value
    return out


def _drop_shared_multipart_json_bodies(document: dict[str, Any]) -> None:
    """Drop multipart bodies when they reuse the same schema as JSON on one operation."""
    paths = document.get("paths", {})
    for path_item in paths.values():
        if not isinstance(path_item, dict):
            continue
        for operation in path_item.values():
            if not isinstance(operation, dict):
                continue
            request_body = operation.get("requestBody")
            if not isinstance(request_body, dict):
                continue
            content = request_body.get("content")
            if not isinstance(content, dict):
                continue
            json_schema = content.get("application/json", {}).get("schema")
            multipart = content.get("multipart/form-data")
            if json_schema is None or multipart is None:
                continue
            multipart_schema = multipart.get("schema")
            if json_schema == multipart_schema:
                del content["multipart/form-data"]


def patch(document: dict[str, Any]) -> dict[str, Any]:
    document = _unwrap_nullable_anyof(document)
    _drop_shared_multipart_json_bodies(document)
    return document


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.json> <output.json>", file=sys.stderr)
        return 2

    with open(sys.argv[1], encoding="utf-8") as handle:
        document = json.load(handle)

    patched = patch(document)

    with open(sys.argv[2], "w", encoding="utf-8") as handle:
        json.dump(patched, handle, indent=2)
        handle.write("\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
