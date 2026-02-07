<?php
// Patch InstallPrerequisites.php to add a NixOS case.
//
// PR #7170 adds NixOS to SUPPORTED_OS but does NOT add a corresponding
// branch in InstallPrerequisites::handle().  Without this patch, NixOS
// passes OS validation but then falls through to:
//   throw new \Exception('Unsupported OS type for prerequisites installation');
//
// On NixOS, prerequisites (curl, git, jq, etc.) are managed declaratively
// via configuration.nix, so we just verify they exist rather than trying
// to install them imperatively.
//
// Remove this file once Coolify ships native NixOS support.

$file = '/var/www/html/app/Actions/Server/InstallPrerequisites.php';
$code = file_get_contents($file);

$search = "} else {\n            throw new \\Exception('Unsupported OS type for prerequisites installation');";

$replace = <<<'PHP'
} elseif (Str::contains($osType, 'nixos')) {
            // NixOS: prerequisites are managed declaratively via configuration.nix.
            // Just verify the essential tools exist.
            $server->executeInBackground("command -v curl && command -v git && command -v jq && echo 'NixOS: all prerequisites found' || echo 'WARNING: some prerequisites missing -- add them to environment.systemPackages'");
        } else {
            throw new \Exception('Unsupported OS type for prerequisites installation');
PHP;

$result = str_replace($search, $replace, $code);

if ($result === $code) {
    fwrite(STDERR, "ERROR: patch target not found in $file -- file may have changed\n");
    exit(1);
}

file_put_contents($file, $result);
echo "Patched $file successfully\n";
