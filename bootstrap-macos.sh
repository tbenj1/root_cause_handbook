#!/bin/bash
set -euo pipefail

REPOSITORY_OWNER="tbenj1"
REPOSITORY_NAME="root_cause_handbook"
REPOSITORY_BRANCH="main"
POWERSHELL_API_URL="https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
MINIMUM_POWERSHELL_VERSION="7.0.0"

PORT="8000"
INSTALL_PATH=""
NO_BROWSER="false"
REINSTALL="false"
VALIDATE_ONLY="false"
FORCE_REPAIR="false"
STOP_SERVER="false"
LOCAL_RUN="false"
SKIP_POWERSHELL_UPDATE="false"
TEMP_ROOT=""
POWERSHELL_PATH=""
LATEST_VERSION=""
LATEST_ASSET_URL=""

write_step() {
  printf '[>] %s\n' "$1"
}

write_success() {
  printf '[+] %s\n' "$1"
}

write_skip() {
  printf '[-] %s\n' "$1"
}

write_warning() {
  printf '[WARNING] %s\n' "$1" >&2
}

fail() {
  printf '\n[!] Root Cause Handbook bootstrap failed.\n%s\n\n' "$1" >&2
  exit 1
}

cleanup() {
  if [[ -n "$TEMP_ROOT" && -d "$TEMP_ROOT" ]]; then
    rm -rf "$TEMP_ROOT"
  fi
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail 'This bootstrap is only for macOS.'
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-path)
      [[ $# -ge 2 ]] || fail '--install-path requires a value.'
      INSTALL_PATH="$2"
      shift 2
      ;;
    --port)
      [[ $# -ge 2 ]] || fail '--port requires a value.'
      PORT="$2"
      shift 2
      ;;
    --no-browser)
      NO_BROWSER="true"
      shift
      ;;
    --reinstall)
      REINSTALL="true"
      shift
      ;;
    --validate-only)
      VALIDATE_ONLY="true"
      shift
      ;;
    --force-repair)
      FORCE_REPAIR="true"
      shift
      ;;
    --stop-server)
      STOP_SERVER="true"
      shift
      ;;
    --local-run)
      LOCAL_RUN="true"
      shift
      ;;
    --skip-powershell-update)
      SKIP_POWERSHELL_UPDATE="true"
      shift
      ;;
    --help|-h)
      cat <<'HELP'
Root Cause Handbook macOS bootstrap

Usage:
  ./bootstrap-macos.sh [options]

Options:
  --install-path PATH          Use a custom handbook installation path.
  --port PORT                  Use a different local website port. Default: 8000.
  --no-browser                 Do not open the browser automatically.
  --reinstall                  Rebuild the managed installation and environment.
  --validate-only              Validate the website without starting it.
  --force-repair               Rebuild the local environment with --local-run.
  --stop-server                Stop the local server with --local-run.
  --local-run                  Run the local run.ps1 file beside this script.
  --skip-powershell-update     Skip the online PowerShell release check.
  --help, -h                   Show this help.

Examples:
  ./bootstrap-macos.sh
  ./bootstrap-macos.sh --local-run --validate-only --no-browser
  ./bootstrap-macos.sh --local-run --force-repair
  ./bootstrap-macos.sh --local-run --stop-server
HELP
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1024 || PORT > 65535 )); then
  fail 'The port must be between 1024 and 65535.'
fi

version_is_less_than() {
  awk -v current="$1" -v required="$2" 'BEGIN {
    split(current, a, ".")
    split(required, b, ".")
    for (i = 1; i <= 4; i++) {
      av = (a[i] == "" ? 0 : a[i] + 0)
      bv = (b[i] == "" ? 0 : b[i] + 0)
      if (av < bv) exit 0
      if (av > bv) exit 1
    }
    exit 1
  }'
}

get_pwsh_version() {
  local candidate="$1"
  local version=""

  version="$("$candidate" -NoLogo -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null | /usr/bin/head -n 1 | /usr/bin/tr -d '\r' || true)"

  case "$version" in
    ''|*'-'*) return 1 ;;
  esac

  if ! [[ "$version" =~ ^[0-9]+([.][0-9]+){1,3}$ ]]; then
    return 1
  fi

  printf '%s\n' "$version"
}

