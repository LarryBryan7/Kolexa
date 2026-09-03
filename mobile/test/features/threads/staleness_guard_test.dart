// ============================================================
// staleness_guard_test.dart — Fase 1: generation/staleness guard (B1)
// ============================================================
// Antes del fix, InboxPage._refresh() y ThreadPage._load() no tenían
// forma de reconocer una respuesta obsoleta: si dos peticiones a la misma
// pantalla se solapaban (push + resume, apertura + pull-to-refresh, o una
// cuenta anterior con un request en vuelo justo cuando se cierra sesión),
// la que TERMINABA última ganaba sin importar cuál había arrancado
// después — podía sobreescribir memoria, SQLite y la UI con datos más
// viejos.
//
// Estos tests prueban el mecanismo (StalenessGuard) directamente, sin
// montar InboxPage/ThreadPage: montarlas en un widget test choca con un
// hueco preexistente del proyecto (Firebase no está mockeado — es el
// mismo motivo por el que test/widget_test.dart ya fallaba antes de esta
// sesión, y mockearlo acá requeriría interceptar los canales Pigeon de
// firebase_core, un trabajo mayor y fuera de alcance de B1/B2). Probar el
// guard aislado es, si acaso, MÁS riguroso: aísla exactamente la lógica
// en cuestión sin el ruido incidental de Firebase/Dio/BLoC — y las 3
// pantallas delegan en esta MISMA clase (ver inbox_page.dart,
// thread_page.dart, new_message_page.dart), así que lo que se prueba acá
// es literalmente lo que gobierna las tres.
//
// La garantía de que la ESCRITURA a memoria/SQLite también se salta
// cuando la respuesta es obsoleta se verifica por inspección de código: en
// las tres pantallas, el mismo `if (!_guard.isCurrent(...)) return;` (o
// `isAccountCurrent`) cubre la asignación en memoria Y la llamada a
// ThreadsLocalStore.saveX en la misma rama — si el guard dice "obsoleto",
// ninguna de las dos corre.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:kolexa/features/threads/data/staleness_guard.dart';
import 'package:kolexa/features/threads/ui/inbox_page.dart';
import 'package:kolexa/features/threads/ui/new_message_page.dart';
import 'package:kolexa/features/threads/ui/thread_page.dart';

