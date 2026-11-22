# Historical compiler regression

`bad.zig` extracts the affected paint branch from `src/changelog.zig` at 0489191435e256906c0ca188219fc2d5dce8ad00. `fixed.zig` extracts the same branch at 8b650619ab96a3c509d576a6044725684b4a812e. Each is wrapped in a standalone generic function with its external names supplied as parameters, so `zig ast-check` can check the extracted branch.
