import type { Metadata } from "next";
import { SignInExperience } from "@/components/app/AppPortal";

export const metadata: Metadata = {
  title: "Sign in"
};

export default function SignInPage() {
  return <SignInExperience />;
}
