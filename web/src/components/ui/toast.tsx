import { createContext, useCallback, useContext, useState, type ReactNode } from "react";
import * as ToastPrimitive from "@radix-ui/react-toast";
import { cn } from "@/lib/utils";

type ToastMessage = { id: number; title: string; variant: "default" | "error" };
type ToastFn = (title: string, variant?: ToastMessage["variant"]) => void;

const ToastContext = createContext<ToastFn>(() => {});

export function ToastProvider({ children }: { children: ReactNode }) {
  const [messages, setMessages] = useState<ToastMessage[]>([]);

  const toast = useCallback<ToastFn>((title, variant = "default") => {
    setMessages((current) => [...current, { id: Date.now() + Math.random(), title, variant }]);
  }, []);

  return (
    <ToastContext.Provider value={toast}>
      <ToastPrimitive.Provider duration={4000}>
        {children}
        {messages.map((message) => (
          <ToastPrimitive.Root
            key={message.id}
            onOpenChange={(open) => !open && setMessages((current) => current.filter((m) => m.id !== message.id))}
            className={cn(
              "rounded-[10px] px-3.5 py-2.5 text-[13px] font-medium text-white shadow-[0_8px_24px_rgb(0_0_0/0.18)]",
              message.variant === "error" ? "bg-destructive" : "bg-primary",
            )}
          >
            <ToastPrimitive.Title>{message.title}</ToastPrimitive.Title>
          </ToastPrimitive.Root>
        ))}
        <ToastPrimitive.Viewport className="fixed bottom-6 left-1/2 z-[100] flex w-96 max-w-[calc(100%-2rem)] -translate-x-1/2 flex-col gap-2 outline-hidden" />
      </ToastPrimitive.Provider>
    </ToastContext.Provider>
  );
}

export function useToast() {
  return useContext(ToastContext);
}
