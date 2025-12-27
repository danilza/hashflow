import BalanceCard from "@/components/BalanceCard";
import Transactions from "@/components/Transactions";
import SolutionsPanels from "@/components/SolutionsPanels";

export default function Home() {
  return (
    <main className="space-y-8">
      <BalanceCard />
      <SolutionsPanels />
      <Transactions />
    </main>
  );
}
