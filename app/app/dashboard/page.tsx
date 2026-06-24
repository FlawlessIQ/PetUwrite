import type { Metadata } from "next";
import { CustomerDashboard } from "@/components/app/AppPortal";

export const metadata: Metadata = {
  title: "Policy dashboard"
};

export default function DashboardPage() {
  return <CustomerDashboard />;
}
