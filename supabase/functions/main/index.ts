// main – minimaler Function-Dispatcher für den self-hosted Stack.
//
// Ersetzt den mitgelieferten Router, der `jsr:@panva/jose` importiert:
// unser Server hat kein IPv4-Internet, Modul-Downloads (jsr.io/esm.sh)
// schlagen beim Kaltstart fehl → 502 für ALLE Functions. Dieser Dispatcher
// kommt ohne externe Imports aus. Gateway-seitige JWT-Verifikation entfällt
// (VERIFY_JWT ist im Stack ohnehin false) — die Functions selbst prüfen
// Identität und Rolle (siehe admin-users).
//
// Original liegt auf dem Server als main/index.ts.orig — kann nach einer
// IPv4-Freigabe zurückgetauscht werden.

console.log("main function started (offline dispatcher)");

// deno-lint-ignore no-explicit-any
declare const EdgeRuntime: any;

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const service = url.pathname.split("/").filter(Boolean)[0];
  if (!service || service === "main") {
    return new Response(
      JSON.stringify({ error: "function name missing in path" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }
  try {
    const worker = await EdgeRuntime.userWorkers.create({
      servicePath: `/home/deno/functions/${service}`,
      memoryLimitMb: 150,
      workerTimeoutMs: 60_000,
      envVars: Object.entries(Deno.env.toObject()),
    });
    return await worker.fetch(req);
  } catch (e) {
    console.error(`worker for "${service}" failed:`, e);
    return new Response(
      JSON.stringify({ error: `function "${service}" not available` }),
      { status: 503, headers: { "Content-Type": "application/json" } },
    );
  }
});
