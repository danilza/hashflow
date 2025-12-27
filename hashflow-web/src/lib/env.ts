export const env = {
  supabaseUrl:
    process.env.NEXT_PUBLIC_SUPABASE_URL || "https://mspqeumqitcomagyorvw.supabase.co",
  supabaseAnonKey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "",
  defaultPlayerId: process.env.NEXT_PUBLIC_DEFAULT_PLAYER_ID || "",
  supabaseProjectRef:
    process.env.NEXT_PUBLIC_SUPABASE_PROJECT_REF || "mspqeumqitcomagyorvw",
  mintUrl:
    process.env.NEXT_PUBLIC_MINT_URL ||
    "https://mspqeumqitcomagyorvw.functions.supabase.co/mint_nft",
  tonRpc: process.env.NEXT_PUBLIC_TON_RPC || "https://testnet.toncenter.com/api/v2/jsonRPC",
  tonApiKey: process.env.NEXT_PUBLIC_TON_API_KEY || "",
};

export function requireEnv(key: keyof typeof env) {
  const val = env[key];
  if (!val) throw new Error(`Missing env ${key} (set NEXT_PUBLIC_${key.toUpperCase()})`);
  return val;
}
