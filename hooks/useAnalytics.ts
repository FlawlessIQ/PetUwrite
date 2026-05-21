"use client";

export type AnalyticsProperties = Record<string, unknown>;

declare global {
  interface Window {
    analytics?: {
      track: (event: string, props?: AnalyticsProperties) => void;
    };
  }
}

export const track = (event: string, props?: AnalyticsProperties) => {
  if (typeof window !== "undefined" && window.analytics) {
    window.analytics.track(event, props);
  }
  console.log("[Analytics]", event, props);
};
