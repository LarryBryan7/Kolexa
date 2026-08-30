import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard,
  School,
  DoorOpen,
  BookOpen,
  Users,
  GraduationCap,
  Contact,
  CalendarClock,
  Link2,
  Upload,
  LogOut,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { useAuth } from '@/contexts/auth-context';
import { Button } from '@/components/ui/button';
import { KolexaLogo } from '@/components/kolexa-logo';

const navItems = [
  { to: '/', label: 'Dashboard', icon: LayoutDashboard, end: true },
  { to: '/institucion', label: 'Institución', icon: School, end: false },
  { to: '/aulas', label: 'Aulas', icon: DoorOpen, end: false },
  { to: '/cursos', label: 'Cursos', icon: BookOpen, end: false },
  { to: '/usuarios', label: 'Usuarios', icon: Users, end: false },
  { to: '/alumnos', label: 'Alumnos', icon: GraduationCap, end: false },
  { to: '/padres', label: 'Padres', icon: Contact, end: false },
  { to: '/horarios', label: 'Horarios', icon: CalendarClock, end: false },
  { to: '/classroom', label: 'Classroom', icon: Link2, end: false },
  { to: '/importar', label: 'Importar', icon: Upload, end: false },
];

interface SidebarProps {
  open: boolean;
  /** Se llama al tocar un ítem: en móvil cierra el menú tras navegar. */
  onNavigate: () => void;
}

export function Sidebar({ open, onNavigate }: SidebarProps) {
  const { user, logout } = useAuth();

  return (
    <aside
      className={cn(
        'flex h-full w-60 shrink-0 flex-col border-r bg-white',
        // En móvil flota sobre el contenido; en escritorio ocupa su columna.
        'fixed inset-y-0 left-0 z-50 transition-transform duration-200 lg:static lg:z-auto',
        open ? 'translate-x-0' : '-translate-x-full lg:hidden',
      )}
    >
      {/* Logo */}
      <div className="flex h-16 items-center gap-3 border-b px-5">
        <div className="kolexa-logo" aria-hidden="true">
          <KolexaLogo className="h-5 w-5" />
        </div>
        <div>
          <p className="text-base font-bold leading-tight text-foreground">KOLEXA</p>
          <p className="text-xs text-muted-foreground">Admin</p>
        </div>
      </div>

      {/* Navegación */}
      <nav className="flex-1 space-y-1 overflow-y-auto p-3" aria-label="Navegación principal">
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.end}
            onClick={onNavigate}
            className={({ isActive }) =>
              cn(
                'flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors',
                isActive
                  ? 'bg-brand-soft text-brand-dark'
                  : 'text-muted-foreground hover:bg-muted hover:text-foreground',
              )
            }
          >
            <item.icon className="h-4 w-4 shrink-0" aria-hidden="true" />
            {item.label}
          </NavLink>
        ))}
      </nav>

      {/* Usuario + logout */}
      <div className="border-t p-3">
        <div className="mb-2 flex items-center gap-3 px-2">
          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand text-sm font-semibold text-white">
            {user?.firstName?.[0]?.toUpperCase() ?? 'A'}
          </div>
          <div className="min-w-0">
            <p className="truncate text-sm font-medium text-foreground">
              {user?.firstName} {user?.lastName}
            </p>
            <p className="truncate text-xs text-muted-foreground">{user?.email}</p>
          </div>
        </div>
        <Button variant="ghost" className="w-full justify-start text-muted-foreground" onClick={logout}>
          <LogOut className="h-4 w-4" aria-hidden="true" />
          Cerrar sesión
        </Button>
      </div>
    </aside>
  );
}
