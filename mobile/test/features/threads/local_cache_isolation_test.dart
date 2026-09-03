// ============================================================
// local_cache_isolation_test.dart — cache en memoria al cerrar sesión
// ============================================================
// El aislamiento en disco (ver app_database_isolation_test.dart) no
// alcanza por sí solo: InboxPage, ThreadPage y NewMessagePage mantienen
// además un cache estático en memoria (sobrevive a que la pantalla se
// destruya y se recree) que NO se borra solo porque AppDatabase cierre su
// archivo. Si una cuenta distinta inicia sesión en el MISMO proceso de la
// app (sin matarla), ese cache en memoria seguiría mostrando, al instante,
// los hilos/mensajes/contactos de la cuenta anterior hasta que el primer
// refresh de red de la cuenta nueva resuelva.
//
// Estos tests prueban que clearCache() en cada pantalla vacía de verdad
// ese cache — es lo que main.dart llama junto con AppDatabase.close()
// cuando el AuthBloc emite AuthUnauthenticated.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:kolexa/features/threads/data/threads_repository.dart';
import 'package:kolexa/features/threads/ui/inbox_page.dart';
import 'package:kolexa/features/threads/ui/new_message_page.dart';
import 'package:kolexa/features/threads/ui/thread_page.dart';

void main() {
  tearDown(() {
    InboxPage.clearCache();
    ThreadPage.clearCache();
    NewMessagePage.clearCache();
  });

  group('InboxPage', () {
    test('clearCache() vacía el cache de la bandeja de la cuenta anterior', () {
      InboxPage.debugCachedThreads = [
        ThreadSummary(
          id: 't1',
          kind: 'direct',
          priority: 'normal',
          lastMessageAt: DateTime(2026, 1, 1),
          unread: false,
          unreadCount: 0,
          muted: false,
        ),
      ];
      expect(InboxPage.debugCachedThreads, isNotEmpty);

      InboxPage.clearCache();

      expect(InboxPage.debugCachedThreads, isNull);
    });

    test('clearCache() también invalida el guard de staleness (B1)', () {
      final epoch = InboxPage.debugGuard.beginAccountEpoch();
      InboxPage.clearCache();
      expect(InboxPage.debugGuard.isAccountCurrent(epoch), isFalse);
    });
  });

  group('ThreadPage', () {
    test('clearCache() vacía TODAS las conversaciones cacheadas, de cualquier hilo', () {
      ThreadPage.debugCache['thread-a'] = ThreadMessagesPage(
        messages: const [],
        otherLastReadAt: null,
        otherLastActiveAt: null,
      );
      ThreadPage.debugCache['thread-b'] = ThreadMessagesPage(
        messages: const [],
        otherLastReadAt: null,
        otherLastActiveAt: null,
      );
      expect(ThreadPage.debugCache, isNotEmpty);

      ThreadPage.clearCache();

      expect(ThreadPage.debugCache, isEmpty);
    });

    test('clearCache() también invalida el guard de staleness (B1)', () {
      final epoch = ThreadPage.debugGuard.beginAccountEpoch();
      ThreadPage.clearCache();
      expect(ThreadPage.debugGuard.isAccountCurrent(epoch), isFalse);
    });
  });

  group('NewMessagePage', () {
    test('clearCache() vacía el cache de contactos de la cuenta anterior', () {
      NewMessagePage.debugCachedContacts = const [
        Contact(userId: '1', name: 'Alguien', avatar: null, role: 'teacher', students: []),
      ];
      expect(NewMessagePage.debugCachedContacts, isNotEmpty);

      NewMessagePage.clearCache();

      expect(NewMessagePage.debugCachedContacts, isNull);
    });

    test('clearCache() también invalida el guard de staleness (B1)', () {
      final epoch = NewMessagePage.debugGuard.beginAccountEpoch();
      NewMessagePage.clearCache();
      expect(NewMessagePage.debugGuard.isAccountCurrent(epoch), isFalse);
    });
  });
}
