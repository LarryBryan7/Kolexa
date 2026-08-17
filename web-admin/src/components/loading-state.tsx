import { Loader2 } from 'lucide-react';

interface LoadingStateProps {
  label?: string;
}

export function LoadingState({ label = 'Cargando…' }: LoadingStateProps) {
  return (
    <div
      role="status"
      aria-live="polite"
      className="flex flex-col items-center justify-center gap-3 py-16 text-muted-foreground"
    >
      <Loader2 className="h-8 w-8 animate-spin text-brand" />
      <p className="text-sm">{label}</p>
    </div>
  );
}
