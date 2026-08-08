#!/usr/bin/env python3.14
"""Generate deterministic Python 3.14 str.format reference fixtures."""

from __future__ import annotations

import argparse
import json
import locale
import math
from pathlib import Path
import platform
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "test" / "fixtures" / "python_format.json"


def value(type_: str, value: Any) -> dict[str, Any]:
    return {"type": type_, "value": value}


def case(
    id_: str,
    template: str,
    positional: list[dict[str, Any]] | None = None,
    named: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    return {
        "id": id_,
        "template": template,
        "positional": positional or [],
        "named": named or {},
    }


CASES = [
    case(
        "default-bigint",
        "{}",
        [value("bigint", "123456789012345678901234567890")],
    ),
    case("default-double", "{}", [value("double", 1234.5)]),
    case("default-double-negative-zero", "{}", [value("double", "-0")]),
    case("default-int", "{}", [value("int", -42)]),
    case("default-string", "{}", [value("string", "hello")]),
    case("error-invalid-float-spec", "{:d}", [value("double", 1.5)]),
    case("error-invalid-integer-spec", "{:.2d}", [value("int", 42)]),
    case("error-missing-list-item", "{0[2]}", [value("list", [value("string", "x")])]),
    case("error-missing-map-integer-key", "{0[1]}", [value("map", [])]),
    case("error-missing-map-item", "{0[missing]}", [value("map", [])]),
    case("error-missing-named", "{missing}"),
    case("error-missing-positional", "{}"),
    case("error-mixed-numbering", "{0} {}", [value("string", "x")]),
    case("error-unmatched-brace", "value {"),
    case("error-unknown-conversion", "{!q}", [value("int", 1)]),
    case("float-E", "{:.3E}", [value("double", 12.5)]),
    case("float-F", "{:F}", [value("double", 12.5)]),
    case("float-G", "{:.4G}", [value("double", 12345.0)]),
    case("float-e", "{:.3e}", [value("double", 12.5)]),
    case("float-f", "{:.2f}", [value("double", 12.345)]),
    case("float-g", "{:.4g}", [value("double", 12345.0)]),
    case("float-n", "{:.4n}", [value("double", 1234.5)]),
    case("float-percent", "{:.1%}", [value("double", 0.125)]),
    case("grammar-automatic", "{} {}", [value("string", "a"), value("string", "b")]),
    case("grammar-escaped-braces", "{{{0}}}", [value("string", "value")]),
    case(
        "grammar-named-and-positional",
        "{0}: {name}",
        [value("string", "answer")],
        {"name": value("int", 42)},
    ),
    case("grouping-float-both", "{:,.6_f}", [value("double", 1234.56789)]),
    case("grouping-float-comma", "{:,.2f}", [value("double", 12345.5)]),
    case("grouping-float-underscore", "{:_.2f}", [value("double", 12345.5)]),
    case("grouping-int-comma", "{:,d}", [value("int", 123456789)]),
    case("grouping-int-underscore", "{:_d}", [value("int", 123456789)]),
    case("integer-X", "{:#X}", [value("int", 48879)]),
    case("integer-b", "{:#b}", [value("int", 42)]),
    case("integer-c", "{:c}", [value("int", 128512)]),
    case("integer-d", "{:+08d}", [value("int", 42)]),
    case("integer-n", "{:n}", [value("int", 1234)]),
    case("integer-o", "{:#o}", [value("int", 511)]),
    case("integer-x", "{:#x}", [value("int", 48879)]),
    case(
        "lookup-list-index",
        "{0[1]}",
        [value("list", [value("string", "zero"), value("string", "one")])],
    ),
    case(
        "lookup-map-integer-key",
        "{0[1]}",
        [
            value(
                "map",
                [{"key": value("int", 1), "value": value("string", "one")}],
            )
        ],
    ),
    case(
        "lookup-map-string-key",
        "{record[name]}",
        named={
            "record": value(
                "map",
                [
                    {
                        "key": value("string", "name"),
                        "value": value("string", "Ada"),
                    }
                ],
            )
        },
    ),
    case(
        "lookup-nested-common",
        "{0[items][0]}",
        [
            value(
                "map",
                [
                    {
                        "key": value("string", "items"),
                        "value": value("list", [value("string", "first")]),
                    }
                ],
            )
        ],
    ),
    case(
        "nested-dynamic-type",
        "{value:{type}}",
        named={"type": value("string", "x"), "value": value("int", 255)},
    ),
    case(
        "nested-width-precision",
        "{value:{width}.{precision}f}",
        named={
            "precision": value("int", 2),
            "value": value("double", 12.3456),
            "width": value("int", 10),
        },
    ),
    case("special-negative-infinity", "{:F}", [value("double", "-inf")]),
    case("special-negative-zero", "{:+.1f}", [value("double", "-0")]),
    case("special-nan", "{:F}", [value("double", "nan")]),
    case("special-positive-infinity", "{:+f}", [value("double", "inf")]),
    case("text-alignment", "{:*^9s}", [value("string", "hello")]),
    case("text-conversion-a-nonascii", "{!a}", [value("string", "é😀")]),
    case("text-conversion-r-double-large", "{!r}", [value("double", 1e20)]),
    case("text-conversion-r-double-small", "{!r}", [value("double", 1e-7)]),
    case(
        "text-conversion-r-nonprintable",
        "{!r}",
        [value("string", "\u2028\u200b\u00ad")],
    ),
    case(
        "text-conversion-r-quotes",
        "{!r}",
        [value("string", "a'''b\"c")],
    ),
    case("text-conversion-s", "{!s:.3s}", [value("string", "hello")]),
    case("text-precision-unicode", "{:.2s}", [value("string", "A😀B")]),
]


def decode(encoded: dict[str, Any]) -> Any:
    type_ = encoded["type"]
    payload = encoded["value"]
    if type_ == "null":
        if payload is not None:
            raise ValueError("null fixture payload must be null")
        return None
    if type_ == "bool":
        if type(payload) is not bool:
            raise ValueError("bool fixture payload must be a bool")
        return payload
    if type_ == "string":
        if not isinstance(payload, str):
            raise ValueError("string fixture payload must be a string")
        return payload
    if type_ == "int":
        if type(payload) is not int:
            raise ValueError("int fixture payload must be an int")
        return payload
    if type_ == "bigint":
        return int(payload)
    if type_ == "double":
        if payload == "-0":
            return -0.0
        if payload == "nan":
            return math.nan
        if payload == "inf":
            return math.inf
        if payload == "-inf":
            return -math.inf
        return float(payload)
    if type_ == "list":
        return [decode(item) for item in payload]
    if type_ == "map":
        return {decode(entry["key"]): decode(entry["value"]) for entry in payload}
    if type_ == "set":
        return {decode(item) for item in payload}
    raise ValueError(f"unknown fixture type: {type_}")


def expected_for(fixture: dict[str, Any]) -> dict[str, str]:
    positional = [decode(item) for item in fixture["positional"]]
    named = {key: decode(item) for key, item in fixture["named"].items()}
    try:
        return {"output": fixture["template"].format(*positional, **named)}
    except (ValueError, IndexError, KeyError) as error:
        return {"error": type(error).__name__}


def main(argv: list[str]) -> None:
    # An explicit output path lets a checker regenerate into a scratch
    # directory and compare, instead of writing over the committed artifact
    # and reading it back out of the working tree.
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    options = parser.parse_args(argv)
    if platform.python_implementation() != "CPython" or sys.version_info[:2] != (3, 14):
        raise SystemExit("This generator requires CPython 3.14 exactly.")
    locale.setlocale(locale.LC_ALL, "C")
    cases = []
    for source in sorted(CASES, key=lambda fixture: fixture["id"]):
        generated = dict(source)
        generated["expected"] = expected_for(source)
        cases.append(generated)
    document = {
        "generator": {"implementation": "CPython", "version": "3.14"},
        "cases": cases,
    }
    with options.output.open("w", encoding="utf-8", newline="\n") as output:
        output.write(
            json.dumps(document, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
        )


if __name__ == "__main__":
    main(sys.argv[1:])
