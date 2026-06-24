import type { Metadata } from "next";
import { PaymentExperience } from "@/components/app/AppPortal";

export const metadata: Metadata = {
  title: "Payment"
};

export default function PaymentPage() {
  return <PaymentExperience />;
}
