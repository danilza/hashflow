import { Address, Cell } from "@ton/core";

function b64ToBytes(b64: string): Uint8Array {
  if (typeof atob !== "function") {
    // Next.js edge polyfill should exist, but guard for SSR (should not be used server-side)
    throw new Error("Base64 decode not available");
  }
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

export function parseAddressFromStack(item: any): string {
  if (!item || !item[1]) throw new Error("Empty stack item");
  const payload = item[1];
  const raw =
    (typeof payload === "string" && payload) ||
    payload.bytes ||
    payload.cell?.bytes ||
    payload.slice?.bytes;
  if (!raw) throw new Error("No base64 payload in stack item");
  const cell = Cell.fromBoc(b64ToBytes(raw))[0];
  const slice = cell.beginParse();
  const addr: Address | null = slice.loadMaybeAddress();
  if (!addr) throw new Error("Address not found in cell");
  return addr.toString();
}

export function normalizeTonAddress(addr: string): string {
  return Address.parse(addr).toString({ bounceable: true, urlSafe: true });
}