find_best_pwsh() {
  local candidate=""
  local version=""
  local best_path=""
  local best_version=""
  local command_path=""
  local candidates=""

  command_path="$(command -v pwsh 2>/dev/null || true)"
  candidates="$command_path
/usr/local/bin/pwsh
/opt/homebrew/bin/pwsh
/usr/local/microsoft/powershell/7/pwsh"

  for candidate in \
    /opt/homebrew/Cellar/powershell/*/bin/pwsh \
    /usr/local/Cellar/powershell/*/bin/pwsh; do
    if [[ -x "$candidate" ]]; then
      candidates="$candidates
$candidate"
    fi
  done

  while IFS= read -r candidate; do
    [[ -n "$candidate" && -x "$candidate" ]] || continue

    version="$(get_pwsh_version "$candidate" || true)"
    [[ -n "$version" ]] || continue

    if [[ -z "$best_version" ]] || version_is_less_than "$best_version" "$version"; then
      best_path="$candidate"
      best_version="$version"
    fi
  done <<CANDIDATES
$candidates
CANDIDATES

  [[ -n "$best_path" ]] || return 1
  printf '%s\n' "$best_path"
}

get_macos_architecture() {
  local machine=""
  local translated="0"
  local arm_capable="0"

  machine="$(uname -m)"
  translated="$(/usr/sbin/sysctl -in sysctl.proc_translated 2>/dev/null || printf '0')"
  arm_capable="$(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null || printf '0')"

  if [[ "$machine" == "arm64" || "$translated" == "1" || "$arm_capable" == "1" ]]; then
    printf 'arm64\n'
    return
  fi

  if [[ "$machine" == "x86_64" ]]; then
    printf 'x64\n'
    return
  fi

  fail "The $machine macOS architecture is not supported."
}

download_file() {
  local url="$1"
  local destination="$2"
  local description="$3"

  write_step "$description"
  /usr/bin/curl \
    --fail \
    --silent \
    --show-error \
    --location \
    --retry 3 \
    --retry-delay 2 \
    --retry-connrefused \
    --connect-timeout 15 \
    --max-time 300 \
    --header 'User-Agent: RootCauseHandbookBootstrap' \
    "$url" \
    --output "$destination"

  if [[ ! -s "$destination" ]]; then
    fail "The download completed without usable content: $url"
  fi
}

get_latest_release() {
  local release_json="$1"
  local architecture="$2"
  local expected_name=""

  write_step 'Checking the latest stable PowerShell release.'

  if ! /usr/bin/curl \
    --fail \
    --silent \
    --show-error \
    --location \
    --retry 3 \
    --retry-delay 2 \
    --retry-connrefused \
    --connect-timeout 15 \
    --max-time 120 \
    --header 'Accept: application/vnd.github+json' \
    --header 'X-GitHub-Api-Version: 2022-11-28' \
    --header 'User-Agent: RootCauseHandbookBootstrap' \
    "$POWERSHELL_API_URL" \
    --output "$release_json"; then
    write_warning 'The latest PowerShell release could not be checked.'
    return 1
  fi

  LATEST_VERSION="$(/usr/bin/plutil -extract tag_name raw -o - "$release_json" 2>/dev/null | /usr/bin/sed 's/^v//' || true)"

  if [[ -z "$LATEST_VERSION" || "$LATEST_VERSION" == *'-'* ]] || ! [[ "$LATEST_VERSION" =~ ^[0-9]+([.][0-9]+){1,3}$ ]]; then
    write_warning 'GitHub did not return a valid stable PowerShell release version.'
    return 1
  fi

  expected_name="powershell-${LATEST_VERSION}-osx-${architecture}.pkg"
  LATEST_ASSET_URL="$({
    /usr/bin/grep -Eo '"browser_download_url":[[:space:]]*"[^"]+' "$release_json" |
      /usr/bin/sed -E 's/^"browser_download_url":[[:space:]]*"//' |
      /usr/bin/grep "/${expected_name}$" |
      /usr/bin/head -n 1
  } || true)"

  if [[ -z "$LATEST_ASSET_URL" ]]; then
    write_warning "The PowerShell $LATEST_VERSION package for macOS $architecture was not found."
    return 1
  fi

  return 0
}

is_homebrew_managed() {
  local brew_path="$1"

  "$brew_path" list --formula powershell >/dev/null 2>&1 || \
    "$brew_path" list --cask powershell >/dev/null 2>&1
}

