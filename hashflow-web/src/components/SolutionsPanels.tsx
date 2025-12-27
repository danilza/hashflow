"use client";

import { useEffect, useMemo, useState } from "react";
import { env } from "@/lib/env";
import { parseAddressFromStack, normalizeTonAddress } from "@/lib/ton";

type MintedItem = {
  nftAddress: string;
  pipelineHash: string;
  metadataUri?: string;
  owner?: string;
  status?: string;
  error?: string;
};

type Solution = {
  pipeline_hash: string;
  level_id: number;
  nft_status?: string | null;
  nft_address?: string | null;
};

type MintRequestBody = {
  player_id: string;
  level_id: number;
  pipeline_hash: string;
  pipeline_length?: number;
  pipeline_raw?: unknown;
  wallet_address?: string | null;
  metadata_uri?: string | null;
};

async function callMint(body: MintRequestBody, signal?: AbortSignal): Promise<MintedItem> {
  if (!env.supabaseAnonKey) throw new Error("NEXT_PUBLIC_SUPABASE_ANON_KEY is not set");
  const res = await fetch(env.mintUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${env.supabaseAnonKey}`,
      apikey: env.supabaseAnonKey,
      ...(env.supabaseProjectRef ? { "x-supabase-project-ref": env.supabaseProjectRef } : {}),
    },
    body: JSON.stringify(body),
    signal,
  });
  const json = await res.json();
  if (!res.ok) throw new Error(json?.error || "Mint failed");
  return {
    nftAddress: json.nft_address,
    pipelineHash: body.pipeline_hash,
    metadataUri: json.metadata_uri,
    status: "minted",
  };
}

async function fetchOwner(address: string): Promise<string> {
  const rpc = env.tonRpc;
  const payload = {
    jsonrpc: "2.0",
    id: 1,
    method: "runGetMethod",
    params: { address, method: "get_nft_data", stack: [] },
  };
  const res = await fetch(rpc, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(env.tonApiKey ? { "X-API-Key": env.tonApiKey } : {}),
    },
    body: JSON.stringify(payload),
  });
  const json = await res.json();
  if (!json?.result || json.result.exit_code !== 0) {
    throw new Error(`runGetMethod failed: ${JSON.stringify(json)}`);
  }
  // stack: [index, collection, owner, content]
  const stack = json.result.stack;
  const owner = parseAddressFromStack(stack[2]);
  return normalizeTonAddress(owner);
}

export default function SolutionsPanels() {
  const [playerId, setPlayerId] = useState(env.defaultPlayerId);
  const [levelId, setLevelId] = useState(1);
  const [pipelineHash, setPipelineHash] = useState(() => randomHash());
  const [metadataUri, setMetadataUri] = useState("");
  const [walletAddress, setWalletAddress] = useState("");
  const [solutions, setSolutions] = useState<Solution[]>([]);
  const [solutionsLoading, setSolutionsLoading] = useState(false);
  const [isMinting, setIsMinting] = useState(false);
  const [minted, setMinted] = useState<MintedItem[]>([]);
  const [ownerCheckAddress, setOwnerCheckAddress] = useState("");
  const [ownerCheckResult, setOwnerCheckResult] = useState<string>("");
  const [ownerCheckLoading, setOwnerCheckLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const canMint = useMemo(() => playerId.trim().length > 0 && pipelineHash.trim().length > 0, [playerId, pipelineHash]);

  useEffect(() => {
    // автоподстановка дефолтного player_id из env при загрузке
    if (!playerId && env.defaultPlayerId) {
      setPlayerId(env.defaultPlayerId);
    }
  }, [playerId]);

  useEffect(() => {
    if (!playerId.trim()) {
      setSolutions([]);
      return;
    }
    const controller = new AbortController();
    (async () => {
      try {
        setSolutionsLoading(true);
        setError(null);
        const qs = new URLSearchParams({
          select: "pipeline_hash,level_id,nft_status,nft_address",
          player_id: `eq.${playerId.trim()}`,
        });
        const res = await fetch(`${env.supabaseUrl}/rest/v1/solutions?${qs.toString()}`, {
          headers: {
            apikey: env.supabaseAnonKey,
            Authorization: `Bearer ${env.supabaseAnonKey}`,
          },
          signal: controller.signal,
        });
        if (!res.ok) {
          const text = await res.text();
          throw new Error(text || "Failed to load solutions");
        }
        const data: Solution[] = await res.json();
        setSolutions(data);
      } catch (e: any) {
        if (controller.signal.aborted) return;
        setError(e?.message ?? String(e));
      } finally {
        setSolutionsLoading(false);
      }
    })();
    return () => controller.abort();
  }, [playerId]);

  async function handleMint(next?: { pipeline_hash?: string; level_id?: number }) {
    setIsMinting(true);
    setError(null);
    try {
      const resolvedPipelineHash = (next?.pipeline_hash ?? pipelineHash).trim();
      const resolvedLevelId = Number(next?.level_id ?? levelId);
      const body: MintRequestBody = {
        player_id: playerId.trim(),
        level_id: resolvedLevelId,
        pipeline_hash: resolvedPipelineHash,
        metadata_uri: metadataUri.trim() || null,
        wallet_address: walletAddress.trim() || null,
      };
      const mintedItem = await callMint(body);
      setMinted((prev) => [mintedItem, ...prev]);
      setPipelineHash(randomHash()); // prepare next unique hash
      // update solutions list
      setSolutions((prev) =>
        prev.map((s) =>
          s.pipeline_hash === body.pipeline_hash
            ? { ...s, nft_status: "minted", nft_address: mintedItem.nftAddress }
            : s
        )
      );
    } catch (e: any) {
      setError(e?.message ?? String(e));
    } finally {
      setIsMinting(false);
    }
  }

  async function handleOwnerCheck(addr: string) {
    setOwnerCheckLoading(true);
    setOwnerCheckResult("");
    setError(null);
    try {
      const owner = await fetchOwner(normalizeTonAddress(addr.trim()));
      setOwnerCheckResult(owner);
    } catch (e: any) {
      setError(e?.message ?? String(e));
    } finally {
      setOwnerCheckLoading(false);
    }
  }

  async function refreshMintedOwner(item: MintedItem) {
    try {
      const owner = await fetchOwner(item.nftAddress);
      setMinted((prev) =>
        prev.map((m) => (m.nftAddress === item.nftAddress ? { ...m, owner } : m))
      );
    } catch (e: any) {
      setError(e?.message ?? String(e));
    }
  }

  return (
    <div className="space-y-4">
      <Panel
        title="Выберите игрока"
        hint="Введите player_id, чтобы загрузить решения из Supabase (по умолчанию берётся из env)"
      >
        <div className="flex flex-col gap-2 md:flex-row md:items-center">
          <input
            className="w-full rounded bg-slate-900 border border-slate-800 px-3 py-2 text-sm"
            value={playerId}
            onChange={(e) => setPlayerId(e.target.value)}
            placeholder="player_id (uuid)"
          />
          {solutionsLoading && <span className="text-xs text-slate-400">Loading solutions...</span>}
        </div>
        {solutions.length > 0 && (
          <div className="text-xs text-slate-400 mt-2">
            Загружено решений: {solutions.length}. Выберите одно и нажмите Mint.
          </div>
        )}
      </Panel>

      <Panel title="Список решений" hint="данные из Supabase/solutions">
        {solutions.length === 0 && <div className="text-sm text-slate-500">Нет данных. Введите player_id.</div>}
        <div className="space-y-2">
          {solutions.map((s) => (
            <Card key={s.pipeline_hash}>
              <div className="space-y-1">
                <div className="text-sm text-slate-200 break-all">hash: {s.pipeline_hash}</div>
                <div className="text-xs text-slate-500">level: {s.level_id}</div>
                {s.nft_status && <div className="text-xs text-slate-400">status: {s.nft_status}</div>}
                {s.nft_address && <div className="text-xs text-emerald-300 break-all">nft: {s.nft_address}</div>}
              </div>
              <button
                className="px-3 py-1 rounded bg-emerald-500 text-slate-900 text-sm disabled:opacity-50"
                onClick={() => {
                  setPipelineHash(s.pipeline_hash);
                  setLevelId(s.level_id);
                  handleMint({ pipeline_hash: s.pipeline_hash, level_id: s.level_id });
                }}
                disabled={isMinting || s.nft_status === "minted"}
              >
                {isMinting && pipelineHash === s.pipeline_hash ? "Minting..." : s.nft_status === "minted" ? "Minted" : "Mint"}
              </button>
            </Card>
          ))}
        </div>
      </Panel>

      <Panel
        title="Mint NFT via Supabase function"
        hint="Заполните player_id и pipeline_hash (обычно выбирается из списка выше)"
      >
        <div className="grid md:grid-cols-2 gap-3">
          <Field label="player_id">
            <input
              className="w-full rounded bg-slate-900 border border-slate-800 px-3 py-2 text-sm"
              value={playerId}
              onChange={(e) => setPlayerId(e.target.value)}
              placeholder="uuid из БД"
            />
          </Field>
          <Field label="level_id">
            <input
              type="number"
              className="w-full rounded bg-slate-900 border border-slate-800 px-3 py-2 text-sm"
              value={levelId}
              min={1}
              onChange={(e) => setLevelId(Number(e.target.value))}
            />
          </Field>
          <Field label="pipeline_hash">
            <input
              className="w-full rounded bg-slate-900 border border-slate-800 px-3 py-2 text-sm"
              value={pipelineHash}
              onChange={(e) => setPipelineHash(e.target.value)}
            />
          </Field>
          <Field label="metadata_uri (optional)">
            <input
              className="w-full rounded bg-slate-900 border border-slate-800 px-3 py-2 text-sm"
              value={metadataUri}
              onChange={(e) => setMetadataUri(e.target.value)}
              placeholder="по умолчанию BASE/pipeline_hash.json"
            />
          </Field>
          <Field label="wallet_address (optional)">
            <input
              className="w-full rounded bg-slate-900 border border-slate-800 px-3 py-2 text-sm"
              value={walletAddress}
              onChange={(e) => setWalletAddress(e.target.value)}
              placeholder="TON адрес, если нужно перезаписать wallet из профиля"
            />
          </Field>
        </div>
        <div className="flex items-center gap-3 mt-3">
          <button
            onClick={handleMint}
            disabled={!canMint || isMinting}
            className="rounded bg-emerald-500 text-slate-900 px-4 py-2 text-sm font-semibold disabled:opacity-50"
          >
            {isMinting ? "Minting..." : "Mint"}
          </button>
          {error && <span className="text-sm text-rose-300">{error}</span>}
        </div>
      </Panel>

      <Panel title="Minted NFTs" hint="обнови владельца при открытии/refresh">
        {minted.length === 0 && <div className="text-sm text-slate-500">Пока нет минтов в этой сессии.</div>}
        <div className="space-y-2">
          {minted.map((item) => (
            <Card key={item.nftAddress}>
              <div className="space-y-1">
                <div className="text-sm text-slate-200 break-all">{item.nftAddress}</div>
                <div className="text-xs text-slate-500 break-all">hash: {item.pipelineHash}</div>
                {item.metadataUri && <div className="text-xs text-slate-500 break-all">meta: {item.metadataUri}</div>}
                {item.owner && <div className="text-xs text-emerald-300 break-all">owner: {item.owner}</div>}
              </div>
              <button
                className="px-3 py-1 rounded bg-sky-500 text-slate-900 text-sm"
                onClick={() => refreshMintedOwner(item)}
              >
                Refresh owner
              </button>
            </Card>
          ))}
        </div>
      </Panel>

      <Panel title="Check NFT owner" hint="runGetMethod get_nft_data">
        <div className="flex flex-col gap-2 md:flex-row md:items-center">
          <input
            className="w-full rounded bg-slate-900 border border-slate-800 px-3 py-2 text-sm"
            value={ownerCheckAddress}
            onChange={(e) => setOwnerCheckAddress(e.target.value)}
            placeholder="EQ..."
          />
          <button
            className="px-4 py-2 rounded bg-indigo-500 text-slate-900 text-sm font-semibold disabled:opacity-50"
            onClick={() => handleOwnerCheck(ownerCheckAddress)}
            disabled={ownerCheckLoading || ownerCheckAddress.trim().length === 0}
          >
            {ownerCheckLoading ? "Loading..." : "Check"}
          </button>
        </div>
        {ownerCheckResult && (
          <div className="text-sm text-emerald-300 break-all">owner: {ownerCheckResult}</div>
        )}
      </Panel>
    </div>
  );
}

function Panel({ title, hint, children }: { title: string; hint?: string; children: React.ReactNode }) {
  return (
    <section className="rounded-2xl bg-slate-900/60 border border-slate-800 p-4 shadow-lg shadow-slate-900/30">
      <div className="flex items-center justify-between mb-3">
        <h2 className="text-lg font-semibold text-slate-100">{title}</h2>
        {hint && <span className="text-xs text-slate-500">{hint}</span>}
      </div>
      <div className="space-y-3">{children}</div>
    </section>
  );
}

function Card({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-3 rounded-xl border border-slate-800 bg-slate-950/50 px-4 py-3">
      {children}
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="flex flex-col gap-1 text-sm text-slate-200">
      <span className="text-xs text-slate-400">{label}</span>
      {children}
    </label>
  );
}

function randomHash() {
  return `client-${Math.random().toString(36).slice(2, 10)}`;
}
