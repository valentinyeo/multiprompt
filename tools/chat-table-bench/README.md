# Chat table build cost

`Chat table bench` runs only on GitHub Windows. A standalone ReleaseSmall executable builds against each checkout's own production sources; neither revision's build.zig is replaced or read by the benchmark build. Preparation appends one fixed public alias for the private production layout entry and copies the standalone entry file into src. No source tail or normal test module is copied. Later render declarations and build steps are preserved.

Each executable warms 500 builds, then measures 20,000 builds of the same nine-cell table with real GDI fonts. QueryPerformanceCounter brackets the production layout entry, including parsing, allocation, measurement, font restoration and its normal diagnostics. Cache clearing is outside the interval; font metrics remain warm. The standalone entry checks the resulting grid dimensions. The normal suite instead runs a two-call production cache correctness test.

Seven independent paired samples alternate before/after order on one runner. The standing regression guard permits at most 10% slower median per-build cost, with at least six of seven paired samples also within 10%. Equal or faster revisions pass. The 10% margin exceeds the recorded seven-sample relative ranges (8.615% before, 3.723% after); the original >=20% improvement proof is recorded PR evidence, not a requirement for future changes. There is no absolute wall-time cutoff. The artifact retains revision identities, build logs, raw counter receipts and summary.json. This compares native Windows table builds, not Wine timing or tab-switch first-paint latency.

`node --test tools/chat-table-bench/bench.test.js` runs lightweight architecture, preparation and comparison controls without launching any compiler, app or subprocess.
