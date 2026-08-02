from __future__ import annotations

import re
import stat
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
ERRORS: list[str] = []
WARNINGS: list[str] = []


def fail(message: str) -> None:
    ERRORS.append(message)


def warn(message: str) -> None:
    WARNINGS.append(message)


def require_file(relative: str, marker: str | None = None) -> Path:
    path = ROOT / relative
    if not path.is_file():
        fail(f"Missing required file: {relative}")
        return path
    if marker is not None:
        text = path.read_text(encoding="utf-8", errors="replace")
        if marker not in text:
            fail(f"Required marker {marker!r} was not found in {relative}")
    return path


def check_required_files() -> None:
    required = {
        "mkdocs.yml": "site_name: The Root Cause Handbook",
        "requirements.lock.txt": "mkdocs==",
        "run.ps1": "Root Cause Handbook local launcher",
        "install.ps1": "Root Cause Handbook installer",
        "bootstrap-windows.ps1": "Root Cause Handbook Windows bootstrap",
        "bootstrap-macos.sh": "Root Cause Handbook macOS bootstrap",
        "docs.cmd": "bootstrap-windows.ps1",
        "docs.command": "bootstrap-macos.sh",
        "docs/assets/health.txt": "root-cause-handbook-health-v1",
        "docs/help.md": "# Setup and Help",
    }
    for relative, marker in required.items():
        require_file(relative, marker)


def check_generated_content_is_absent() -> None:
    for relative in (".venv", ".runtime", "site", ".lockenv"):
        if (ROOT / relative).exists():
            fail(f"Generated or runtime content must not be packaged: {relative}")
    for path in ROOT.rglob("__pycache__"):
        if path.is_dir():
            fail(f"Python cache must not be packaged: {path.relative_to(ROOT)}")
    for pattern in ("*.pyc", "*.pyo"):
        for path in ROOT.rglob(pattern):
            if path.is_file():
                fail(f"Compiled Python file must not be packaged: {path.relative_to(ROOT)}")


def check_removed_content_is_absent() -> None:
    removed = (
        ".python-version",
        "requirements.in",
        "FUNCTIONAL_AUDIT.md",
        "docs/assets/images/README.txt",
    )
    for relative in removed:
        if (ROOT / relative).exists():
            fail(f"Removed project content must not be packaged: {relative}")


def check_requirements() -> None:
    path = ROOT / "requirements.lock.txt"
    if not path.is_file():
        return
    seen: set[str] = set()
    for line_number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.strip()
        if not line:
            continue
        if line.startswith("#"):
            fail(f"requirements.lock.txt:{line_number} contains a comment")
            continue
        if "==" not in line:
            fail(f"requirements.lock.txt:{line_number} is not exactly pinned: {line}")
            continue
        package, version = line.split("==", 1)
        key = package.strip().lower().replace("_", "-")
        if not package.strip() or not version.strip():
            fail(f"requirements.lock.txt:{line_number} has an incomplete pin")
        if key in seen:
            fail(f"requirements.lock.txt contains a duplicate package: {package.strip()}")
        seen.add(key)
    for required in ("mkdocs", "mkdocs-material"):
        if required not in seen:
            fail(f"requirements.lock.txt is missing {required}")


def check_repository_constants() -> None:
    checks = {
        "bootstrap-macos.sh": (
            'REPOSITORY_OWNER="tbenj1"',
            'REPOSITORY_NAME="root_cause_handbook"',
            'REPOSITORY_BRANCH="main"',
        ),
        "bootstrap-windows.ps1": ("tbenj1", "root_cause_handbook", "main"),
        "install.ps1": ("tbenj1", "root_cause_handbook", "main"),
    }
    for relative, markers in checks.items():
        path = ROOT / relative
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for marker in markers:
            if marker not in text:
                fail(f"Repository setting {marker!r} is missing from {relative}")


