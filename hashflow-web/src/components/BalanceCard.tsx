const dummyBalance = {
  total: 120,
  withdrawable: 80,
  freeRunUntil: "2025-12-13T18:00:00Z",
};

export default function BalanceCard() {
  const freeRunActive = new Date(dummyBalance.freeRunUntil).getTime() > Date.now();
  const freeRunLabel = freeRunActive
    ? `Free-run active until ${new Date(dummyBalance.freeRunUntil).toLocaleString()}`
    : "Free-run inactive";

  return (
    <section className="rounded-2xl bg-slate-900/60 border border-slate-800 p-6 shadow-lg shadow-slate-900/40">
      <div className="flex items-center justify-between">
        <div>
          <div className="text-sm text-slate-400">Total credits</div>
          <div className="text-4xl font-semibold text-slate-50">{dummyBalance.total}</div>
        </div>
        <div>
          <div className="text-sm text-slate-400">Withdrawable</div>
          <div className="text-2xl font-semibold text-emerald-300">{dummyBalance.withdrawable}</div>
        </div>
      </div>
      <div className="mt-4 text-sm text-slate-300">{freeRunLabel}</div>
    </section>
  );
}
