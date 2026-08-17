import { useCallback, useMemo, useRef, useState } from 'react';
import {
  Upload,
  FileText,
  CheckCircle2,
  AlertCircle,
  Clock,
  FileSpreadsheet,
  FileDown,
  Loader2,
  X,
  RefreshCw,
  Download,
} from 'lucide-react';
import { PageHeader } from '@/components/page-header';
import { Button } from '@/components/ui/button';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { StatusBadge } from '@/components/status-badge';
import { ConfirmDialog } from '@/components/confirm-dialog';
import { useToast } from '@/components/ui/toast';
import { useImportPreview, useImportConfirm } from '@/hooks/use-import';
import type { ImportPreview, ImportRowStatus } from '@/lib/types';
import {
  IMPORT_CONFIG,
  ImportFileError,
  type ImportType,
  type ImportUiState,
  type ParseResult,
} from '@/lib/import';
import { validateFile, validateParseResult } from '@/lib/import';
import { parseImportFile } from '@/lib/import';
import { resultToCsv } from '@/lib/import';
import { downloadExcelTemplate, downloadCsvTemplate } from '@/lib/import';

const statusLabel: Record<ImportRowStatus, string> = {
  creada: 'Creada',
  error: 'Error',
  requiere_confirmacion: 'Requiere confirmación',
};

const statusVariant: Record<ImportRowStatus, 'active' | 'error' | 'pending'> = {
  creada: 'active',
  error: 'error',
  requiere_confirmacion: 'pending',
};

/** Campos clave que se muestran en el detalle de cada fila, por tipo de importación. */
const ROW_SUMMARY_FIELDS: Record<ImportType, { label: string; key: string }[]> = {
  classrooms: [
    { label: 'Aula', key: 'nombre' },
    { label: 'Grado', key: 'grado' },
    { label: 'Sección', key: 'seccion' },
    { label: 'Año', key: 'año' },
    { label: 'Sede', key: 'sede' },
  ],
  courses: [
    { label: 'Curso', key: 'nombre' },
    { label: 'Código', key: 'codigo' },
  ],
  teachers: [
    { label: 'Email', key: 'email' },
    { label: 'Nombre', key: 'nombre' },
    { label: 'Apellido', key: 'apellido' },
    { label: 'DNI', key: 'dni' },
    { label: 'Teléfono', key: 'telefono' },
  ],
  students: [
    { label: 'Nombre', key: 'nombre' },
    { label: 'Apellido', key: 'apellido' },
    { label: 'DNI', key: 'dni' },
    { label: 'Código', key: 'codigo' },
    { label: 'Aula', key: 'aula' },
    { label: 'Año', key: 'año' },
    { label: 'Email padre', key: 'emailpadre' },
  ],
};

/** Construye un resumen legible de una fila a partir de sus valores del archivo. */
function rowSummary(type: ImportType, values: Record<string, string>): string {
  return ROW_SUMMARY_FIELDS[type]
    .map((f) => {
      const v = (values[f.key] ?? values[f.key.replace('año', 'anio')] ?? '').trim();
      return v ? `${f.label}: ${v}` : null;
    })
    .filter(Boolean)
    .join(' · ');
}