def markdown_targets(path: Path) -> list[tuple[int, str]]:
    targets: list[tuple[int, str]] = []
    in_fence = False
    fence_char = ""
    for line_number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), start=1):
        stripped = line.lstrip()
        fence_match = re.match(r"(```+|~~~+)", stripped)
        if fence_match:
            token = fence_match.group(1)
            char = token[0]
            if not in_fence:
                in_fence = True
                fence_char = char
            elif char == fence_char:
                in_fence = False
                fence_char = ""
            continue
        if in_fence:
            continue
        for match in re.finditer(r"(?<!!)\[[^\]]*\]\(([^)]+)\)", line):
            target = match.group(1).strip()
            if target.startswith("<") and target.endswith(">"):
                target = target[1:-1]
            target = target.split(maxsplit=1)[0].strip('"\'')
            targets.append((line_number, target))
    return targets


def check_markdown_links() -> None:
    if not DOCS.is_dir():
        fail("The docs directory is missing")
        return
    for path in sorted(DOCS.rglob("*.md")):
        text = path.read_text(encoding="utf-8", errors="replace")
        if "¶" in text:
            fail(f"Pilcrow character found in {path.relative_to(ROOT)}")
        for line_number, target in markdown_targets(path):
            parsed = urlsplit(target)
            if parsed.scheme or parsed.netloc or target.startswith(("mailto:", "tel:", "#")):
                continue
            target_path = unquote(parsed.path)
            if not target_path:
                continue
            resolved = (path.parent / target_path).resolve()
            try:
                resolved.relative_to(ROOT.resolve())
            except ValueError:
                fail(f"{path.relative_to(ROOT)}:{line_number} points outside the project: {target}")
                continue
            candidates = [resolved]
            if resolved.suffix == "":
                candidates.extend([resolved.with_suffix(".md"), resolved / "index.md"])
            if not any(candidate.exists() for candidate in candidates):
                fail(f"Broken local link in {path.relative_to(ROOT)}:{line_number}: {target}")


def check_navigation() -> None:
    config = ROOT / "mkdocs.yml"
    if not config.is_file():
        return
    text = config.read_text(encoding="utf-8", errors="replace")
    if re.search(r"permalink:\s*true", text, re.IGNORECASE):
        fail("mkdocs.yml enables heading permalinks")
    nav_paths = re.findall(r"^\s*-\s+[^:\n]+:\s*([^\s#]+\.md)\s*$", text, re.MULTILINE)
    if not nav_paths:
        fail("No Markdown navigation entries were found in mkdocs.yml")
        return
    nav_set: set[Path] = set()
    for raw in nav_paths:
        relative = Path(raw.strip().strip('"\''))
        nav_set.add(relative)
        if not (DOCS / relative).is_file():
            fail(f"Navigation references a missing page: {relative.as_posix()}")
    documented = {path.relative_to(DOCS) for path in DOCS.rglob("*.md")}
    for missing in sorted(documented - nav_set - {Path("404.md")}):
        warn(f"Markdown page is not listed in navigation: {missing.as_posix()}")


def check_script_permissions() -> None:
    if sys.platform == "win32":
        return
    if sys.platform != "darwin":
        fail("The project audit only runs on Windows or macOS")
        return
    for relative in ("bootstrap-macos.sh", "docs.command"):
        path = ROOT / relative
        if path.is_file() and not (path.stat().st_mode & stat.S_IXUSR):
            fail(f"macOS launcher is not executable: {relative}")


def check_asset_references() -> None:
    source_files = [
        ROOT / "mkdocs.yml",
        ROOT / "README.md",
        ROOT / "run.ps1",
        ROOT / "install.ps1",
        *DOCS.rglob("*.md"),
        *DOCS.rglob("*.css"),
        *DOCS.rglob("*.js"),
        *(ROOT / "overrides").rglob("*.html"),
    ]
    corpus = "\n".join(
        path.read_text(encoding="utf-8", errors="replace")
        for path in source_files
        if path.is_file()
    )
    for path in sorted(DOCS.rglob("*")):
        if not path.is_file() or path.suffix.lower() == ".md":
            continue
        relative = path.relative_to(DOCS).as_posix()
        if relative not in corpus and path.name not in corpus:
            fail(f"Website asset appears unused: docs/{relative}")