update_homebrew_powershell() {
  local brew_path="$1"

  write_step 'Updating the existing Homebrew PowerShell installation.'

  if ! "$brew_path" update; then
    write_warning 'Homebrew update did not complete.'
    return 1
  fi

  if "$brew_path" list --formula powershell >/dev/null 2>&1; then
    "$brew_path" upgrade powershell || "$brew_path" reinstall powershell
    return $?
  fi

  if "$brew_path" list --cask powershell >/dev/null 2>&1; then
    "$brew_path" upgrade --cask powershell || "$brew_path" reinstall --cask powershell
    return $?
  fi

  return 1
}

install_with_homebrew_fallback() {
  local brew_path="$1"

  write_step 'Trying Homebrew because the PowerShell release service is unavailable.'

  if ! "$brew_path" update; then
    write_warning 'Homebrew update did not complete.'
  fi

  if "$brew_path" install --cask powershell; then
    return 0
  fi

  if "$brew_path" install powershell; then
    return 0
  fi

  return 1
}

install_official_pkg() {
  local version="$1"
  local asset_url="$2"
  local package_path="$TEMP_ROOT/powershell-${version}.pkg"
  local signature_report="$TEMP_ROOT/powershell-signature.txt"

  download_file "$asset_url" "$package_path" "Downloading PowerShell $version for macOS."

  write_step 'Checking the PowerShell package signature.'
  if ! /usr/sbin/pkgutil --check-signature "$package_path" >"$signature_report" 2>&1; then
    /bin/cat "$signature_report" >&2 || true
    fail 'The downloaded PowerShell package does not have a valid macOS installer signature.'
  fi

  if ! /usr/bin/grep -qi 'Microsoft Corporation' "$signature_report"; then
    /bin/cat "$signature_report" >&2 || true
    fail 'The downloaded package was not signed by Microsoft Corporation.'
  fi

  write_step 'Installing PowerShell. macOS may ask for an administrator password.'
  /usr/bin/sudo /usr/sbin/installer -pkg "$package_path" -target /
}

verify_powershell() {
  local path="$1"
  local required_version="$2"
  local version=""

  version="$(get_pwsh_version "$path" || true)"
  if [[ -z "$version" ]] || version_is_less_than "$version" "$required_version"; then
    return 1
  fi

  printf '%s\n' "$version"
}

install_or_update_powershell() {
  local pwsh_path=""
  local current_version=""
  local architecture=""
  local release_json=""
  local brew_path=""
  local verified_version=""
  local release_available="false"

  pwsh_path="$(find_best_pwsh 2>/dev/null || true)"
  if [[ -n "$pwsh_path" ]]; then
    current_version="$(get_pwsh_version "$pwsh_path" || true)"
  fi

  if [[ "$SKIP_POWERSHELL_UPDATE" == "true" ]]; then
    if [[ -z "$pwsh_path" ]] || ! verified_version="$(verify_powershell "$pwsh_path" "$MINIMUM_POWERSHELL_VERSION")"; then
      fail 'PowerShell 7 was not found and the PowerShell update check was skipped.'
    fi

    write_skip "The PowerShell update check was skipped. Using PowerShell $verified_version."
    POWERSHELL_PATH="$pwsh_path"
    return
  fi

  architecture="$(get_macos_architecture)"
  release_json="$TEMP_ROOT/powershell-release.json"
  brew_path="$(command -v brew 2>/dev/null || true)"

  if get_latest_release "$release_json" "$architecture"; then
    release_available="true"
  fi

  if [[ "$release_available" != "true" ]]; then
    if [[ -n "$pwsh_path" ]] && verified_version="$(verify_powershell "$pwsh_path" "$MINIMUM_POWERSHELL_VERSION")"; then
      write_warning "Continuing with PowerShell $verified_version because the update check could not be completed."
      POWERSHELL_PATH="$pwsh_path"
      return
    fi

    if [[ -n "$brew_path" ]] && install_with_homebrew_fallback "$brew_path"; then
      hash -r
      pwsh_path="$(find_best_pwsh 2>/dev/null || true)"
      if [[ -n "$pwsh_path" ]] && verified_version="$(verify_powershell "$pwsh_path" "$MINIMUM_POWERSHELL_VERSION")"; then
        write_success "PowerShell $verified_version is ready."
        POWERSHELL_PATH="$pwsh_path"
        return
      fi
    fi

    fail 'PowerShell is not installed and the latest release could not be checked.'
  fi

  if [[ -n "$current_version" ]] && ! version_is_less_than "$current_version" "$LATEST_VERSION"; then
    write_skip "PowerShell $current_version is already current."
    POWERSHELL_PATH="$pwsh_path"
    return
  fi

  if [[ -n "$current_version" ]]; then
    write_step "PowerShell $current_version is installed. Updating to $LATEST_VERSION."
  else
    write_step "PowerShell is not installed. Installing $LATEST_VERSION."
  fi

  if [[ -n "$brew_path" ]] && is_homebrew_managed "$brew_path"; then
    if ! update_homebrew_powershell "$brew_path"; then
      if [[ -n "$pwsh_path" ]] && verified_version="$(verify_powershell "$pwsh_path" "$MINIMUM_POWERSHELL_VERSION")"; then
        write_warning "The Homebrew update failed. Continuing with PowerShell $verified_version."
        POWERSHELL_PATH="$pwsh_path"
        return
      fi
      fail 'The Homebrew-managed PowerShell installation could not be updated.'
    fi
  else
    install_official_pkg "$LATEST_VERSION" "$LATEST_ASSET_URL"
  fi

  hash -r
  pwsh_path="$(find_best_pwsh 2>/dev/null || true)"

  if [[ -z "$pwsh_path" ]] || ! verified_version="$(verify_powershell "$pwsh_path" "$MINIMUM_POWERSHELL_VERSION")"; then
    fail 'PowerShell was installed, but the installation could not be verified.'
  fi

  if version_is_less_than "$verified_version" "$LATEST_VERSION"; then
    if [[ -n "$brew_path" ]] && is_homebrew_managed "$brew_path"; then
      write_warning "Homebrew provided PowerShell $verified_version instead of $LATEST_VERSION. Continuing with the newest Homebrew version available."
    else
      fail "PowerShell $verified_version was installed, but $LATEST_VERSION was expected."
    fi
  fi

  write_success "PowerShell $verified_version is ready."
  POWERSHELL_PATH="$pwsh_path"
}