void main() {
  group('StalenessGuard — dos operaciones concurrentes de la misma clave', () {
    test('1-2) la que RESERVÓ secuencia después gana, sin importar cuál resuelve primero', () {
      final guard = StalenessGuard();

      // Dos _refresh() que se solapan: el #1 arranca, luego el #2 arranca
      // antes de que el #1 resuelva (ej. push + resume casi simultáneos).
      final epoch1 = guard.beginAccountEpoch();
      final seq1 = guard.beginSequence();
      final epoch2 = guard.beginAccountEpoch();
      final seq2 = guard.beginSequence();

      // El #2 (más nuevo) resuelve PRIMERO — su resultado debe aplicarse.
      expect(guard.isCurrent(epoch2, seq2), isTrue);

      // El #1 (más viejo) resuelve DESPUÉS — su resultado, aunque llegue
      // más tarde en el tiempo real, debe descartarse: #2 ya reservó una
      // secuencia más nueva.
      expect(guard.isCurrent(epoch1, seq1), isFalse,
          reason: 'la operación #1 arrancó antes que la #2, así que su resultado es obsoleto '
              'aunque resuelva después en tiempo real');
    });

    test('una operación sin nada más en vuelo siempre se considera vigente', () {
      final guard = StalenessGuard();
      final epoch = guard.beginAccountEpoch();
      final seq = guard.beginSequence();
      expect(guard.isCurrent(epoch, seq), isTrue);
    });

    test('claves distintas no compiten entre sí (ThreadPage: hilo A no invalida al hilo B)', () {
      final guard = StalenessGuard();
      final epochA = guard.beginAccountEpoch();
      final seqA = guard.beginSequence('hilo-A');
      final epochB = guard.beginAccountEpoch();
      final seqB = guard.beginSequence('hilo-B');

      // Abrir el hilo B (clave distinta) no debe invalidar al hilo A.
      expect(guard.isCurrent(epochA, seqA, 'hilo-A'), isTrue);
      expect(guard.isCurrent(epochB, seqB, 'hilo-B'), isTrue);
    });

    test('5) markRead/getInbox: la respuesta obsoleta no puede regresionar el unread ya confirmado', () {
      // Modela exactamente el escenario de la auditoría: dos getInbox()
      // concurrentes para la MISMA bandeja — uno arrancó antes de que
      // markRead() confirmara en el servidor (todavía ve unread:true),
      // el otro arrancó después (ya ve unread:false). No importa cuál
      // responda primero: el que arrancó después es la verdad vigente.
      final guard = StalenessGuard();
      final staleEpoch = guard.beginAccountEpoch();
      final staleSeq = guard.beginSequence(); // getInbox que todavía verá unread:true
      final freshEpoch = guard.beginAccountEpoch();
      final freshSeq = guard.beginSequence(); // getInbox que ya verá unread:false

      // El fresco resuelve primero y aplica unread:false.
      expect(guard.isCurrent(freshEpoch, freshSeq), isTrue);
      // El obsoleto resuelve después, todavía con unread:true — no debe
      // aplicarse (no debe "reaparecer" el badge de no leído).
      expect(guard.isCurrent(staleEpoch, staleSeq), isFalse);
    });
  });

  group('StalenessGuard — _loadFromDisk() y _refresh() son complementarios, no compiten', () {
    test('una lectura de disco que solo revisa el epoch de cuenta no se invalida por un refresh de red', () {
      final guard = StalenessGuard();
      // _loadFromDisk() solo captura el epoch de cuenta (no reserva
      // secuencia) — un _refresh() disparado en el mismo tick (patrón
      // real de initState: primero _loadFromDisk(), después _refresh())
      // NO debe invalidarlo, o se rompería el "instantáneo desde disco"
      // ya verificado en vivo.
      final diskEpoch = guard.beginAccountEpoch();
      guard.beginSequence(); // el _refresh() que se dispara justo después

      expect(guard.isAccountCurrent(diskEpoch), isTrue,
          reason: '_loadFromDisk() no debe verse afectado por la secuencia de _refresh()');
    });
  });

  group('StalenessGuard — cambio de cuenta (logout) invalida lo que esté en vuelo', () {
    test('3-4) una operación que capturó su epoch ANTES de invalidateAccount() queda obsoleta', () {
      final guard = StalenessGuard();
      final epoch = guard.beginAccountEpoch();
      final seq = guard.beginSequence();

      // Logout: exactamente lo que hace clearCache() en las 3 pantallas.
      guard.invalidateAccount();

      // La respuesta tardía de la cuenta anterior, sin importar cuánto
      // tarde en resolver, nunca vuelve a ser "vigente" — ni para la
      // lectura de disco (isAccountCurrent) ni para el refresh de red
      // (isCurrent). En el código real, esto es lo que impide que la
      // rama que sigue (asignar a memoria, llamar a
      // ThreadsLocalStore.saveX) se ejecute — nunca llega a intentar
      // escribir en el archivo SQLite de la cuenta que quedó activa.
      expect(guard.isAccountCurrent(epoch), isFalse);
      expect(guard.isCurrent(epoch, seq), isFalse);

      // Ni siquiera una cuenta que vuelve a "loguearse" (nuevo epoch)
      // resucita la operación vieja.
      final newEpoch = guard.beginAccountEpoch();
      final newSeq = guard.beginSequence();
      expect(guard.isCurrent(newEpoch, newSeq), isTrue);
      expect(guard.isCurrent(epoch, seq), isFalse);
    });

    test('invalidateAccount() sin nada en vuelo no rompe la siguiente operación normal', () {
      final guard = StalenessGuard();
      guard.invalidateAccount();
      final epoch = guard.beginAccountEpoch();
      final seq = guard.beginSequence();
      expect(guard.isCurrent(epoch, seq), isTrue);
    });
  });

  group('las 3 pantallas quedan cableadas al guard vía clearCache() (integración liviana)', () {
    test('InboxPage.clearCache() invalida cualquier operación en vuelo capturada antes', () {
      final epoch = InboxPage.debugGuard.beginAccountEpoch();
      final seq = InboxPage.debugGuard.beginSequence();
      InboxPage.clearCache();
      expect(InboxPage.debugGuard.isCurrent(epoch, seq), isFalse);
    });

    test('ThreadPage.clearCache() invalida cualquier operación en vuelo capturada antes (cualquier hilo)', () {
      final epoch = ThreadPage.debugGuard.beginAccountEpoch();
      final seq = ThreadPage.debugGuard.beginSequence('t1');
      ThreadPage.clearCache();
      expect(ThreadPage.debugGuard.isCurrent(epoch, seq, 't1'), isFalse);
    });

    test('NewMessagePage.clearCache() invalida cualquier operación en vuelo capturada antes', () {
      final epoch = NewMessagePage.debugGuard.beginAccountEpoch();
      final seq = NewMessagePage.debugGuard.beginSequence();
      NewMessagePage.clearCache();
      expect(NewMessagePage.debugGuard.isCurrent(epoch, seq), isFalse);
    });
  });
}
