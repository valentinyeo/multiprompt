def resolve_cwd(session, supplied):
    if session != "-":
        try:
            resolved = subprocess.run(["tmux", "display-message", "-p", "-t", session, "#{pane_current_path}"],
                                      capture_output=True, text=True, encoding="utf-8", timeout=0.5, check=True).stdout.strip()
            if usable_dir(resolved):
                return Path(resolved)
        except (OSError, subprocess.SubprocessError):
            pass
    return Path(supplied) if supplied != "-" and usable_dir(supplied) else HOME