validate_installer_script() {
  local script_path="$1"

  if [[ ! -s "$script_path" ]]; then
    fail 'The Root Cause Handbook installer download is empty.'
  fi

  if ! /usr/bin/grep -Fq "Root Cause Handbook Setup" "$script_path" || \
     ! /usr/bin/grep -Fq "[CmdletBinding()]" "$script_path" || \
     ! /usr/bin/grep -Eq "REPOSITORY_NAME|RepositoryName" "$script_path"; then
    fail 'The downloaded file does not look like the Root Cause Handbook installer.'
  fi
}

printf '\nRoot Cause Handbook Bootstrap\n\n'
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/RootCauseHandbook.XXXXXX")"
install_or_update_powershell

NEXT_ARGS=(-Port "$PORT")

if [[ "$NO_BROWSER" == "true" ]]; then
  NEXT_ARGS+=(-NoBrowser)
fi

if [[ "$VALIDATE_ONLY" == "true" ]]; then
  NEXT_ARGS+=(-ValidateOnly)
fi

if [[ "$LOCAL_RUN" == "true" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  NEXT_SCRIPT="$SCRIPT_DIR/run.ps1"

  if [[ ! -f "$NEXT_SCRIPT" ]]; then
    fail "run.ps1 was not found at $NEXT_SCRIPT."
  fi

  if [[ "$FORCE_REPAIR" == "true" ]]; then
    NEXT_ARGS+=(-ForceRepair)
  fi

  if [[ "$STOP_SERVER" == "true" ]]; then
    NEXT_ARGS+=(-StopServer)
  fi
else
  NEXT_SCRIPT="$TEMP_ROOT/install.ps1"
  INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/${REPOSITORY_OWNER}/${REPOSITORY_NAME}/${REPOSITORY_BRANCH}/install.ps1"

  download_file "$INSTALL_SCRIPT_URL" "$NEXT_SCRIPT" 'Downloading the Root Cause Handbook installer.'
  validate_installer_script "$NEXT_SCRIPT"

  if [[ -n "$INSTALL_PATH" ]]; then
    NEXT_ARGS+=(-InstallPath "$INSTALL_PATH")
  fi

  if [[ "$REINSTALL" == "true" ]]; then
    NEXT_ARGS+=(-Reinstall)
  fi
fi

write_step 'Continuing with the Root Cause Handbook setup.'
set +e
"$POWERSHELL_PATH" -NoLogo -NoProfile -NonInteractive -File "$NEXT_SCRIPT" "${NEXT_ARGS[@]}"
NEXT_EXIT_CODE=$?
set -e
exit "$NEXT_EXIT_CODE"
