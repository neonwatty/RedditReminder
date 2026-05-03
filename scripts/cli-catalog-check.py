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


def cli_json(cli, arguments):
    with tempfile.TemporaryDirectory() as tmpdir:
        store = str(Path(tmpdir) / "redditreminder-cli.store")
        result = subprocess.run(
            [cli, "--json", "--store", store, *arguments],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    if result.returncode != 0:
        fail(f"{' '.join(arguments)} failed: {result.stderr.strip()}")
    payload = json.loads(result.stdout)
    if not payload.get("ok"):
        fail(f"{' '.join(arguments)} returned ok=false")
    return payload


def command_catalog(cli):
    return cli_json(cli, ["commands", "list"])["data"]


def recipe_catalog(cli):
    return cli_json(cli, ["recipes", "list"])["data"]


def validate_bootstrap(cli, command_ids):
    bootstrap = cli_json(cli, ["agent", "bootstrap"])["data"]
    if bootstrap.get("schemaVersion") != 2:
        fail("agent bootstrap missing schemaVersion 2")
    if bootstrap.get("toolName") != "redditreminder":
        fail("agent bootstrap returned wrong toolName")
    discovery = set(bootstrap.get("discoveryCommands", []))
    unknown = sorted(discovery - command_ids)
    if unknown:
        fail(f"agent bootstrap references unknown commands: {', '.join(unknown)}")
    schema_ids = {command.get("id") for command in bootstrap.get("commandSchemas", [])}
    if schema_ids != command_ids:
        missing = sorted(command_ids - schema_ids)
        extra = sorted(schema_ids - command_ids)
        fail(f"agent bootstrap commandSchemas mismatch: missing={missing} extra={extra}")
    recipe_schemas = bootstrap.get("recipeSchemas", [])
    if not recipe_schemas:
        fail("agent bootstrap missing recipeSchemas")
    if "AGENTS.md" not in bootstrap.get("docs", []):
        fail("agent bootstrap docs must include AGENTS.md")


def validate_catalog(cli, catalog):
    ids = [command["id"] for command in catalog]
    duplicates = sorted({command_id for command_id in ids if ids.count(command_id) > 1})
    if duplicates:
        fail(f"duplicate command catalog ids: {', '.join(duplicates)}")

    for command in catalog:
        command_id = command["id"]
        if command.get("schemaVersion") != 1:
            fail(f"{command_id} missing schemaVersion 1")
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


def validate_recipes(cli, recipes, command_ids):
    ids = [recipe["id"] for recipe in recipes]
    duplicates = sorted({recipe_id for recipe_id in ids if ids.count(recipe_id) > 1})
    if duplicates:
        fail(f"duplicate recipe ids: {', '.join(duplicates)}")

    for recipe in recipes:
        recipe_id = recipe["id"]
        if recipe.get("schemaVersion") != 1:
            fail(f"{recipe_id} missing schemaVersion 1")
        for field in ("summary", "goal", "inputs", "steps", "examples", "relatedCommands"):
            if not recipe.get(field):
                fail(f"{recipe_id} missing {field}")
        shown = cli_json(cli, ["recipes", "show", recipe_id])
        if shown.get("data", {}).get("id") != recipe_id:
            fail(f"recipes show returned wrong id for {recipe_id}")
        related = set(recipe["relatedCommands"])
        step_commands = {step["commandId"] for step in recipe["steps"]}
        unknown = sorted((related | step_commands) - command_ids)
        if unknown:
            fail(f"{recipe_id} references unknown commands: {', '.join(unknown)}")

    search = cli_json(cli, ["recipes", "search", "--query", "media"])
    search_ids = {recipe["id"] for recipe in search["data"]}
    if "posting.create-with-media" not in search_ids:
        fail("recipes search did not return posting.create-with-media for media")
    dry_run_search = cli_json(cli, ["recipes", "search", "--query", "dry-run"])
    dry_run_ids = {recipe["id"] for recipe in dry_run_search["data"]}
    expected_dry_run_ids = {
        "posting.create-with-media-dry-run",
        "subreddit.configure-peak-times-dry-run",
        "project.archive-dry-run",
    }
    missing_dry_run_ids = sorted(expected_dry_run_ids - dry_run_ids)
    if missing_dry_run_ids:
        fail(f"recipes search missing dry-run recipes: {', '.join(missing_dry_run_ids)}")


def main():
    if len(sys.argv) != 2:
        fail("usage: cli-catalog-check.py PATH_TO_REDDITREMINDER_CLI")

    cli = sys.argv[1]
    repo_root = Path(__file__).resolve().parents[1]
    routes = parser_routes(repo_root)
    catalog = command_catalog(cli)
    validate_catalog(cli, catalog)
    catalog_ids = {command["id"] for command in catalog}
    validate_bootstrap(cli, catalog_ids)
    recipes = recipe_catalog(cli)
    validate_recipes(cli, recipes, catalog_ids)

    missing = sorted(routes - catalog_ids)
    extra = sorted(catalog_ids - routes)
    if missing or extra:
        details = []
        if missing:
            details.append(f"missing catalog ids: {', '.join(missing)}")
        if extra:
            details.append(f"catalog ids without parser routes: {', '.join(extra)}")
        fail("; ".join(details))

    print(f"CLI command catalog covers {len(routes)} parser routes and {len(recipes)} recipes")


if __name__ == "__main__":
    main()
