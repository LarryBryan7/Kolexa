// ============================================================
// AuthContext — autenticación de la Web Admin.
// Reutiliza el sistema de autenticación del backend (POST /auth/login).
// - login / logout
// - persistencia de sesión (localStorage)
// - handler de 401 (sesión expirada)
// - expone useAuth()
// ============================================================

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { api, setAccessToken, setUnauthorizedHandler } from '@/lib/api';
import type { AuthUser, LoginResponse } from '@/lib/types';

const TOKEN_KEY = 'kolexa_admin_token';
const USER_KEY = 'kolexa_admin_user';

interface AuthContextValue {
  user: AuthUser | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<AuthUser>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

function readStoredUser(): AuthUser | null {
  try {
    const raw = localStorage.getItem(USER_KEY);
    return raw ? (JSON.parse(raw) as AuthUser) : null;
  } catch {
    return null;
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(() => readStoredUser());
  const [isLoading, setIsLoading] = useState(false);

  // Restaurar el token al iniciar
  useEffect(() => {
    const token = localStorage.getItem(TOKEN_KEY);
    setAccessToken(token);
  }, []);

  // Handler global de 401 → cerrar sesión
  useEffect(() => {
    setUnauthorizedHandler(() => {
      logout();
    });
    return () => setUnauthorizedHandler(null);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const logout = useCallback(() => {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    setAccessToken(null);
    setUser(null);
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    setIsLoading(true);
    try {
      const res = await api<LoginResponse>('/auth/login', {
        method: 'POST',
        body: { email, password },
        auth: false,
      });

      localStorage.setItem(TOKEN_KEY, res.accessToken);
      localStorage.setItem(USER_KEY, JSON.stringify(res.user));
      setAccessToken(res.accessToken);
      setUser(res.user);
      return res.user;
    } finally {
      setIsLoading(false);
    }
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      user,
      isAuthenticated: !!user,
      isLoading,
      login,
      logout,
    }),
    [user, isLoading, login, logout],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error('useAuth debe usarse dentro de <AuthProvider>');
  }
  return ctx;
}
