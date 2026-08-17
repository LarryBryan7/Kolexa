// ============================================================
// Cliente API centralizado (fetch nativo).
// - Base URL desde VITE_API_URL (sin hardcodear producción).
// - Adjunta Authorization: Bearer <token>.
// - Maneja errores HTTP (401/403/404/409/400/500).
// - No repetir fetch() con lógica duplicada en cada pantalla.
// ============================================================

const API_URL = (import.meta.env.VITE_API_URL as string | undefined)?.replace(
  /\/$/,
  '',
);

if (!API_URL) {
  // En desarrollo sin .env, avisamos claramente (no asumimos producción).
  // eslint-disable-next-line no-console
  console.warn(
    '[kolexa-web-admin] VITE_API_URL no está definida. Configúrala en .env (ver .env.example).',
  );
}

export class ApiError extends Error {
  status: number;
  details?: unknown;

  constructor(status: number, message: string, details?: unknown) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.details = details;
  }
}

// Callback para manejar sesión expirada (401). Lo registra AuthContext.
let onUnauthorized: (() => void) | null = null;
export function setUnauthorizedHandler(handler: (() => void) | null) {
  onUnauthorized = handler;
}

// Token de acceso en memoria (se restaura desde localStorage al iniciar).
let accessToken: string | null = null;
export function setAccessToken(token: string | null) {
  accessToken = token;
}

interface RequestOptions {
  method?: 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE';
  body?: unknown;
  headers?: Record<string, string>;
  auth?: boolean;
}

export async function api<T = unknown>(
  path: string,
  options: RequestOptions = {},
): Promise<T> {
  const { method = 'GET', body, headers = {}, auth = true } = options;

  const finalHeaders: Record<string, string> = {
    Accept: 'application/json',
    ...headers,
  };

  if (body !== undefined) {
    finalHeaders['Content-Type'] = 'application/json';
  }

  if (auth && accessToken) {
    finalHeaders['Authorization'] = `Bearer ${accessToken}`;
  }

  const response = await fetch(`${API_URL}${path}`, {
    method,
    headers: finalHeaders,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });

  // Manejo de 401 → sesión expirada
  if (response.status === 401) {
    if (onUnauthorized) onUnauthorized();
    throw new ApiError(401, 'Tu sesión ha expirado. Vuelve a iniciar sesión.');
  }

  // Intentar parsear el cuerpo (puede ser JSON o vacío)
  let data: unknown = null;
  const contentType = response.headers.get('content-type') ?? '';
  if (contentType.includes('application/json')) {
    try {
      data = await response.json();
    } catch {
      data = null;
    }
  }

  if (!response.ok) {
    const message = extractErrorMessage(data, response.status);
    throw new ApiError(response.status, message, data);
  }

  return data as T;
}

// Extrae un mensaje legible del error del backend (NestJS).
function extractErrorMessage(data: unknown, status: number): string {
  if (data && typeof data === 'object') {
    const obj = data as Record<string, unknown>;
    if (typeof obj.message === 'string') return obj.message;
    if (Array.isArray(obj.message)) {
      // Errores de validación de class-validator (array de mensajes)
      return obj.message.join(', ');
    }
    if (typeof obj.error === 'string') return obj.error;
  }
  switch (status) {
    case 400:
      return 'Solicitud inválida. Revisa los datos ingresados.';
    case 403:
      return 'No tienes permisos para realizar esta acción.';
    case 404:
      return 'El recurso solicitado no fue encontrado.';
    case 409:
      return 'Conflicto con los datos existentes.';
    case 500:
      return 'Ocurrió un error en el servidor. Inténtalo nuevamente.';
    default:
      return 'Ocurrió un error inesperado.';
  }
}

// ── Helpers de URL ─────────────────────────────────────────
export function buildQuery(params: Record<string, string | number | undefined>): string {
  const search = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== '') search.set(key, String(value));
  });
  const qs = search.toString();
  return qs ? `?${qs}` : '';
}
