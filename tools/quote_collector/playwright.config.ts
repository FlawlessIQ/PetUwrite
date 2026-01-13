const config = {
  use: {
    headless: false,
    viewport: { width: 1280, height: 800 },
    // Tool is human-in-the-loop; keep browser visible by default.
  },
  timeout: 60_000,
};

export default config;
