"use client";

import { useEffect } from "react";
import { usePathname } from "next/navigation";
import { track } from "@/hooks/useAnalytics";

export function PageTracker() {
  const pathname = usePathname();

  useEffect(() => {
    track("page_viewed", { path: pathname });
  }, [pathname]);

  return null;
}