def check_workflow_scope() -> None:
    path = ROOT / ".github" / "workflows" / "documentation_check.yml"
    if not path.is_file():
        fail("The Windows and macOS validation workflow is missing")
        return
    text = path.read_text(encoding="utf-8", errors="replace")
    for marker in ("windows-latest", "macos-latest", "if ($IsWindows)"):
        if marker not in text:
            fail(f"Workflow marker {marker!r} is missing")


def check_health_contract() -> None:
    marker = "root-cause-handbook-health-v1"
    run_script = ROOT / "run.ps1"
    health_file = DOCS / "assets" / "health.txt"
    if run_script.is_file() and marker not in run_script.read_text(encoding="utf-8", errors="replace"):
        fail("run.ps1 does not contain the expected health-check marker")
    if health_file.is_file() and health_file.read_text(encoding="utf-8").strip() != marker:
        fail("docs/assets/health.txt does not exactly match the health-check marker")


def check_xml_assets() -> None:
    for path in sorted(DOCS.rglob("*.svg")):
        try:
            ET.parse(path)
        except ET.ParseError as exc:
            fail(f"Invalid SVG XML in {path.relative_to(ROOT)}: {exc}")


def check_no_obvious_placeholders() -> None:
    patterns = ("YOUR_GITHUB", "REPLACE_ME", "example/repository")
    for relative in ("README.md", "bootstrap-macos.sh", "bootstrap-windows.ps1", "install.ps1", "run.ps1"):
        path = ROOT / relative
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for pattern in patterns:
            if pattern in text:
                fail(f"Placeholder {pattern!r} remains in {relative}")


def check_help_and_audience() -> None:
    help_markers = {
        "README.md": ("## Help", "Help and Setup"),
        "bootstrap-windows.ps1": ("[switch]$Help", "Root Cause Handbook Windows bootstrap"),
        "install.ps1": ("[switch]$Help", "Root Cause Handbook installer"),
        "run.ps1": ("[switch]$Help", "Root Cause Handbook local launcher"),
        "bootstrap-macos.sh": ("--help|-h", "Root Cause Handbook macOS bootstrap"),
        "docs/help.md": ("# Setup and Help", "## Show Command Help"),
    }
    for relative, markers in help_markers.items():
        path = ROOT / relative
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for marker in markers:
            if marker not in text:
                fail(f"Help marker {marker!r} is missing from {relative}")
    audience_patterns = {
        r"\bL1\b": "L1",
        r"\bLevel\s+1\b": "Level 1",
        r"\bentry[- ]level technicians?\b": "entry-level technician",
    }
    for path in sorted([ROOT / "README.md", *DOCS.rglob("*.md")]):
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for pattern, label in audience_patterns.items():
            if re.search(pattern, text, re.IGNORECASE):
                fail(f"Audience-limiting wording {label!r} remains in {path.relative_to(ROOT)}")


def check_supported_platform_scope() -> None:
    unsupported = "lin" + "ux"
    patterns = {
        rf"\b{unsupported}\b": "Unsupported platform reference",
        r"\$Is" + unsupported: "Unsupported PowerShell platform branch",
        r"OSPlatform[^\n]*" + unsupported: "Unsupported OS platform check",
        r"unknown-" + unsupported: "Unsupported release asset",
        unsupported + r"-(?:gnu|musl)": "Unsupported runtime asset",
        r"\b" + "xdg" + "-open\b": "Unsupported browser launcher",
        r"\b" + "system" + "ctl\b": "Unsupported service command",
        r"\b" + "a" + "pt(?:-get)?\b": "Unsupported package command",
        r"\b" + "d" + "nf\b": "Unsupported package command",
        r"\b" + "y" + "um\b": "Unsupported package command",
    }
    suffixes = {".ps1", ".sh", ".command", ".cmd", ".py", ".js", ".css", ".yml", ".yaml", ".md", ".html", ".txt"}
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in suffixes:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for pattern, label in patterns.items():
            if re.search(pattern, text, re.IGNORECASE):
                fail(f"{label} found in {path.relative_to(ROOT)}")


