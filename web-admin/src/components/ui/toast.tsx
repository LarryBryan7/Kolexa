// ============================================================
// Sistema de notificaciones (toast) ligero de la Web Admin.
// Sin dependencias externas: usa un contexto + portal propio.
// API: useToast() → { toast({ title, description, variant }) }
// ============================================================

import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { CheckCircle2, AlertCircle, Info, X } from 'lucide-react';
import { cn } from '@/lib/utils';

type ToastVariant = 'success' | 'error' | 'info';

interface ToastItem {
  id: number;
  title: string;
  description?: string;
  variant: ToastVariant;
}

interface ToastContextValue {
  toast: (opts: { title: string; description?: string; variant?: ToastVariant }) => void;
}

const ToastContext = createContext<ToastContextValue | undefined>(undefined);

let nextId = 1;

const variantStyles: Record<ToastVariant, { icon: ReactNode; classes: string }> = {
  success: {
    icon: <CheckCircle2 className="h-5 w-5 text-success" />,
    classes: 'border-success/30',
  },
  error: {
    icon: <AlertCircle className="h-5 w-5 text-destructive" />,
    classes: 'border-destructive/30',
  },
  info: {
    icon: <Info className="h-5 w-5 text-brand" />,
    classes: 'border-brand/30',
  },
};

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<ToastItem[]>([]);

  const dismiss = useCallback((id: number) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const toast = useCallback(
    (opts: { title: string; description?: string; variant?: ToastVariant }) => {
      const id = nextId++;
      const item: ToastItem = {
        id,
        title: opts.title,
        description: opts.description,
        variant: opts.variant ?? 'info',
      };
      setToasts((prev) => [...prev, item]);
      // Auto-dismiss después de 4.5s
      window.setTimeout(() => dismiss(id), 4500);
    },
    [dismiss],
  );

  const value = useMemo(() => ({ toast }), [toast]);

  return (
    <ToastContext.Provider value={value}>
      {children}
      {/* Portal de toasts */}
      <div
        aria-live="polite"
        aria-atomic="true"
        className="pointer-events-none fixed bottom-4 right-4 z-[100] flex w-full max-w-sm flex-col gap-2"
      >
        {toasts.map((t) => {
          const v = variantStyles[t.variant];
          return (
            <div
              key={t.id}
              role="status"
              className={cn(
                'pointer-events-auto flex items-start gap-3 rounded-lg border bg-background p-4 shadow-lg animate-in slide-in-from-bottom-2 fade-in',
                v.classes,
              )}
            >
              <div className="mt-0.5 shrink-0">{v.icon}</div>
              <div className="flex-1">
                <p className="text-sm font-semibold">{t.title}</p>
                {t.description && (
                  <p className="mt-0.5 text-sm text-muted-foreground">{t.description}</p>
                )}
              </div>
              <button
                type="button"
                onClick={() => dismiss(t.id)}
                className="shrink-0 rounded-sm p-1 text-muted-foreground transition-colors hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                aria-label="Cerrar notificación"
              >
                <X className="h-4 w-4" />
              </button>
            </div>
          );
        })}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast(): ToastContextValue {
  const ctx = useContext(ToastContext);
  if (!ctx) {
    throw new Error('useToast debe usarse dentro de <ToastProvider>');
  }
  return ctx;
}
