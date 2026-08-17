import { useEffect, useRef, useState } from 'react';
import { Search, X } from 'lucide-react';
import { cn } from '@/lib/utils';

interface SearchInputProps {
  placeholder: string;
  value: string;
  onValueChange: (value: string) => void;
  className?: string;
}

/**
 * Campo de búsqueda con debounce.
 *
 * Mantiene su propio valor local (lo que escribe el usuario) y, tras ~300 ms
 * de inactividad, propaga el término hacia arriba mediante `onValueChange`.
 * Así se separa la entrada del usuario del valor usado por la query de
 * TanStack Query, evitando una petición por cada tecla.
 */
export function SearchInput({ placeholder, value, onValueChange, className }: SearchInputProps) {
  const [localValue, setLocalValue] = useState(value);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Sincroniza el valor local cuando el valor controlado cambia desde fuera
  // (p. ej. al limpiar el campo desde el botón).
  useEffect(() => {
    setLocalValue(value);
  }, [value]);

  useEffect(() => {
    return () => {
      if (timerRef.current) clearTimeout(timerRef.current);
    };
  }, []);

  const handleChange = (next: string) => {
    setLocalValue(next);
    if (timerRef.current) clearTimeout(timerRef.current);
    timerRef.current = setTimeout(() => {
      onValueChange(next);
    }, 300);
  };

  const handleClear = () => {
    if (timerRef.current) clearTimeout(timerRef.current);
    setLocalValue('');
    onValueChange('');
  };

  return (
    <div className={cn('relative', className)}>
      <Search
        className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground"
        aria-hidden="true"
      />
      <input
        type="text"
        value={localValue}
        onChange={(e) => handleChange(e.target.value)}
        placeholder={placeholder}
        className="h-10 w-full rounded-md border border-input bg-background pl-9 pr-9 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
      />
      {localValue && (
        <button
          type="button"
          onClick={handleClear}
          aria-label="Limpiar búsqueda"
          className="absolute right-2 top-1/2 -translate-y-1/2 rounded-full p-1 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
        >
          <X className="h-4 w-4" />
        </button>
      )}
    </div>
  );
}
