import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import App from "./App";
import { ToastProvider } from "@/components/ui/toast";
import { SessionProvider } from "@/lib/session";
import "./index.css";
import { ShopperApp } from "./shopper/ShopperApp";

const isShopper = window.location.pathname.startsWith("/shopper");
if (!isShopper) document.body.classList.add("rb-app");

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    {isShopper ? (
      <ShopperApp />
    ) : (
      <BrowserRouter>
        <SessionProvider>
          <ToastProvider>
            <App />
          </ToastProvider>
        </SessionProvider>
      </BrowserRouter>
    )}
  </StrictMode>,
);
