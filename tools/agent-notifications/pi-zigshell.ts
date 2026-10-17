import { execFile } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";

export default function (pi: any) {
  const send = (event: string) => new Promise<void>((resolve) => {
    if (!process.env.TMUX && !process.env.ZIGSHELL_SHELL_ID) return resolve();
    const script = join(homedir(), ".local", "share", "zigshell", "notify.py");
    execFile(process.platform === "win32" ? "python" : "python3",
      [script, "pi", event, "{}"],
      { timeout: 1500, windowsHide: true, maxBuffer: 1024 }, () => resolve());
  });
  pi.on("session_start", () => send("session"));
  pi.on("agent_start", () => send("active"));
  pi.on("agent_settled", (_event: unknown, ctx: any) => {
    if (ctx.isIdle() && !ctx.hasPendingMessages()) return send("done");
  });
}