def check_no_source_comments() -> None:
    checks = {
        ".ps1": (r"<#", r"(?m)^\s*#"),
        ".py": (r"(?m)^\s*#",),
        ".js": (r"/\*", r"(?m)^\s*//"),
        ".css": (r"/\*",),
        ".yml": (r"(?m)^\s*#",),
        ".yaml": (r"(?m)^\s*#",),
        ".html": (r"<!--",),
    }
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file():
            continue
        patterns = checks.get(path.suffix.lower())
        if patterns:
            text = path.read_text(encoding="utf-8", errors="replace")
            for pattern in patterns:
                if re.search(pattern, text):
                    fail(f"Source comment found in {path.relative_to(ROOT)}")
                    break
    gitignore = ROOT / ".gitignore"
    if gitignore.is_file() and re.search(r"(?m)^\s*#", gitignore.read_text(encoding="utf-8", errors="replace")):
        fail("Source comment found in .gitignore")
    for relative in ("bootstrap-macos.sh", "docs.command"):
        path = ROOT / relative
        if not path.is_file():
            continue
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        for line_number, line in enumerate(lines, start=1):
            if line.lstrip().startswith("#") and not (line_number == 1 and line.startswith("#!")):
                fail(f"Source comment found in {relative}:{line_number}")


def check_obvious_unused_functions() -> None:
    definitions: list[tuple[Path, str]] = []
    for relative in ("run.ps1", "install.ps1", "bootstrap-windows.ps1"):
        path = ROOT / relative
        if path.is_file():
            text = path.read_text(encoding="utf-8", errors="replace")
            for name in re.findall(r"(?mi)^function\s+([A-Za-z][A-Za-z0-9-]*)\s*\{", text):
                definitions.append((path, name))
    shell_path = ROOT / "bootstrap-macos.sh"
    if shell_path.is_file():
        text = shell_path.read_text(encoding="utf-8", errors="replace")
        for name in re.findall(r"(?m)^([A-Za-z_][A-Za-z0-9_]*)\(\)\s*\{", text):
            definitions.append((shell_path, name))
    js_path = DOCS / "javascripts" / "extra.js"
    if js_path.is_file():
        text = js_path.read_text(encoding="utf-8", errors="replace")
        for name in re.findall(r"function\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*\(", text):
            definitions.append((js_path, name))
    py_path = ROOT / "tools" / "project_audit.py"
    if py_path.is_file():
        text = py_path.read_text(encoding="utf-8", errors="replace")
        for name in re.findall(r"(?m)^def\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", text):
            definitions.append((py_path, name))
    for path, name in definitions:
        text = path.read_text(encoding="utf-8", errors="replace")
        if len(re.findall(rf"(?<![A-Za-z0-9_-]){re.escape(name)}(?![A-Za-z0-9_-])", text)) < 2:
            fail(f"Function appears unused in {path.relative_to(ROOT)}: {name}")


def main() -> int:
    checks = (
        check_required_files,
        check_generated_content_is_absent,
        check_removed_content_is_absent,
        check_requirements,
        check_repository_constants,
        check_markdown_links,
        check_navigation,
        check_script_permissions,
        check_asset_references,
        check_workflow_scope,
        check_health_contract,
        check_xml_assets,
        check_no_obvious_placeholders,
        check_help_and_audience,
        check_supported_platform_scope,
        check_no_source_comments,
        check_obvious_unused_functions,
    )
    for check in checks:
        check()
    for message in WARNINGS:
        print(f"[WARNING] {message}")
    if ERRORS:
        for message in ERRORS:
            print(f"[ERROR] {message}", file=sys.stderr)
        print(f"\nAudit failed with {len(ERRORS)} error(s).", file=sys.stderr)
        return 1
    print(f"Audit passed with {len(WARNINGS)} warning(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
