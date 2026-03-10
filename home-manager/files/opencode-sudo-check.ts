import type { Plugin } from "@opencode-ai/plugin"

export const SudoCheck: Plugin = async ({ $ }) => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") return
      if (!/\bsudo\b/.test(output.args.command)) return

      // Check if sudo credentials are cached
      try {
        await $`sudo -n true 2>/dev/null`
        return
      } catch {}

      // Poll for up to 30 seconds waiting for the user to run sudo -v
      console.error(
        "Sudo credentials not cached. Run 'sudo -v' in another terminal. Waiting up to 30s...",
      )
      for (let i = 0; i < 30; i++) {
        await new Promise((r) => setTimeout(r, 1000))
        try {
          await $`sudo -n true 2>/dev/null`
          return
        } catch {}
      }

      throw new Error(
        "Sudo credentials not cached. Timed out after 30s. Please run sudo -v in another terminal.",
      )
    },
  }
}
