import { describe, expect, it } from "vitest";

describe("Supabase connection", () => {
  it("responds from the configured Auth endpoint", async () => {
    const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
    const key = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;
    if (!url || !key) return;
    const response = await fetch(`${url}/auth/v1/settings`, { headers: { apikey: key } });
    expect(response.ok).toBe(true);
  }, 20000);

  it("uses the expected public project URL and anon key", () => {
    const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
    const key = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;
    expect(url === undefined || /^https:\/\/[^/]+\.supabase\.co$/.test(url)).toBe(true);
    expect(key === undefined || key.length > 40).toBe(true);
    expect(key === undefined || !key.includes("service_role")).toBe(true);
  });
});
