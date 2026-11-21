export async function pooled(items, limit, worker) {
  const results = new Array(items.length);
  let next = 0;
  const run = async () => {
    while (next < items.length) {
      const index = next;
      next += 1;
      results[index] = await worker(items[index], index);
    }
  };
  const runners = [];
  for (let index = 0; index < Math.max(1, Math.min(limit, items.length)); index += 1) runners.push(run());
  await Promise.all(runners);
  return results;
}
