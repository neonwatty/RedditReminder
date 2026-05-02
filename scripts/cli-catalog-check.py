#!/usr/bin/env python3
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path


def fail(message):
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def parser_routes(repo_root):
    invocation = repo_root / "CLI" / "Sources" / "CLIInvocation.swift"
    source = invocation.read_text()
    matches = re.findall(r'case \("([^"]+)", "([^"]+)"\):', source)
    if not matches:
        fail("no parser routes found in CLIInvocation.swift")
    return {f"{domain}.{command}" for domain, command in matches}


def command_catalog(cli):
    with tempfile.TemporaryDirectory() as tmpdir:
        store = str(Path(tmpdir) / "redditreminder-cli.store")
        result = subprocess.run(
            [cli, "--json", "--store", store, "commands", "list"],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    if result.returncode != 0:
        fail(f"commands list failed: {result.stderr.strip()}")
    payload = json.loads(result.stdout)
    if not payload.get("ok"):
        fail("commands list returned ok=false")
    return payload["data"]


def validate_catalog(cli, catalog):
    ids = [command["id"] for command in catalog]
    duplicates = sorted({command_id for command_id in ids if ids.count(command_id) > 1})
    if duplicates:
        fail(f"duplicate command catalog ids: {', '.join(duplicates)}")

    for command in catalog:
        command_id = command["id"]
        expected_id = f'{command["domain"]}.{command["command"]}'
        if command_id != expected_id:
            fail(f"{command_id} domain/command mismatch: expected {expected_id}")
        for field in ("summary", "examples", "output"):
            if not command.get(field):
                fail(f"{command_id} missing {field}")
        shown = subprocess.run(
            [cli, "--json", "commands", "show", command_id],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if shown.returncode != 0:
            fail(f"commands show failed for {command_id}: {shown.stderr.strip()}")
        payload = json.loads(shown.stdout)
        if payload.get("data", {}).get("id") != command_id:
            fail(f"commands show returned wrong id for {command_id}")


def main():
    if len(sys.argv) != 2:
        fail("usage: cli-catalog-check.py PATH_TO_REDDITREMINDER_CLI")

    cli = sys.argv[1]
    repo_root = Path(__file__).resolve().parents[1]
    routes = parser_routes(repo_root)
    catalog = command_catalog(cli)
    validate_catalog(cli, catalog)
    catalog_ids = {command["id"] for command in catalog}

    missing = sorted(routes - catalog_ids)
    extra = sorted(catalog_ids - routes)
    if missing or extra:
        details = []
        if missing:
            details.append(f"missing catalog ids: {', '.join(missing)}")
        if extra:
            details.append(f"catalog ids without parser routes: {', '.join(extra)}")
        fail("; ".join(details))

    print(f"CLI command catalog covers {len(routes)} parser routes")


if __name__ == "__main__":
    main()
