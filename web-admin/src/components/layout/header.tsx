import { Menu, X } from 'lucide-react';
import { useAuth } from '@/contexts/auth-context';

interface HeaderProps {
  sidebarOpen: boolean;
  onToggleSidebar: () => void;
}

export function Header({ sidebarOpen, onToggleSidebar }: HeaderProps) {
  const { user } = useAuth();
  const schoolName = user?.roles?.find((r) => r.schoolName)?.schoolName;

  return (
    <header className="flex h-16 shrink-0 items-center justify-between border-b bg-white px-4 sm:px-6">
      <div className="flex min-w-0 items-center gap-3">
        <button
          type="button"
          onClick={onToggleSidebar}
          aria-label={sidebarOpen ? 'Ocultar menú' : 'Mostrar menú'}
          aria-expanded={sidebarOpen}
          className="-ml-1 rounded-md p-2 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        >
          {sidebarOpen ? (
            <X className="h-5 w-5" aria-hidden="true" />
          ) : (
            <Menu className="h-5 w-5" aria-hidden="true" />
          )}
        </button>
        <div className="min-w-0">
          <p className="text-sm text-muted-foreground">Panel de administración</p>
          {schoolName && (
            <p className="truncate text-sm font-semibold text-foreground">{schoolName}</p>
          )}
        </div>
      </div>
      <div className="flex items-center gap-3">
        <span className="hidden text-sm text-muted-foreground sm:inline">
          {new Date().toLocaleDateString('es-PE', {
            weekday: 'long',
            year: 'numeric',
            month: 'long',
            day: 'numeric',
          })}
        </span>
      </div>
    </header>
  );
}
