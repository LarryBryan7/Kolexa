// ============================================================
// staleness_guard.dart — guard de "respuesta obsoleta" (B1)
// ============================================================
// Mecanismo compartido por InboxPage/ThreadPage/NewMessagePage para que
// una respuesta de red que arrancó ANTES pero resuelve DESPUÉS (jitter de
// red, push+resume solapados, o una cuenta anterior con un request en
// vuelo justo cuando se cierra sesión) no pueda sobreescribir memoria,
// SQLite ni la UI con datos más viejos que los que ya se aplicaron.
//
// Dos conceptos, no uno — ver por qué en el comentario de `beginSequence`:
//   - accountEpoch: solo lo mueve `invalidateAccount()` (logout/cambio de
//     cuenta). Lo capturan TODAS las operaciones (lecturas y escrituras).
//   - secuencia POR CLAVE: solo la mueven las operaciones "competitivas"
//     entre sí (ej. dos _refresh() de la bandeja, o dos _load() del MISMO
//     hilo). La clave por defecto sirve para pantallas con un solo
//     recurso (bandeja, contactos); ThreadPage pasa el threadId como
//     clave para que abrir el hilo A nunca invalide una operación en
//     vuelo del hilo B.
//
// Es deliberadamente una clase de datos simple (dos contadores) — no un
// sistema de cancelación de requests: quien la usa sigue dejando que la
// petición HTTP corra hasta el final, y solo decide, al resolver, si vale
// la pena aplicar el resultado.
// ============================================================

const _defaultKey = '_default';

class StalenessGuard {
  int _accountEpoch = 0;
  final Map<String, int> _sequenceByKey = {};

  /// Captura el epoch de cuenta actual — llamar ANTES de disparar
  /// cualquier operación (lectura o escritura) que dependa de que la
  /// sesión siga siendo la misma cuando resuelva.
  int beginAccountEpoch() => _accountEpoch;

  /// true si nadie llamó a `invalidateAccount()` desde que se capturó
  /// `epoch` — si es false, la cuenta cambió mientras la operación
  /// estaba en vuelo y su resultado debe descartarse sin tocar memoria,
  /// SQLite ni `setState`.
  bool isAccountCurrent(int epoch) => epoch == _accountEpoch;

  /// Reserva el siguiente número de secuencia para `key` — llamar ANTES
  /// de disparar una operación de red "competitiva" (ej. _refresh(),
  /// _load()). Dos operaciones de la MISMA clave que se solapan siempre
  /// pueden distinguirse: la que reservó el número más alto es la más
  /// nueva, sin importar cuál resuelve primero.
  int beginSequence([String key = _defaultKey]) {
    final next = (_sequenceByKey[key] ?? 0) + 1;
    _sequenceByKey[key] = next;
    return next;
  }

  /// true si, para `key`, nadie reservó un número de secuencia más nuevo
  /// desde que se capturó `seq` — y la cuenta sigue siendo la misma. Si
  /// es false, esta respuesta es obsoleta (otra más nueva ya ganó, o la
  /// cuenta cambió) y debe descartarse.
  bool isCurrent(int epoch, int seq, [String key = _defaultKey]) =>
      isAccountCurrent(epoch) && seq == (_sequenceByKey[key] ?? 0);

  /// Invalida TODO lo que esté en vuelo — se llama al cerrar sesión
  /// (logout/cambio de cuenta). Cualquier operación que haya capturado su
  /// epoch/secuencia ANTES de este llamado queda descartada cuando
  /// resuelva, sin importar cuánto tarde en hacerlo.
  void invalidateAccount() {
    _accountEpoch++;
    _sequenceByKey.clear();
  }
}
