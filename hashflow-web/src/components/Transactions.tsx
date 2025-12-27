const dummyTx = [
  { id: "1", amount: +20, type: "bonus", source: "daily_refill", created_at: "2025-12-12T08:00:00Z" },
  { id: "2", amount: -3, type: "bonus", source: "run_cost", created_at: "2025-12-12T09:10:00Z" },
  { id: "3", amount: +50, type: "paid", source: "crypto", created_at: "2025-12-11T20:00:00Z" },
  { id: "4", amount: +10, type: "earned", source: "sale", created_at: "2025-12-11T19:00:00Z" },
];

const typeColor: Record<string, string> = {
  bonus: "text-sky-300",
  earned: "text-emerald-300",
  paid: "text-amber-300",
};

export default function Transactions() {
  return (
    <section className="rounded-2xl bg-slate-900/60 border border-slate-800 p-6 shadow-lg shadow-slate-900/40">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-lg font-semibold text-slate-100">Transactions</h2>
        <span className="text-xs text-slate-400">History (dummy data)</span>
      </div>
      <div className="divide-y divide-slate-800">
        {dummyTx.map((tx) => (
          <div key={tx.id} className="flex items-center justify-between py-3">
            <div>
              <div className="text-sm text-slate-200">{tx.source}</div>
              <div className="text-xs text-slate-500">
                {new Date(tx.created_at).toLocaleString()} • {tx.type}
              </div>
            </div>
            <div className={`text-base font-semibold ${tx.amount >= 0 ? "text-emerald-400" : "text-rose-400"}`}>
              {tx.amount > 0 ? "+" : ""}
              {tx.amount}
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
