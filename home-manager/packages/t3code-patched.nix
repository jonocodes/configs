# nixpkgs t3code with the OPENCODE_CONFIG_CONTENT fix applied.
#
# Bug: the t3code server hardcodes `OPENCODE_CONFIG_CONTENT: "{}"` on the
# opencode subprocess environment. In apps/server/dist/bin.mjs (v0.0.28):
#
#     env: {
#       ...input.environment,
#       OPENCODE_CONFIG_CONTENT: OPENCODE_EMPTY_CONFIG_CONTENT   // = "{}"
#     }
#
# Because the explicit key comes AFTER the spread, it clobbers any inherited
# OPENCODE_CONFIG_CONTENT. opencode then ignores ~/.config/opencode/opencode.json
# and shows no custom providers/models in the t3code UI.
#
#   Issue: https://github.com/pingdotgg/t3code/issues/4239
#   Fix PR: https://github.com/pingdotgg/t3code/pull/4242
#   (The earlier #2797 was closed as "completed" without fixing this — it was
#   a different code path. #4239 is our precise root-cause report.)
#   Once the fix (PR #4242) ships in nixpkgs-unstable: delete this file and set
#   the lute service to `package = pkgs-unstable.t3code;` (stock, unpatched).
#
# This overrides the *unwrapped* derivation's postInstall to rewrite that env
# construction so an inherited OPENCODE_CONFIG_CONTENT is respected:
#
#     ...(process.env.OPENCODE_CONFIG_CONTENT ? {} : { OPENCODE_CONFIG_CONTENT: OPENCODE_EMPTY_CONFIG_CONTENT })
#
# NOTE: the patch only makes the env var *respected*. To actually populate
# models you must ALSO export OPENCODE_CONFIG_CONTENT for the service (e.g.
# services.t3code.opencodeConfigPath pointing at your opencode.json).
#
# Overriding the unwrapped derivation forces a full local rebuild of t3code
# (including the Electron desktop build). Remove this wrapper once upstream
# fixes the bug and the fix lands in nixpkgs.
{ t3code, python3 }:

t3code.override {
  t3code-unwrapped = t3code.unwrapped.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      target="$out/libexec/t3code/apps/server/dist/bin.mjs"
      if [ -f "$target" ]; then
        echo "t3code-patched: applying OPENCODE_CONFIG_CONTENT fix (t3code#4239)"
        ${python3}/bin/python3 - "$target" <<'PYEOF'
import re, sys
path = sys.argv[1]
src = open(path).read()
pat = re.compile(
    r"env:\s*\{\s*\.\.\.input\.environment\s*,?\s*\n\s*OPENCODE_CONFIG_CONTENT:\s*OPENCODE_EMPTY_CONFIG_CONTENT\s*,?\s*\n\s*\}",
    re.MULTILINE,
)
repl = (
    "env: {\n"
    "        ...input.environment,\n"
    "        ...(process.env.OPENCODE_CONFIG_CONTENT ? {} : { OPENCODE_CONFIG_CONTENT: OPENCODE_EMPTY_CONFIG_CONTENT })\n"
    "      }"
)
new_src, n = pat.subn(repl, src)
if n == 0:
    print("t3code-patched: pattern not found — upstream may have fixed/changed it", file=sys.stderr)
    sys.exit(0)
if n > 1:
    print(f"t3code-patched: WARNING replaced {n} occurrences (expected 1)", file=sys.stderr)
open(path, "w").write(new_src)
print(f"t3code-patched: patched {n} occurrence(s)")
PYEOF
      fi
    '';
  });
}
