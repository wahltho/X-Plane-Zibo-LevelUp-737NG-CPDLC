#!/usr/bin/env python3
"""Restricted text-patch operation used by the AUTO JETWAY installer."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any


class PatchError(RuntimeError):
    """Raised when a patch precondition or integrity check fails."""


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_path(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise PatchError(f"Expected a JSON object in {path}")
    return value


def split_text_bytes(data: bytes) -> tuple[list[str], str, bool]:
    crlf_count = data.count(b"\r\n")
    lf_only_count = data.count(b"\n") - crlf_count
    eol = "\r\n" if crlf_count > lf_only_count else "\n"
    has_final_eol = data.endswith((b"\n", b"\r"))
    text = data.decode("utf-8", errors="strict")
    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    if has_final_eol and lines and lines[-1] == "":
        lines.pop()
    return lines, eol, has_final_eol


def join_text_bytes(lines: list[str], eol: str, has_final_eol: bool) -> bytes:
    text = eol.join(lines)
    if has_final_eol:
        text += eol
    return text.encode("utf-8")


def _find_sequence(lines: list[str], sequence: list[str]) -> list[int]:
    if not sequence:
        raise PatchError("Empty text replacement sequence")
    width = len(sequence)
    return [
        index
        for index in range(len(lines) - width + 1)
        if lines[index : index + width] == sequence
    ]


def _matches_are_inside(
    inner_matches: list[int], inner_width: int, outer_start: int, outer_width: int
) -> bool:
    outer_end = outer_start + outer_width
    return all(
        outer_start <= start and start + inner_width <= outer_end
        for start in inner_matches
    )


def apply_exact_text_replacements(data: bytes, spec: dict[str, Any]) -> bytes:
    if spec.get("format") != "exact-text-replacements-v1":
        raise PatchError("Unsupported text patch format")
    replacements = spec.get("replacements")
    if not isinstance(replacements, list) or not replacements:
        raise PatchError("Text patch contains no replacements")

    lines, eol, has_final_eol = split_text_bytes(data)
    for replacement in replacements:
        old = replacement["oldLines"]
        new = replacement["newLines"]
        old_matches = _find_sequence(lines, old)
        new_matches = _find_sequence(lines, new)
        name = replacement.get("name", "unnamed replacement")
        if len(new_matches) == 1 and _matches_are_inside(
            old_matches, len(old), new_matches[0], len(new)
        ):
            continue
        if len(old_matches) == 1 and not new_matches:
            start = old_matches[0]
            lines[start : start + len(old)] = new
        else:
            raise PatchError(
                f"{name}: expected exactly one original block or one installed "
                f"block; found original={len(old_matches)}, installed={len(new_matches)}"
            )
    return join_text_bytes(lines, eol, has_final_eol)


def remove_exact_text_replacements(data: bytes, spec: dict[str, Any]) -> bytes:
    if spec.get("format") != "exact-text-replacements-v1":
        raise PatchError("Unsupported text patch format")
    replacements = spec.get("replacements")
    if not isinstance(replacements, list) or not replacements:
        raise PatchError("Text patch contains no replacements")

    lines, eol, has_final_eol = split_text_bytes(data)
    for replacement in reversed(replacements):
        old = replacement["oldLines"]
        new = replacement["newLines"]
        old_matches = _find_sequence(lines, old)
        new_matches = _find_sequence(lines, new)
        name = replacement.get("name", "unnamed replacement")
        if len(new_matches) == 1 and _matches_are_inside(
            old_matches, len(old), new_matches[0], len(new)
        ):
            start = new_matches[0]
            lines[start : start + len(new)] = old
        elif not new_matches and len(old_matches) == 1:
            continue
        else:
            raise PatchError(
                f"{name}: expected exactly one installed block or one original "
                f"block; found installed={len(new_matches)}, original={len(old_matches)}"
            )
    return join_text_bytes(lines, eol, has_final_eol)


def apply_operation(data: bytes, operation: str, spec: dict[str, Any]) -> bytes:
    if operation == "exact-text-replacements-v1":
        return apply_exact_text_replacements(data, spec)
    raise PatchError(f"Unsupported patch operation: {operation}")


def remove_operation(data: bytes, operation: str, spec: dict[str, Any]) -> bytes:
    if operation == "exact-text-replacements-v1":
        return remove_exact_text_replacements(data, spec)
    raise PatchError(f"Unsupported patch operation: {operation}")