function ImportSection({ type }: { type: ImportType }) {
  const config = IMPORT_CONFIG[type];
  const { toast } = useToast();
  const previewMutation = useImportPreview();
  const confirmMutation = useImportConfirm();

  const fileInputRef = useRef<HTMLInputElement>(null);

  const [state, setState] = useState<ImportUiState>('idle');
  const [dragging, setDragging] = useState(false);
  const [fileName, setFileName] = useState('');
  const [parseResult, setParseResult] = useState<ParseResult | null>(null);
  const [preview, setPreview] = useState<ImportPreview | null>(null);
  const [errorMessage, setErrorMessage] = useState('');
  const [confirmOpen, setConfirmOpen] = useState(false);

  const reset = useCallback(() => {
    setState('idle');
    setFileName('');
    setParseResult(null);
    setPreview(null);
    setErrorMessage('');
    if (fileInputRef.current) fileInputRef.current.value = '';
  }, []);

  const handleError = useCallback(
    (err: unknown) => {
      if (err instanceof ImportFileError) {
        setErrorMessage(err.message);
      } else if (err instanceof Error) {
        setErrorMessage(err.message);
      } else {
        setErrorMessage('Ocurrió un error inesperado al procesar el archivo.');
      }
      setState('error');
    },
    [],
  );

  /** Llama al backend para obtener la vista previa (validación de negocio). */
  const runPreview = useCallback(
    async (result: ParseResult) => {
      setState('processing');
      try {
        const csv = resultToCsv(result, type);
        const res = await previewMutation.mutateAsync({ type, csv });
        setPreview(res);
        setState('preview');
      } catch (err) {
        handleError(err);
      }
    },
    [type, previewMutation, handleError],
  );

  /** Procesa un archivo (Excel o CSV) seleccionado/arrastrado. */
  const processFile = useCallback(
    async (file: File) => {
      try {
        validateFile(file, type);
        setState('reading');
        setFileName(file.name);
        setErrorMessage('');
        // Pequeño retardo para que el estado "reading" se renderice.
        await new Promise((r) => setTimeout(r, 50));
        const result = await parseImportFile(file, type);
        validateParseResult(result, type);
        setParseResult(result);
        // Vista previa automática: llama al backend sin esperar un clic.
        await runPreview(result);
      } catch (err) {
        handleError(err);
      }
    },
    [type, handleError, runPreview],
  );

  const handleFileInput = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) void processFile(file);
  };

  const handleDrop = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setDragging(false);
    const file = e.dataTransfer.files?.[0];
    if (file) void processFile(file);
  };

  const handleConfirm = async () => {
    if (!parseResult || !preview) return;
    setState('confirming');
    try {
      const csv = resultToCsv(parseResult, type);
      const res = await confirmMutation.mutateAsync({ type, csv });
      setPreview(res);
      setConfirmOpen(false);
      setState('success');
      toast({
        title: 'Importación completada',
        description: `${res.creadas} creadas, ${res.errores} con error.`,
        variant: res.errores > 0 ? 'info' : 'success',
      });
    } catch (err) {
      handleError(err);
      setState('preview');
    }
  };

  const canConfirm = preview && preview.creadas > 0;

  // Número máximo de filas que se muestran en el detalle de la vista previa.
  // Se mantiene bajo para que el botón de confirmación quede accesible sin scroll excesivo.
  const PREVIEW_MAX_ROWS = 20;

  // Mapa fila → valores del archivo original, para mostrar el detalle de cada fila.
  const rowValues = useMemo(() => {
    const map = new Map<number, Record<string, string>>();
    parseResult?.rows.forEach((r) => map.set(r.row, r.values));
    return map;
  }, [parseResult]);

  return (
    <div className="space-y-6">
      {/* ── Zona de subida / selección ─────────────────────── */}
      {(state === 'idle' || state === 'dragging' || state === 'error') && (
        <div className="space-y-5">
          <div
            role="button"
            tabIndex={0}
            onClick={() => fileInputRef.current?.click()}
            onKeyDown={(e) => {
              if (e.key === 'Enter' || e.key === ' ') fileInputRef.current?.click();
            }}
            onDragOver={(e) => {
              e.preventDefault();
              setDragging(true);
            }}
            onDragLeave={() => setDragging(false)}
            onDrop={handleDrop}
            className={`flex cursor-pointer flex-col items-center justify-center rounded-xl border-2 border-dashed px-6 py-12 text-center transition-colors ${
              dragging
                ? 'border-brand bg-brand-soft'
                : 'border-muted-foreground/30 bg-white hover:border-brand hover:bg-brand-soft/40'
            }`}
          >
            <div className="mb-3 flex h-14 w-14 items-center justify-center rounded-full bg-brand-soft text-brand">
              <Upload className="h-7 w-7" aria-hidden="true" />
            </div>
            <p className="text-sm font-semibold text-foreground">
              {dragging ? 'Suelta el archivo aquí' : 'Arrastra tu archivo aquí'}
            </p>
            <p className="mt-1 text-sm text-muted-foreground">
              o <span className="font-medium text-brand">Selecciona un archivo</span>
            </p>
            <p className="mt-3 text-xs text-muted-foreground">
              Formatos: <span className="font-medium">Excel (.xlsx, .xls)</span> o{' '}
              <span className="font-medium">CSV (.csv)</span> · Máx.{' '}
              {Math.round(config.maxFileSize / (1024 * 1024))} MB
            </p>
            <input
              ref={fileInputRef}
              type="file"
              accept=".xlsx,.xls,.csv"
              className="hidden"
              onChange={handleFileInput}
            />
          </div>

          {state === 'error' && (
            <div className="flex items-start gap-3 rounded-lg border border-destructive/30 bg-destructive/5 p-4">
              <AlertCircle className="mt-0.5 h-5 w-5 shrink-0 text-destructive" aria-hidden="true" />
              <div className="min-w-0 flex-1">
                <p className="text-sm font-semibold text-destructive">No se pudo procesar</p>
                <p className="mt-0.5 text-sm text-muted-foreground">{errorMessage}</p>
              </div>
              <Button variant="ghost" size="sm" onClick={reset}>
                <RefreshCw className="h-4 w-4" aria-hidden="true" />
                Reintentar
              </Button>
            </div>
          )}

          {/* ── Plantillas ────────────────────────────────── */}
          <div className="rounded-lg border bg-white p-5">
            <div className="mb-3 flex items-center gap-2">
              <FileDown className="h-5 w-5 text-brand" aria-hidden="true" />
              <div>
                <p className="text-sm font-semibold">Descargar plantilla</p>
                <p className="text-xs text-muted-foreground">
                  Usa la plantilla para asegurar el formato correcto de las columnas.
                </p>
              </div>
            </div>
            <div className="flex flex-wrap gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => void downloadExcelTemplate(type)}
              >
                <FileSpreadsheet className="h-4 w-4" aria-hidden="true" />
                Plantilla Excel (.xlsx)
              </Button>
              <Button variant="outline" size="sm" onClick={() => downloadCsvTemplate(type)}>
                <FileText className="h-4 w-4" aria-hidden="true" />
                Plantilla CSV (.csv)
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* ── Leyendo / procesando ─────────────────────────── */}
      {(state === 'reading' || state === 'processing') && (
        <div className="flex flex-col items-center justify-center rounded-xl border bg-white px-6 py-16 text-center">
          <Loader2 className="h-10 w-10 animate-spin text-brand" aria-hidden="true" />
          <p className="mt-4 text-sm font-semibold">
            {state === 'reading' ? 'Leyendo archivo…' : 'Procesando con el servidor…'}
          </p>
          <p className="mt-1 text-xs text-muted-foreground">
            {state === 'reading' ? fileName : 'Validando duplicados y datos de negocio'}
          </p>
        </div>
      )}

      {/* ── Vista previa ─────────────────────────────────── */}
      {(state === 'preview' || state === 'confirming' || state === 'success') && parseResult && (
        <div className="space-y-4">
          {/* Barra de archivo seleccionado */}
          <div className="flex items-center justify-between rounded-lg border bg-white p-4">
            <div className="flex min-w-0 items-center gap-3">
              <FileSpreadsheet className="h-6 w-6 shrink-0 text-brand" aria-hidden="true" />
              <div className="min-w-0">
                <p className="truncate text-sm font-semibold">{fileName}</p>
                <p className="text-xs text-muted-foreground">
                  {parseResult.rows.length} fila(s) de datos · {parseResult.headers.length} columna(s)
                </p>
              </div>
            </div>
            <Button variant="ghost" size="sm" onClick={reset} disabled={state === 'confirming'}>
              <X className="h-4 w-4" aria-hidden="true" />
              Cambiar
            </Button>
          </div>

          {/* Resumen de la vista previa del backend */}
          {preview && (
            <div className="grid grid-cols-3 gap-4">
              <div className="rounded-lg border bg-white p-4 text-center">
                <p className="text-2xl font-bold text-success">{preview.creadas}</p>
                <p className="text-sm text-muted-foreground">Creadas</p>
              </div>
              <div className="rounded-lg border bg-white p-4 text-center">
                <p className="text-2xl font-bold text-warning">{preview.requiereConfirmacion}</p>
                <p className="text-sm text-muted-foreground">Requieren confirmación</p>
              </div>
              <div className="rounded-lg border bg-white p-4 text-center">
                <p className="text-2xl font-bold text-destructive">{preview.errores}</p>
                <p className="text-sm text-muted-foreground">Con error</p>
              </div>
            </div>
          )}

          {/* Resultado por fila */}
          {preview && (
            <div className="rounded-lg border bg-white">
              <div className="flex items-center justify-between border-b px-4 py-3">
                <p className="text-sm font-semibold">Resultado por fila</p>
                {preview.rows.length > PREVIEW_MAX_ROWS && (
                  <p className="text-xs text-muted-foreground">
                    Mostrando {PREVIEW_MAX_ROWS} de {preview.rows.length} filas
                  </p>
                )}
              </div>
              <ul className="max-h-80 divide-y overflow-y-auto">
                {preview.rows.slice(0, PREVIEW_MAX_ROWS).map((row) => {
                  const values = rowValues.get(row.row);
                  const summary = values ? rowSummary(type, values) : '';
                  return (
                    <li key={row.row} className="flex items-start gap-3 px-4 py-3">
                      <span className="mt-0.5 shrink-0">
                        {row.status === 'creada' && (
                          <CheckCircle2 className="h-4 w-4 text-success" aria-hidden="true" />
                        )}
                        {row.status === 'error' && (
                          <AlertCircle className="h-4 w-4 text-destructive" aria-hidden="true" />
                        )}
                        {row.status === 'requiere_confirmacion' && (
                          <Clock className="h-4 w-4 text-warning" aria-hidden="true" />
                        )}
                      </span>
                      <div className="min-w-0 flex-1">
                        <p className="text-sm">
                          <span className="font-medium">Fila {row.row}:</span> {row.message}
                        </p>
                        {summary && (
                          <p className="mt-0.5 truncate text-xs text-muted-foreground" title={summary}>
                            {summary}
                          </p>
                        )}
                      </div>
                      <StatusBadge status={statusVariant[row.status]} label={statusLabel[row.status]} />
                    </li>
                  );
                })}
              </ul>
            </div>
          )}

          {/* Acciones */}
          {state !== 'success' && (
            <div className="flex flex-wrap justify-end gap-2">
              {preview && canConfirm && (
                <Button onClick={() => setConfirmOpen(true)} disabled={confirmMutation.isPending}>
                  <CheckCircle2 className="h-4 w-4" aria-hidden="true" />
                  {confirmMutation.isPending ? 'Confirmando…' : 'Confirmar importación'}
                </Button>
              )}
              {preview && !canConfirm && (
                <p className="text-sm text-muted-foreground">
                  No hay filas válidas para confirmar.
                </p>
              )}
            </div>
          )}

          {/* Éxito */}
          {state === 'success' && preview && (
            <div className="flex items-center gap-3 rounded-lg border border-success/30 bg-success/5 p-4">
              <CheckCircle2 className="h-5 w-5 shrink-0 text-success" aria-hidden="true" />
              <div className="min-w-0 flex-1">
                <p className="text-sm font-semibold text-success">Importación finalizada</p>
                <p className="text-sm text-muted-foreground">
                  {preview.creadas} creadas, {preview.requiereConfirmacion} pendientes,{' '}
                  {preview.errores} con error.
                </p>
              </div>
              <Button variant="outline" size="sm" onClick={reset}>
                <Download className="h-4 w-4" aria-hidden="true" />
                Nueva importación
              </Button>
            </div>
          )}
        </div>
      )}

      <ConfirmDialog
        open={confirmOpen}
        onOpenChange={setConfirmOpen}
        title="¿Confirmar importación?"
        description={`Se crearán ${preview?.creadas ?? 0} registros. Las filas con error o que requieren confirmación no se crearán.`}
        confirmLabel="Confirmar"
        loading={confirmMutation.isPending}
        onConfirm={handleConfirm}
      />
    </div>
  );
}

export function ImportarPage() {
  return (
    <div className="space-y-6">
      <PageHeader
        title="Importación masiva"
        description="Carga aulas, cursos, docentes o alumnos desde Excel o CSV. Revisa la vista previa y confirma solo las filas válidas."
      />

      <Tabs defaultValue="classrooms">
        <TabsList>
          <TabsTrigger value="classrooms">Aulas</TabsTrigger>
          <TabsTrigger value="courses">Cursos</TabsTrigger>
          <TabsTrigger value="teachers">Docentes</TabsTrigger>
          <TabsTrigger value="students">Alumnos</TabsTrigger>
        </TabsList>
        <TabsContent value="classrooms">
          <ImportSection type="classrooms" />
        </TabsContent>
        <TabsContent value="courses">
          <ImportSection type="courses" />
        </TabsContent>
        <TabsContent value="teachers">
          <ImportSection type="teachers" />
        </TabsContent>
        <TabsContent value="students">
          <ImportSection type="students" />
        </TabsContent>
      </Tabs>
    </div>
  );
}
