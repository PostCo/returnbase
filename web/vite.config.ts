import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) },
  },
  server: {
    host: true,
    port: 5180,
    strictPort: true,
    allowedHosts: true, // Codespaces serves the app under a forwarded hostname
    // Docker on Windows passes no file change events into containers, so bin/setup turns on polling there
    watch: process.env.WEB_WATCH_POLLING === "1" ? { usePolling: true, interval: 300 } : undefined,
    proxy: {
      "/api": { target: "http://api:3100", changeOrigin: true },
      "/admin": { target: "http://api:3100", changeOrigin: true },
    },
  },
});
