// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'threads_drift_db.dart';

// ignore_for_file: type=lint
class $InboxThreadsTable extends InboxThreads
    with TableInfo<$InboxThreadsTable, InboxThread> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InboxThreadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _subjectMeta =
      const VerificationMeta('subject');
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
      'subject', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _studentIdMeta =
      const VerificationMeta('studentId');
  @override
  late final GeneratedColumn<String> studentId = GeneratedColumn<String>(
      'studentId', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _studentNameMeta =
      const VerificationMeta('studentName');
  @override
  late final GeneratedColumn<String> studentName = GeneratedColumn<String>(
      'studentName', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _priorityMeta =
      const VerificationMeta('priority');
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
      'priority', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastMessageAtMeta =
      const VerificationMeta('lastMessageAt');
  @override
  late final GeneratedColumn<int> lastMessageAt = GeneratedColumn<int>(
      'lastMessageAt', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _unreadMeta = const VerificationMeta('unread');
  @override
  late final GeneratedColumn<bool> unread = GeneratedColumn<bool>(
      'unread', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("unread" IN (0, 1))'));
  static const VerificationMeta _unreadCountMeta =
      const VerificationMeta('unreadCount');
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
      'unreadCount', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _mutedMeta = const VerificationMeta('muted');
  @override
  late final GeneratedColumn<bool> muted = GeneratedColumn<bool>(
      'muted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("muted" IN (0, 1))'));
  static const VerificationMeta _otherIdMeta =
      const VerificationMeta('otherId');
  @override
  late final GeneratedColumn<String> otherId = GeneratedColumn<String>(
      'otherId', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _otherNameMeta =
      const VerificationMeta('otherName');
  @override
  late final GeneratedColumn<String> otherName = GeneratedColumn<String>(
      'otherName', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _otherAvatarMeta =
      const VerificationMeta('otherAvatar');
  @override
  late final GeneratedColumn<String> otherAvatar = GeneratedColumn<String>(
      'otherAvatar', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _otherOnlineMeta =
      const VerificationMeta('otherOnline');
  @override
  late final GeneratedColumn<bool> otherOnline = GeneratedColumn<bool>(
      'otherOnline', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("otherOnline" IN (0, 1))'));
  static const VerificationMeta _lastMsgBodyMeta =
      const VerificationMeta('lastMsgBody');
  @override
  late final GeneratedColumn<String> lastMsgBody = GeneratedColumn<String>(
      'lastMsgBody', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastMsgSenderIdMeta =
      const VerificationMeta('lastMsgSenderId');
  @override
  late final GeneratedColumn<String> lastMsgSenderId = GeneratedColumn<String>(
      'lastMsgSenderId', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastMsgSentAtMeta =
      const VerificationMeta('lastMsgSentAt');
  @override
  late final GeneratedColumn<int> lastMsgSentAt = GeneratedColumn<int>(
      'lastMsgSentAt', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _lastMsgDeliveredMeta =
      const VerificationMeta('lastMsgDelivered');
  @override
  late final GeneratedColumn<bool> lastMsgDelivered = GeneratedColumn<bool>(
      'lastMsgDelivered', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("lastMsgDelivered" IN (0, 1))'));
  static const VerificationMeta _sortIndexMeta =
      const VerificationMeta('sortIndex');
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
      'sortIndex', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        kind,
        subject,
        studentId,
        studentName,
        priority,
        lastMessageAt,
        unread,
        unreadCount,
        muted,
        otherId,
        otherName,
        otherAvatar,
        otherOnline,
        lastMsgBody,
        lastMsgSenderId,
        lastMsgSentAt,
        lastMsgDelivered,
        sortIndex
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inbox_threads';
  @override
  VerificationContext validateIntegrity(Insertable<InboxThread> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(_subjectMeta,
          subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta));
    }
    if (data.containsKey('studentId')) {
      context.handle(_studentIdMeta,
          studentId.isAcceptableOrUnknown(data['studentId']!, _studentIdMeta));
    }
    if (data.containsKey('studentName')) {
      context.handle(
          _studentNameMeta,
          studentName.isAcceptableOrUnknown(
              data['studentName']!, _studentNameMeta));
    }
    if (data.containsKey('priority')) {
      context.handle(_priorityMeta,
          priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta));
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('lastMessageAt')) {
      context.handle(
          _lastMessageAtMeta,
          lastMessageAt.isAcceptableOrUnknown(
              data['lastMessageAt']!, _lastMessageAtMeta));
    } else if (isInserting) {
      context.missing(_lastMessageAtMeta);
    }
    if (data.containsKey('unread')) {
      context.handle(_unreadMeta,
          unread.isAcceptableOrUnknown(data['unread']!, _unreadMeta));
    } else if (isInserting) {
      context.missing(_unreadMeta);
    }
    if (data.containsKey('unreadCount')) {
      context.handle(
          _unreadCountMeta,
          unreadCount.isAcceptableOrUnknown(
              data['unreadCount']!, _unreadCountMeta));
    } else if (isInserting) {
      context.missing(_unreadCountMeta);
    }
    if (data.containsKey('muted')) {
      context.handle(
          _mutedMeta, muted.isAcceptableOrUnknown(data['muted']!, _mutedMeta));
    } else if (isInserting) {
      context.missing(_mutedMeta);
    }
    if (data.containsKey('otherId')) {
      context.handle(_otherIdMeta,
          otherId.isAcceptableOrUnknown(data['otherId']!, _otherIdMeta));
    }
    if (data.containsKey('otherName')) {
      context.handle(_otherNameMeta,
          otherName.isAcceptableOrUnknown(data['otherName']!, _otherNameMeta));
    }
    if (data.containsKey('otherAvatar')) {
      context.handle(
          _otherAvatarMeta,
          otherAvatar.isAcceptableOrUnknown(
              data['otherAvatar']!, _otherAvatarMeta));
    }
    if (data.containsKey('otherOnline')) {
      context.handle(
          _otherOnlineMeta,
          otherOnline.isAcceptableOrUnknown(
              data['otherOnline']!, _otherOnlineMeta));
    }
    if (data.containsKey('lastMsgBody')) {
      context.handle(
          _lastMsgBodyMeta,
          lastMsgBody.isAcceptableOrUnknown(
              data['lastMsgBody']!, _lastMsgBodyMeta));
    }
    if (data.containsKey('lastMsgSenderId')) {
      context.handle(
          _lastMsgSenderIdMeta,
          lastMsgSenderId.isAcceptableOrUnknown(
              data['lastMsgSenderId']!, _lastMsgSenderIdMeta));
    }
    if (data.containsKey('lastMsgSentAt')) {
      context.handle(
          _lastMsgSentAtMeta,
          lastMsgSentAt.isAcceptableOrUnknown(
              data['lastMsgSentAt']!, _lastMsgSentAtMeta));
    }
    if (data.containsKey('lastMsgDelivered')) {
      context.handle(
          _lastMsgDeliveredMeta,
          lastMsgDelivered.isAcceptableOrUnknown(
              data['lastMsgDelivered']!, _lastMsgDeliveredMeta));
    }
    if (data.containsKey('sortIndex')) {
      context.handle(_sortIndexMeta,
          sortIndex.isAcceptableOrUnknown(data['sortIndex']!, _sortIndexMeta));
    } else if (isInserting) {
      context.missing(_sortIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InboxThread map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InboxThread(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      subject: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject']),
      studentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}studentId']),
      studentName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}studentName']),
      priority: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}priority'])!,
      lastMessageAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}lastMessageAt'])!,
      unread: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}unread'])!,
      unreadCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}unreadCount'])!,
      muted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}muted'])!,
      otherId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}otherId']),
      otherName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}otherName']),
      otherAvatar: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}otherAvatar']),
      otherOnline: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}otherOnline']),
      lastMsgBody: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lastMsgBody']),
      lastMsgSenderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lastMsgSenderId']),
      lastMsgSentAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}lastMsgSentAt']),
      lastMsgDelivered: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}lastMsgDelivered']),
      sortIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sortIndex'])!,
    );
  }

  @override
  $InboxThreadsTable createAlias(String alias) {
    return $InboxThreadsTable(attachedDatabase, alias);
  }
}

class InboxThread extends DataClass implements Insertable<InboxThread> {
  final String id;
  final String kind;
  final String? subject;
  final String? studentId;
  final String? studentName;
  final String priority;
  final int lastMessageAt;
  final bool unread;
  final int unreadCount;
  final bool muted;
  final String? otherId;
  final String? otherName;
  final String? otherAvatar;
  final bool? otherOnline;
  final String? lastMsgBody;
  final String? lastMsgSenderId;
  final int? lastMsgSentAt;
  final bool? lastMsgDelivered;
  final int sortIndex;
  const InboxThread(
      {required this.id,
      required this.kind,
      this.subject,
      this.studentId,
      this.studentName,
      required this.priority,
      required this.lastMessageAt,
      required this.unread,
      required this.unreadCount,
      required this.muted,
      this.otherId,
      this.otherName,
      this.otherAvatar,
      this.otherOnline,
      this.lastMsgBody,
      this.lastMsgSenderId,
      this.lastMsgSentAt,
      this.lastMsgDelivered,
      required this.sortIndex});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || subject != null) {
      map['subject'] = Variable<String>(subject);
    }
    if (!nullToAbsent || studentId != null) {
      map['studentId'] = Variable<String>(studentId);
    }
    if (!nullToAbsent || studentName != null) {
      map['studentName'] = Variable<String>(studentName);
    }
    map['priority'] = Variable<String>(priority);
    map['lastMessageAt'] = Variable<int>(lastMessageAt);
    map['unread'] = Variable<bool>(unread);
    map['unreadCount'] = Variable<int>(unreadCount);
    map['muted'] = Variable<bool>(muted);
    if (!nullToAbsent || otherId != null) {
      map['otherId'] = Variable<String>(otherId);
    }
    if (!nullToAbsent || otherName != null) {
      map['otherName'] = Variable<String>(otherName);
    }
    if (!nullToAbsent || otherAvatar != null) {
      map['otherAvatar'] = Variable<String>(otherAvatar);
    }
    if (!nullToAbsent || otherOnline != null) {
      map['otherOnline'] = Variable<bool>(otherOnline);
    }
    if (!nullToAbsent || lastMsgBody != null) {
      map['lastMsgBody'] = Variable<String>(lastMsgBody);
    }
    if (!nullToAbsent || lastMsgSenderId != null) {
      map['lastMsgSenderId'] = Variable<String>(lastMsgSenderId);
    }
    if (!nullToAbsent || lastMsgSentAt != null) {
      map['lastMsgSentAt'] = Variable<int>(lastMsgSentAt);
    }
    if (!nullToAbsent || lastMsgDelivered != null) {
      map['lastMsgDelivered'] = Variable<bool>(lastMsgDelivered);
    }
    map['sortIndex'] = Variable<int>(sortIndex);
    return map;
  }

  InboxThreadsCompanion toCompanion(bool nullToAbsent) {
    return InboxThreadsCompanion(
      id: Value(id),
      kind: Value(kind),
      subject: subject == null && nullToAbsent
          ? const Value.absent()
          : Value(subject),
      studentId: studentId == null && nullToAbsent
          ? const Value.absent()
          : Value(studentId),
      studentName: studentName == null && nullToAbsent
          ? const Value.absent()
          : Value(studentName),
      priority: Value(priority),
      lastMessageAt: Value(lastMessageAt),
      unread: Value(unread),
      unreadCount: Value(unreadCount),
      muted: Value(muted),
      otherId: otherId == null && nullToAbsent
          ? const Value.absent()
          : Value(otherId),
      otherName: otherName == null && nullToAbsent
          ? const Value.absent()
          : Value(otherName),
      otherAvatar: otherAvatar == null && nullToAbsent
          ? const Value.absent()
          : Value(otherAvatar),
      otherOnline: otherOnline == null && nullToAbsent
          ? const Value.absent()
          : Value(otherOnline),
      lastMsgBody: lastMsgBody == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMsgBody),
      lastMsgSenderId: lastMsgSenderId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMsgSenderId),
      lastMsgSentAt: lastMsgSentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMsgSentAt),
      lastMsgDelivered: lastMsgDelivered == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMsgDelivered),
      sortIndex: Value(sortIndex),
    );
  }

  factory InboxThread.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InboxThread(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      subject: serializer.fromJson<String?>(json['subject']),
      studentId: serializer.fromJson<String?>(json['studentId']),
      studentName: serializer.fromJson<String?>(json['studentName']),
      priority: serializer.fromJson<String>(json['priority']),
      lastMessageAt: serializer.fromJson<int>(json['lastMessageAt']),
      unread: serializer.fromJson<bool>(json['unread']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      muted: serializer.fromJson<bool>(json['muted']),
      otherId: serializer.fromJson<String?>(json['otherId']),
      otherName: serializer.fromJson<String?>(json['otherName']),
      otherAvatar: serializer.fromJson<String?>(json['otherAvatar']),
      otherOnline: serializer.fromJson<bool?>(json['otherOnline']),
      lastMsgBody: serializer.fromJson<String?>(json['lastMsgBody']),
      lastMsgSenderId: serializer.fromJson<String?>(json['lastMsgSenderId']),
      lastMsgSentAt: serializer.fromJson<int?>(json['lastMsgSentAt']),
      lastMsgDelivered: serializer.fromJson<bool?>(json['lastMsgDelivered']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'subject': serializer.toJson<String?>(subject),
      'studentId': serializer.toJson<String?>(studentId),
      'studentName': serializer.toJson<String?>(studentName),
      'priority': serializer.toJson<String>(priority),
      'lastMessageAt': serializer.toJson<int>(lastMessageAt),
      'unread': serializer.toJson<bool>(unread),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'muted': serializer.toJson<bool>(muted),
      'otherId': serializer.toJson<String?>(otherId),
      'otherName': serializer.toJson<String?>(otherName),
      'otherAvatar': serializer.toJson<String?>(otherAvatar),
      'otherOnline': serializer.toJson<bool?>(otherOnline),
      'lastMsgBody': serializer.toJson<String?>(lastMsgBody),
      'lastMsgSenderId': serializer.toJson<String?>(lastMsgSenderId),
      'lastMsgSentAt': serializer.toJson<int?>(lastMsgSentAt),
      'lastMsgDelivered': serializer.toJson<bool?>(lastMsgDelivered),
      'sortIndex': serializer.toJson<int>(sortIndex),
    };
  }

  InboxThread copyWith(
          {String? id,
          String? kind,
          Value<String?> subject = const Value.absent(),
          Value<String?> studentId = const Value.absent(),
          Value<String?> studentName = const Value.absent(),
          String? priority,
          int? lastMessageAt,
          bool? unread,
          int? unreadCount,
          bool? muted,
          Value<String?> otherId = const Value.absent(),
          Value<String?> otherName = const Value.absent(),
          Value<String?> otherAvatar = const Value.absent(),
          Value<bool?> otherOnline = const Value.absent(),
          Value<String?> lastMsgBody = const Value.absent(),
          Value<String?> lastMsgSenderId = const Value.absent(),
          Value<int?> lastMsgSentAt = const Value.absent(),
          Value<bool?> lastMsgDelivered = const Value.absent(),
          int? sortIndex}) =>
      InboxThread(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        subject: subject.present ? subject.value : this.subject,
        studentId: studentId.present ? studentId.value : this.studentId,
        studentName: studentName.present ? studentName.value : this.studentName,
        priority: priority ?? this.priority,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        unread: unread ?? this.unread,
        unreadCount: unreadCount ?? this.unreadCount,
        muted: muted ?? this.muted,
        otherId: otherId.present ? otherId.value : this.otherId,
        otherName: otherName.present ? otherName.value : this.otherName,
        otherAvatar: otherAvatar.present ? otherAvatar.value : this.otherAvatar,
        otherOnline: otherOnline.present ? otherOnline.value : this.otherOnline,
        lastMsgBody: lastMsgBody.present ? lastMsgBody.value : this.lastMsgBody,
        lastMsgSenderId: lastMsgSenderId.present
            ? lastMsgSenderId.value
            : this.lastMsgSenderId,
        lastMsgSentAt:
            lastMsgSentAt.present ? lastMsgSentAt.value : this.lastMsgSentAt,
        lastMsgDelivered: lastMsgDelivered.present
            ? lastMsgDelivered.value
            : this.lastMsgDelivered,
        sortIndex: sortIndex ?? this.sortIndex,
      );
  InboxThread copyWithCompanion(InboxThreadsCompanion data) {
    return InboxThread(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      subject: data.subject.present ? data.subject.value : this.subject,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      studentName:
          data.studentName.present ? data.studentName.value : this.studentName,
      priority: data.priority.present ? data.priority.value : this.priority,
      lastMessageAt: data.lastMessageAt.present
          ? data.lastMessageAt.value
          : this.lastMessageAt,
      unread: data.unread.present ? data.unread.value : this.unread,
      unreadCount:
          data.unreadCount.present ? data.unreadCount.value : this.unreadCount,
      muted: data.muted.present ? data.muted.value : this.muted,
      otherId: data.otherId.present ? data.otherId.value : this.otherId,
      otherName: data.otherName.present ? data.otherName.value : this.otherName,
      otherAvatar:
          data.otherAvatar.present ? data.otherAvatar.value : this.otherAvatar,
      otherOnline:
          data.otherOnline.present ? data.otherOnline.value : this.otherOnline,
      lastMsgBody:
          data.lastMsgBody.present ? data.lastMsgBody.value : this.lastMsgBody,
      lastMsgSenderId: data.lastMsgSenderId.present
          ? data.lastMsgSenderId.value
          : this.lastMsgSenderId,
      lastMsgSentAt: data.lastMsgSentAt.present
          ? data.lastMsgSentAt.value
          : this.lastMsgSentAt,
      lastMsgDelivered: data.lastMsgDelivered.present
          ? data.lastMsgDelivered.value
          : this.lastMsgDelivered,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InboxThread(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('subject: $subject, ')
          ..write('studentId: $studentId, ')
          ..write('studentName: $studentName, ')
          ..write('priority: $priority, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('unread: $unread, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('muted: $muted, ')
          ..write('otherId: $otherId, ')
          ..write('otherName: $otherName, ')
          ..write('otherAvatar: $otherAvatar, ')
          ..write('otherOnline: $otherOnline, ')
          ..write('lastMsgBody: $lastMsgBody, ')
          ..write('lastMsgSenderId: $lastMsgSenderId, ')
          ..write('lastMsgSentAt: $lastMsgSentAt, ')
          ..write('lastMsgDelivered: $lastMsgDelivered, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      kind,
      subject,
      studentId,
      studentName,
      priority,
      lastMessageAt,
      unread,
      unreadCount,
      muted,
      otherId,
      otherName,
      otherAvatar,
      otherOnline,
      lastMsgBody,
      lastMsgSenderId,
      lastMsgSentAt,
      lastMsgDelivered,
      sortIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InboxThread &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.subject == this.subject &&
          other.studentId == this.studentId &&
          other.studentName == this.studentName &&
          other.priority == this.priority &&
          other.lastMessageAt == this.lastMessageAt &&
          other.unread == this.unread &&
          other.unreadCount == this.unreadCount &&
          other.muted == this.muted &&
          other.otherId == this.otherId &&
          other.otherName == this.otherName &&
          other.otherAvatar == this.otherAvatar &&
          other.otherOnline == this.otherOnline &&
          other.lastMsgBody == this.lastMsgBody &&
          other.lastMsgSenderId == this.lastMsgSenderId &&
          other.lastMsgSentAt == this.lastMsgSentAt &&
          other.lastMsgDelivered == this.lastMsgDelivered &&
          other.sortIndex == this.sortIndex);
}

class InboxThreadsCompanion extends UpdateCompanion<InboxThread> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String?> subject;
  final Value<String?> studentId;
  final Value<String?> studentName;
  final Value<String> priority;
  final Value<int> lastMessageAt;
  final Value<bool> unread;
  final Value<int> unreadCount;
  final Value<bool> muted;
  final Value<String?> otherId;
  final Value<String?> otherName;
  final Value<String?> otherAvatar;
  final Value<bool?> otherOnline;
  final Value<String?> lastMsgBody;
  final Value<String?> lastMsgSenderId;
  final Value<int?> lastMsgSentAt;
  final Value<bool?> lastMsgDelivered;
  final Value<int> sortIndex;
  final Value<int> rowid;
  const InboxThreadsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.subject = const Value.absent(),
    this.studentId = const Value.absent(),
    this.studentName = const Value.absent(),
    this.priority = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.unread = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.muted = const Value.absent(),
    this.otherId = const Value.absent(),
    this.otherName = const Value.absent(),
    this.otherAvatar = const Value.absent(),
    this.otherOnline = const Value.absent(),
    this.lastMsgBody = const Value.absent(),
    this.lastMsgSenderId = const Value.absent(),
    this.lastMsgSentAt = const Value.absent(),
    this.lastMsgDelivered = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InboxThreadsCompanion.insert({
    required String id,
    required String kind,
    this.subject = const Value.absent(),
    this.studentId = const Value.absent(),
    this.studentName = const Value.absent(),
    required String priority,
    required int lastMessageAt,
    required bool unread,
    required int unreadCount,
    required bool muted,
    this.otherId = const Value.absent(),
    this.otherName = const Value.absent(),
    this.otherAvatar = const Value.absent(),
    this.otherOnline = const Value.absent(),
    this.lastMsgBody = const Value.absent(),
    this.lastMsgSenderId = const Value.absent(),
    this.lastMsgSentAt = const Value.absent(),
    this.lastMsgDelivered = const Value.absent(),
    required int sortIndex,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        kind = Value(kind),
        priority = Value(priority),
        lastMessageAt = Value(lastMessageAt),
        unread = Value(unread),
        unreadCount = Value(unreadCount),
        muted = Value(muted),
        sortIndex = Value(sortIndex);
  static Insertable<InboxThread> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? subject,
    Expression<String>? studentId,
    Expression<String>? studentName,
    Expression<String>? priority,
    Expression<int>? lastMessageAt,
    Expression<bool>? unread,
    Expression<int>? unreadCount,
    Expression<bool>? muted,
    Expression<String>? otherId,
    Expression<String>? otherName,
    Expression<String>? otherAvatar,
    Expression<bool>? otherOnline,
    Expression<String>? lastMsgBody,
    Expression<String>? lastMsgSenderId,
    Expression<int>? lastMsgSentAt,
    Expression<bool>? lastMsgDelivered,
    Expression<int>? sortIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (subject != null) 'subject': subject,
      if (studentId != null) 'studentId': studentId,
      if (studentName != null) 'studentName': studentName,
      if (priority != null) 'priority': priority,
      if (lastMessageAt != null) 'lastMessageAt': lastMessageAt,
      if (unread != null) 'unread': unread,
      if (unreadCount != null) 'unreadCount': unreadCount,
      if (muted != null) 'muted': muted,
      if (otherId != null) 'otherId': otherId,
      if (otherName != null) 'otherName': otherName,
      if (otherAvatar != null) 'otherAvatar': otherAvatar,
      if (otherOnline != null) 'otherOnline': otherOnline,
      if (lastMsgBody != null) 'lastMsgBody': lastMsgBody,
      if (lastMsgSenderId != null) 'lastMsgSenderId': lastMsgSenderId,
      if (lastMsgSentAt != null) 'lastMsgSentAt': lastMsgSentAt,
      if (lastMsgDelivered != null) 'lastMsgDelivered': lastMsgDelivered,
      if (sortIndex != null) 'sortIndex': sortIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InboxThreadsCompanion copyWith(
      {Value<String>? id,
      Value<String>? kind,
      Value<String?>? subject,
      Value<String?>? studentId,
      Value<String?>? studentName,
      Value<String>? priority,
      Value<int>? lastMessageAt,
      Value<bool>? unread,
      Value<int>? unreadCount,
      Value<bool>? muted,
      Value<String?>? otherId,
      Value<String?>? otherName,
      Value<String?>? otherAvatar,
      Value<bool?>? otherOnline,
      Value<String?>? lastMsgBody,
      Value<String?>? lastMsgSenderId,
      Value<int?>? lastMsgSentAt,
      Value<bool?>? lastMsgDelivered,
      Value<int>? sortIndex,
      Value<int>? rowid}) {
    return InboxThreadsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      subject: subject ?? this.subject,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      priority: priority ?? this.priority,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unread: unread ?? this.unread,
      unreadCount: unreadCount ?? this.unreadCount,
      muted: muted ?? this.muted,
      otherId: otherId ?? this.otherId,
      otherName: otherName ?? this.otherName,
      otherAvatar: otherAvatar ?? this.otherAvatar,
      otherOnline: otherOnline ?? this.otherOnline,
      lastMsgBody: lastMsgBody ?? this.lastMsgBody,
      lastMsgSenderId: lastMsgSenderId ?? this.lastMsgSenderId,
      lastMsgSentAt: lastMsgSentAt ?? this.lastMsgSentAt,
      lastMsgDelivered: lastMsgDelivered ?? this.lastMsgDelivered,
      sortIndex: sortIndex ?? this.sortIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (studentId.present) {
      map['studentId'] = Variable<String>(studentId.value);
    }
    if (studentName.present) {
      map['studentName'] = Variable<String>(studentName.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (lastMessageAt.present) {
      map['lastMessageAt'] = Variable<int>(lastMessageAt.value);
    }
    if (unread.present) {
      map['unread'] = Variable<bool>(unread.value);
    }
    if (unreadCount.present) {
      map['unreadCount'] = Variable<int>(unreadCount.value);
    }
    if (muted.present) {
      map['muted'] = Variable<bool>(muted.value);
    }
    if (otherId.present) {
      map['otherId'] = Variable<String>(otherId.value);
    }
    if (otherName.present) {
      map['otherName'] = Variable<String>(otherName.value);
    }
    if (otherAvatar.present) {
      map['otherAvatar'] = Variable<String>(otherAvatar.value);
    }
    if (otherOnline.present) {
      map['otherOnline'] = Variable<bool>(otherOnline.value);
    }
    if (lastMsgBody.present) {
      map['lastMsgBody'] = Variable<String>(lastMsgBody.value);
    }
    if (lastMsgSenderId.present) {
      map['lastMsgSenderId'] = Variable<String>(lastMsgSenderId.value);
    }
    if (lastMsgSentAt.present) {
      map['lastMsgSentAt'] = Variable<int>(lastMsgSentAt.value);
    }
    if (lastMsgDelivered.present) {
      map['lastMsgDelivered'] = Variable<bool>(lastMsgDelivered.value);
    }
    if (sortIndex.present) {
      map['sortIndex'] = Variable<int>(sortIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InboxThreadsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('subject: $subject, ')
          ..write('studentId: $studentId, ')
          ..write('studentName: $studentName, ')
          ..write('priority: $priority, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('unread: $unread, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('muted: $muted, ')
          ..write('otherId: $otherId, ')
          ..write('otherName: $otherName, ')
          ..write('otherAvatar: $otherAvatar, ')
          ..write('otherOnline: $otherOnline, ')
          ..write('lastMsgBody: $lastMsgBody, ')
          ..write('lastMsgSenderId: $lastMsgSenderId, ')
          ..write('lastMsgSentAt: $lastMsgSentAt, ')
          ..write('lastMsgDelivered: $lastMsgDelivered, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ThreadMessagesTable extends ThreadMessages
    with TableInfo<$ThreadMessagesTable, ThreadMessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ThreadMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _threadIdMeta =
      const VerificationMeta('threadId');
  @override
  late final GeneratedColumn<String> threadId = GeneratedColumn<String>(
      'threadId', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderIdMeta =
      const VerificationMeta('senderId');
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
      'senderId', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderNameMeta =
      const VerificationMeta('senderName');
  @override
  late final GeneratedColumn<String> senderName = GeneratedColumn<String>(
      'senderName', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<int> sentAt = GeneratedColumn<int>(
      'sentAt', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, threadId, senderId, senderName, body, sentAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'thread_messages';
  @override
  VerificationContext validateIntegrity(Insertable<ThreadMessageRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('threadId')) {
      context.handle(_threadIdMeta,
          threadId.isAcceptableOrUnknown(data['threadId']!, _threadIdMeta));
    } else if (isInserting) {
      context.missing(_threadIdMeta);
    }
    if (data.containsKey('senderId')) {
      context.handle(_senderIdMeta,
          senderId.isAcceptableOrUnknown(data['senderId']!, _senderIdMeta));
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('senderName')) {
      context.handle(
          _senderNameMeta,
          senderName.isAcceptableOrUnknown(
              data['senderName']!, _senderNameMeta));
    } else if (isInserting) {
      context.missing(_senderNameMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('sentAt')) {
      context.handle(_sentAtMeta,
          sentAt.isAcceptableOrUnknown(data['sentAt']!, _sentAtMeta));
    } else if (isInserting) {
      context.missing(_sentAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ThreadMessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ThreadMessageRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      threadId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}threadId'])!,
      senderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}senderId'])!,
      senderName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}senderName'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      sentAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sentAt'])!,
    );
  }

  @override
  $ThreadMessagesTable createAlias(String alias) {
    return $ThreadMessagesTable(attachedDatabase, alias);
  }
}

class ThreadMessageRow extends DataClass
    implements Insertable<ThreadMessageRow> {
  final String id;
  final String threadId;
  final String senderId;
  final String senderName;
  final String body;
  final int sentAt;
  const ThreadMessageRow(
      {required this.id,
      required this.threadId,
      required this.senderId,
      required this.senderName,
      required this.body,
      required this.sentAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['threadId'] = Variable<String>(threadId);
    map['senderId'] = Variable<String>(senderId);
    map['senderName'] = Variable<String>(senderName);
    map['body'] = Variable<String>(body);
    map['sentAt'] = Variable<int>(sentAt);
    return map;
  }

  ThreadMessagesCompanion toCompanion(bool nullToAbsent) {
    return ThreadMessagesCompanion(
      id: Value(id),
      threadId: Value(threadId),
      senderId: Value(senderId),
      senderName: Value(senderName),
      body: Value(body),
      sentAt: Value(sentAt),
    );
  }

  factory ThreadMessageRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ThreadMessageRow(
      id: serializer.fromJson<String>(json['id']),
      threadId: serializer.fromJson<String>(json['threadId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      senderName: serializer.fromJson<String>(json['senderName']),
      body: serializer.fromJson<String>(json['body']),
      sentAt: serializer.fromJson<int>(json['sentAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'threadId': serializer.toJson<String>(threadId),
      'senderId': serializer.toJson<String>(senderId),
      'senderName': serializer.toJson<String>(senderName),
      'body': serializer.toJson<String>(body),
      'sentAt': serializer.toJson<int>(sentAt),
    };
  }

  ThreadMessageRow copyWith(
          {String? id,
          String? threadId,
          String? senderId,
          String? senderName,
          String? body,
          int? sentAt}) =>
      ThreadMessageRow(
        id: id ?? this.id,
        threadId: threadId ?? this.threadId,
        senderId: senderId ?? this.senderId,
        senderName: senderName ?? this.senderName,
        body: body ?? this.body,
        sentAt: sentAt ?? this.sentAt,
      );
  ThreadMessageRow copyWithCompanion(ThreadMessagesCompanion data) {
    return ThreadMessageRow(
      id: data.id.present ? data.id.value : this.id,
      threadId: data.threadId.present ? data.threadId.value : this.threadId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      senderName:
          data.senderName.present ? data.senderName.value : this.senderName,
      body: data.body.present ? data.body.value : this.body,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ThreadMessageRow(')
          ..write('id: $id, ')
          ..write('threadId: $threadId, ')
          ..write('senderId: $senderId, ')
          ..write('senderName: $senderName, ')
          ..write('body: $body, ')
          ..write('sentAt: $sentAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, threadId, senderId, senderName, body, sentAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ThreadMessageRow &&
          other.id == this.id &&
          other.threadId == this.threadId &&
          other.senderId == this.senderId &&
          other.senderName == this.senderName &&
          other.body == this.body &&
          other.sentAt == this.sentAt);
}

class ThreadMessagesCompanion extends UpdateCompanion<ThreadMessageRow> {
  final Value<String> id;
  final Value<String> threadId;
  final Value<String> senderId;
  final Value<String> senderName;
  final Value<String> body;
  final Value<int> sentAt;
  final Value<int> rowid;
  const ThreadMessagesCompanion({
    this.id = const Value.absent(),
    this.threadId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.senderName = const Value.absent(),
    this.body = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ThreadMessagesCompanion.insert({
    required String id,
    required String threadId,
    required String senderId,
    required String senderName,
    required String body,
    required int sentAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        threadId = Value(threadId),
        senderId = Value(senderId),
        senderName = Value(senderName),
        body = Value(body),
        sentAt = Value(sentAt);
  static Insertable<ThreadMessageRow> custom({
    Expression<String>? id,
    Expression<String>? threadId,
    Expression<String>? senderId,
    Expression<String>? senderName,
    Expression<String>? body,
    Expression<int>? sentAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (threadId != null) 'threadId': threadId,
      if (senderId != null) 'senderId': senderId,
      if (senderName != null) 'senderName': senderName,
      if (body != null) 'body': body,
      if (sentAt != null) 'sentAt': sentAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ThreadMessagesCompanion copyWith(
      {Value<String>? id,
      Value<String>? threadId,
      Value<String>? senderId,
      Value<String>? senderName,
      Value<String>? body,
      Value<int>? sentAt,
      Value<int>? rowid}) {
    return ThreadMessagesCompanion(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      body: body ?? this.body,
      sentAt: sentAt ?? this.sentAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (threadId.present) {
      map['threadId'] = Variable<String>(threadId.value);
    }
    if (senderId.present) {
      map['senderId'] = Variable<String>(senderId.value);
    }
    if (senderName.present) {
      map['senderName'] = Variable<String>(senderName.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (sentAt.present) {
      map['sentAt'] = Variable<int>(sentAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ThreadMessagesCompanion(')
          ..write('id: $id, ')
          ..write('threadId: $threadId, ')
          ..write('senderId: $senderId, ')
          ..write('senderName: $senderName, ')
          ..write('body: $body, ')
          ..write('sentAt: $sentAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ThreadMetaTable extends ThreadMeta
    with TableInfo<$ThreadMetaTable, ThreadMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ThreadMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _threadIdMeta =
      const VerificationMeta('threadId');
  @override
  late final GeneratedColumn<String> threadId = GeneratedColumn<String>(
      'threadId', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _otherLastReadAtMeta =
      const VerificationMeta('otherLastReadAt');
  @override
  late final GeneratedColumn<int> otherLastReadAt = GeneratedColumn<int>(
      'otherLastReadAt', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _otherLastActiveAtMeta =
      const VerificationMeta('otherLastActiveAt');
  @override
  late final GeneratedColumn<int> otherLastActiveAt = GeneratedColumn<int>(
      'otherLastActiveAt', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [threadId, otherLastReadAt, otherLastActiveAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'thread_meta';
  @override
  VerificationContext validateIntegrity(Insertable<ThreadMetaData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('threadId')) {
      context.handle(_threadIdMeta,
          threadId.isAcceptableOrUnknown(data['threadId']!, _threadIdMeta));
    } else if (isInserting) {
      context.missing(_threadIdMeta);
    }
    if (data.containsKey('otherLastReadAt')) {
      context.handle(
          _otherLastReadAtMeta,
          otherLastReadAt.isAcceptableOrUnknown(
              data['otherLastReadAt']!, _otherLastReadAtMeta));
    }
    if (data.containsKey('otherLastActiveAt')) {
      context.handle(
          _otherLastActiveAtMeta,
          otherLastActiveAt.isAcceptableOrUnknown(
              data['otherLastActiveAt']!, _otherLastActiveAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {threadId};
  @override
  ThreadMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ThreadMetaData(
      threadId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}threadId'])!,
      otherLastReadAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}otherLastReadAt']),
      otherLastActiveAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}otherLastActiveAt']),
    );
  }

  @override
  $ThreadMetaTable createAlias(String alias) {
    return $ThreadMetaTable(attachedDatabase, alias);
  }
}

class ThreadMetaData extends DataClass implements Insertable<ThreadMetaData> {
  final String threadId;
  final int? otherLastReadAt;
  final int? otherLastActiveAt;
  const ThreadMetaData(
      {required this.threadId, this.otherLastReadAt, this.otherLastActiveAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['threadId'] = Variable<String>(threadId);
    if (!nullToAbsent || otherLastReadAt != null) {
      map['otherLastReadAt'] = Variable<int>(otherLastReadAt);
    }
    if (!nullToAbsent || otherLastActiveAt != null) {
      map['otherLastActiveAt'] = Variable<int>(otherLastActiveAt);
    }
    return map;
  }

  ThreadMetaCompanion toCompanion(bool nullToAbsent) {
    return ThreadMetaCompanion(
      threadId: Value(threadId),
      otherLastReadAt: otherLastReadAt == null && nullToAbsent
          ? const Value.absent()
          : Value(otherLastReadAt),
      otherLastActiveAt: otherLastActiveAt == null && nullToAbsent
          ? const Value.absent()
          : Value(otherLastActiveAt),
    );
  }

  factory ThreadMetaData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ThreadMetaData(
      threadId: serializer.fromJson<String>(json['threadId']),
      otherLastReadAt: serializer.fromJson<int?>(json['otherLastReadAt']),
      otherLastActiveAt: serializer.fromJson<int?>(json['otherLastActiveAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'threadId': serializer.toJson<String>(threadId),
      'otherLastReadAt': serializer.toJson<int?>(otherLastReadAt),
      'otherLastActiveAt': serializer.toJson<int?>(otherLastActiveAt),
    };
  }

  ThreadMetaData copyWith(
          {String? threadId,
          Value<int?> otherLastReadAt = const Value.absent(),
          Value<int?> otherLastActiveAt = const Value.absent()}) =>
      ThreadMetaData(
        threadId: threadId ?? this.threadId,
        otherLastReadAt: otherLastReadAt.present
            ? otherLastReadAt.value
            : this.otherLastReadAt,
        otherLastActiveAt: otherLastActiveAt.present
            ? otherLastActiveAt.value
            : this.otherLastActiveAt,
      );
  ThreadMetaData copyWithCompanion(ThreadMetaCompanion data) {
    return ThreadMetaData(
      threadId: data.threadId.present ? data.threadId.value : this.threadId,
      otherLastReadAt: data.otherLastReadAt.present
          ? data.otherLastReadAt.value
          : this.otherLastReadAt,
      otherLastActiveAt: data.otherLastActiveAt.present
          ? data.otherLastActiveAt.value
          : this.otherLastActiveAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ThreadMetaData(')
          ..write('threadId: $threadId, ')
          ..write('otherLastReadAt: $otherLastReadAt, ')
          ..write('otherLastActiveAt: $otherLastActiveAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(threadId, otherLastReadAt, otherLastActiveAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ThreadMetaData &&
          other.threadId == this.threadId &&
          other.otherLastReadAt == this.otherLastReadAt &&
          other.otherLastActiveAt == this.otherLastActiveAt);
}

class ThreadMetaCompanion extends UpdateCompanion<ThreadMetaData> {
  final Value<String> threadId;
  final Value<int?> otherLastReadAt;
  final Value<int?> otherLastActiveAt;
  final Value<int> rowid;
  const ThreadMetaCompanion({
    this.threadId = const Value.absent(),
    this.otherLastReadAt = const Value.absent(),
    this.otherLastActiveAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ThreadMetaCompanion.insert({
    required String threadId,
    this.otherLastReadAt = const Value.absent(),
    this.otherLastActiveAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : threadId = Value(threadId);
  static Insertable<ThreadMetaData> custom({
    Expression<String>? threadId,
    Expression<int>? otherLastReadAt,
    Expression<int>? otherLastActiveAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (threadId != null) 'threadId': threadId,
      if (otherLastReadAt != null) 'otherLastReadAt': otherLastReadAt,
      if (otherLastActiveAt != null) 'otherLastActiveAt': otherLastActiveAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ThreadMetaCompanion copyWith(
      {Value<String>? threadId,
      Value<int?>? otherLastReadAt,
      Value<int?>? otherLastActiveAt,
      Value<int>? rowid}) {
    return ThreadMetaCompanion(
      threadId: threadId ?? this.threadId,
      otherLastReadAt: otherLastReadAt ?? this.otherLastReadAt,
      otherLastActiveAt: otherLastActiveAt ?? this.otherLastActiveAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (threadId.present) {
      map['threadId'] = Variable<String>(threadId.value);
    }
    if (otherLastReadAt.present) {
      map['otherLastReadAt'] = Variable<int>(otherLastReadAt.value);
    }
    if (otherLastActiveAt.present) {
      map['otherLastActiveAt'] = Variable<int>(otherLastActiveAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ThreadMetaCompanion(')
          ..write('threadId: $threadId, ')
          ..write('otherLastReadAt: $otherLastReadAt, ')
          ..write('otherLastActiveAt: $otherLastActiveAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContactsTable extends Contacts
    with TableInfo<$ContactsTable, ContactRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'userId', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _avatarMeta = const VerificationMeta('avatar');
  @override
  late final GeneratedColumn<String> avatar = GeneratedColumn<String>(
      'avatar', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _studentsJsonMeta =
      const VerificationMeta('studentsJson');
  @override
  late final GeneratedColumn<String> studentsJson = GeneratedColumn<String>(
      'studentsJson', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sortIndexMeta =
      const VerificationMeta('sortIndex');
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
      'sortIndex', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [userId, name, avatar, role, studentsJson, sortIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contacts';
  @override
  VerificationContext validateIntegrity(Insertable<ContactRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('userId')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['userId']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('avatar')) {
      context.handle(_avatarMeta,
          avatar.isAcceptableOrUnknown(data['avatar']!, _avatarMeta));
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('studentsJson')) {
      context.handle(
          _studentsJsonMeta,
          studentsJson.isAcceptableOrUnknown(
              data['studentsJson']!, _studentsJsonMeta));
    } else if (isInserting) {
      context.missing(_studentsJsonMeta);
    }
    if (data.containsKey('sortIndex')) {
      context.handle(_sortIndexMeta,
          sortIndex.isAcceptableOrUnknown(data['sortIndex']!, _sortIndexMeta));
    } else if (isInserting) {
      context.missing(_sortIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  ContactRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContactRow(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}userId'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      avatar: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar']),
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      studentsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}studentsJson'])!,
      sortIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sortIndex'])!,
    );
  }

  @override
  $ContactsTable createAlias(String alias) {
    return $ContactsTable(attachedDatabase, alias);
  }
}

class ContactRow extends DataClass implements Insertable<ContactRow> {
  final String userId;
  final String name;
  final String? avatar;
  final String role;
  final String studentsJson;
  final int sortIndex;
  const ContactRow(
      {required this.userId,
      required this.name,
      this.avatar,
      required this.role,
      required this.studentsJson,
      required this.sortIndex});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['userId'] = Variable<String>(userId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || avatar != null) {
      map['avatar'] = Variable<String>(avatar);
    }
    map['role'] = Variable<String>(role);
    map['studentsJson'] = Variable<String>(studentsJson);
    map['sortIndex'] = Variable<int>(sortIndex);
    return map;
  }

  ContactsCompanion toCompanion(bool nullToAbsent) {
    return ContactsCompanion(
      userId: Value(userId),
      name: Value(name),
      avatar:
          avatar == null && nullToAbsent ? const Value.absent() : Value(avatar),
      role: Value(role),
      studentsJson: Value(studentsJson),
      sortIndex: Value(sortIndex),
    );
  }

  factory ContactRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContactRow(
      userId: serializer.fromJson<String>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      avatar: serializer.fromJson<String?>(json['avatar']),
      role: serializer.fromJson<String>(json['role']),
      studentsJson: serializer.fromJson<String>(json['studentsJson']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'name': serializer.toJson<String>(name),
      'avatar': serializer.toJson<String?>(avatar),
      'role': serializer.toJson<String>(role),
      'studentsJson': serializer.toJson<String>(studentsJson),
      'sortIndex': serializer.toJson<int>(sortIndex),
    };
  }

  ContactRow copyWith(
          {String? userId,
          String? name,
          Value<String?> avatar = const Value.absent(),
          String? role,
          String? studentsJson,
          int? sortIndex}) =>
      ContactRow(
        userId: userId ?? this.userId,
        name: name ?? this.name,
        avatar: avatar.present ? avatar.value : this.avatar,
        role: role ?? this.role,
        studentsJson: studentsJson ?? this.studentsJson,
        sortIndex: sortIndex ?? this.sortIndex,
      );
  ContactRow copyWithCompanion(ContactsCompanion data) {
    return ContactRow(
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      avatar: data.avatar.present ? data.avatar.value : this.avatar,
      role: data.role.present ? data.role.value : this.role,
      studentsJson: data.studentsJson.present
          ? data.studentsJson.value
          : this.studentsJson,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContactRow(')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('avatar: $avatar, ')
          ..write('role: $role, ')
          ..write('studentsJson: $studentsJson, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(userId, name, avatar, role, studentsJson, sortIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContactRow &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.avatar == this.avatar &&
          other.role == this.role &&
          other.studentsJson == this.studentsJson &&
          other.sortIndex == this.sortIndex);
}

class ContactsCompanion extends UpdateCompanion<ContactRow> {
  final Value<String> userId;
  final Value<String> name;
  final Value<String?> avatar;
  final Value<String> role;
  final Value<String> studentsJson;
  final Value<int> sortIndex;
  final Value<int> rowid;
  const ContactsCompanion({
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.avatar = const Value.absent(),
    this.role = const Value.absent(),
    this.studentsJson = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactsCompanion.insert({
    required String userId,
    required String name,
    this.avatar = const Value.absent(),
    required String role,
    required String studentsJson,
    required int sortIndex,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        name = Value(name),
        role = Value(role),
        studentsJson = Value(studentsJson),
        sortIndex = Value(sortIndex);
  static Insertable<ContactRow> custom({
    Expression<String>? userId,
    Expression<String>? name,
    Expression<String>? avatar,
    Expression<String>? role,
    Expression<String>? studentsJson,
    Expression<int>? sortIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'userId': userId,
      if (name != null) 'name': name,
      if (avatar != null) 'avatar': avatar,
      if (role != null) 'role': role,
      if (studentsJson != null) 'studentsJson': studentsJson,
      if (sortIndex != null) 'sortIndex': sortIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactsCompanion copyWith(
      {Value<String>? userId,
      Value<String>? name,
      Value<String?>? avatar,
      Value<String>? role,
      Value<String>? studentsJson,
      Value<int>? sortIndex,
      Value<int>? rowid}) {
    return ContactsCompanion(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      role: role ?? this.role,
      studentsJson: studentsJson ?? this.studentsJson,
      sortIndex: sortIndex ?? this.sortIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['userId'] = Variable<String>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (avatar.present) {
      map['avatar'] = Variable<String>(avatar.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (studentsJson.present) {
      map['studentsJson'] = Variable<String>(studentsJson.value);
    }
    if (sortIndex.present) {
      map['sortIndex'] = Variable<int>(sortIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactsCompanion(')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('avatar: $avatar, ')
          ..write('role: $role, ')
          ..write('studentsJson: $studentsJson, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ThreadsDriftDb extends GeneratedDatabase {
  _$ThreadsDriftDb(QueryExecutor e) : super(e);
  $ThreadsDriftDbManager get managers => $ThreadsDriftDbManager(this);
  late final $InboxThreadsTable inboxThreads = $InboxThreadsTable(this);
  late final $ThreadMessagesTable threadMessages = $ThreadMessagesTable(this);
  late final $ThreadMetaTable threadMeta = $ThreadMetaTable(this);
  late final $ContactsTable contacts = $ContactsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [inboxThreads, threadMessages, threadMeta, contacts];
}

typedef $$InboxThreadsTableCreateCompanionBuilder = InboxThreadsCompanion
    Function({
  required String id,
  required String kind,
  Value<String?> subject,
  Value<String?> studentId,
  Value<String?> studentName,
  required String priority,
  required int lastMessageAt,
  required bool unread,
  required int unreadCount,
  required bool muted,
  Value<String?> otherId,
  Value<String?> otherName,
  Value<String?> otherAvatar,
  Value<bool?> otherOnline,
  Value<String?> lastMsgBody,
  Value<String?> lastMsgSenderId,
  Value<int?> lastMsgSentAt,
  Value<bool?> lastMsgDelivered,
  required int sortIndex,
  Value<int> rowid,
});
typedef $$InboxThreadsTableUpdateCompanionBuilder = InboxThreadsCompanion
    Function({
  Value<String> id,
  Value<String> kind,
  Value<String?> subject,
  Value<String?> studentId,
  Value<String?> studentName,
  Value<String> priority,
  Value<int> lastMessageAt,
  Value<bool> unread,
  Value<int> unreadCount,
  Value<bool> muted,
  Value<String?> otherId,
  Value<String?> otherName,
  Value<String?> otherAvatar,
  Value<bool?> otherOnline,
  Value<String?> lastMsgBody,
  Value<String?> lastMsgSenderId,
  Value<int?> lastMsgSentAt,
  Value<bool?> lastMsgDelivered,
  Value<int> sortIndex,
  Value<int> rowid,
});

class $$InboxThreadsTableFilterComposer
    extends Composer<_$ThreadsDriftDb, $InboxThreadsTable> {
  $$InboxThreadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subject => $composableBuilder(
      column: $table.subject, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get studentId => $composableBuilder(
      column: $table.studentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get studentName => $composableBuilder(
      column: $table.studentName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastMessageAt => $composableBuilder(
      column: $table.lastMessageAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get unread => $composableBuilder(
      column: $table.unread, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get muted => $composableBuilder(
      column: $table.muted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get otherId => $composableBuilder(
      column: $table.otherId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get otherName => $composableBuilder(
      column: $table.otherName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get otherAvatar => $composableBuilder(
      column: $table.otherAvatar, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get otherOnline => $composableBuilder(
      column: $table.otherOnline, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastMsgBody => $composableBuilder(
      column: $table.lastMsgBody, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastMsgSenderId => $composableBuilder(
      column: $table.lastMsgSenderId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastMsgSentAt => $composableBuilder(
      column: $table.lastMsgSentAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get lastMsgDelivered => $composableBuilder(
      column: $table.lastMsgDelivered,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortIndex => $composableBuilder(
      column: $table.sortIndex, builder: (column) => ColumnFilters(column));
}

class $$InboxThreadsTableOrderingComposer
    extends Composer<_$ThreadsDriftDb, $InboxThreadsTable> {
  $$InboxThreadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subject => $composableBuilder(
      column: $table.subject, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get studentId => $composableBuilder(
      column: $table.studentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get studentName => $composableBuilder(
      column: $table.studentName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastMessageAt => $composableBuilder(
      column: $table.lastMessageAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get unread => $composableBuilder(
      column: $table.unread, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get muted => $composableBuilder(
      column: $table.muted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get otherId => $composableBuilder(
      column: $table.otherId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get otherName => $composableBuilder(
      column: $table.otherName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get otherAvatar => $composableBuilder(
      column: $table.otherAvatar, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get otherOnline => $composableBuilder(
      column: $table.otherOnline, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastMsgBody => $composableBuilder(
      column: $table.lastMsgBody, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastMsgSenderId => $composableBuilder(
      column: $table.lastMsgSenderId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastMsgSentAt => $composableBuilder(
      column: $table.lastMsgSentAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get lastMsgDelivered => $composableBuilder(
      column: $table.lastMsgDelivered,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortIndex => $composableBuilder(
      column: $table.sortIndex, builder: (column) => ColumnOrderings(column));
}

class $$InboxThreadsTableAnnotationComposer
    extends Composer<_$ThreadsDriftDb, $InboxThreadsTable> {
  $$InboxThreadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get studentId =>
      $composableBuilder(column: $table.studentId, builder: (column) => column);

  GeneratedColumn<String> get studentName => $composableBuilder(
      column: $table.studentName, builder: (column) => column);

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get lastMessageAt => $composableBuilder(
      column: $table.lastMessageAt, builder: (column) => column);

  GeneratedColumn<bool> get unread =>
      $composableBuilder(column: $table.unread, builder: (column) => column);

  GeneratedColumn<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => column);

  GeneratedColumn<bool> get muted =>
      $composableBuilder(column: $table.muted, builder: (column) => column);

  GeneratedColumn<String> get otherId =>
      $composableBuilder(column: $table.otherId, builder: (column) => column);

  GeneratedColumn<String> get otherName =>
      $composableBuilder(column: $table.otherName, builder: (column) => column);

  GeneratedColumn<String> get otherAvatar => $composableBuilder(
      column: $table.otherAvatar, builder: (column) => column);

  GeneratedColumn<bool> get otherOnline => $composableBuilder(
      column: $table.otherOnline, builder: (column) => column);

  GeneratedColumn<String> get lastMsgBody => $composableBuilder(
      column: $table.lastMsgBody, builder: (column) => column);

  GeneratedColumn<String> get lastMsgSenderId => $composableBuilder(
      column: $table.lastMsgSenderId, builder: (column) => column);

  GeneratedColumn<int> get lastMsgSentAt => $composableBuilder(
      column: $table.lastMsgSentAt, builder: (column) => column);

  GeneratedColumn<bool> get lastMsgDelivered => $composableBuilder(
      column: $table.lastMsgDelivered, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);
}

class $$InboxThreadsTableTableManager extends RootTableManager<
    _$ThreadsDriftDb,
    $InboxThreadsTable,
    InboxThread,
    $$InboxThreadsTableFilterComposer,
    $$InboxThreadsTableOrderingComposer,
    $$InboxThreadsTableAnnotationComposer,
    $$InboxThreadsTableCreateCompanionBuilder,
    $$InboxThreadsTableUpdateCompanionBuilder,
    (
      InboxThread,
      BaseReferences<_$ThreadsDriftDb, $InboxThreadsTable, InboxThread>
    ),
    InboxThread,
    PrefetchHooks Function()> {
  $$InboxThreadsTableTableManager(_$ThreadsDriftDb db, $InboxThreadsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InboxThreadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InboxThreadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InboxThreadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String?> subject = const Value.absent(),
            Value<String?> studentId = const Value.absent(),
            Value<String?> studentName = const Value.absent(),
            Value<String> priority = const Value.absent(),
            Value<int> lastMessageAt = const Value.absent(),
            Value<bool> unread = const Value.absent(),
            Value<int> unreadCount = const Value.absent(),
            Value<bool> muted = const Value.absent(),
            Value<String?> otherId = const Value.absent(),
            Value<String?> otherName = const Value.absent(),
            Value<String?> otherAvatar = const Value.absent(),
            Value<bool?> otherOnline = const Value.absent(),
            Value<String?> lastMsgBody = const Value.absent(),
            Value<String?> lastMsgSenderId = const Value.absent(),
            Value<int?> lastMsgSentAt = const Value.absent(),
            Value<bool?> lastMsgDelivered = const Value.absent(),
            Value<int> sortIndex = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InboxThreadsCompanion(
            id: id,
            kind: kind,
            subject: subject,
            studentId: studentId,
            studentName: studentName,
            priority: priority,
            lastMessageAt: lastMessageAt,
            unread: unread,
            unreadCount: unreadCount,
            muted: muted,
            otherId: otherId,
            otherName: otherName,
            otherAvatar: otherAvatar,
            otherOnline: otherOnline,
            lastMsgBody: lastMsgBody,
            lastMsgSenderId: lastMsgSenderId,
            lastMsgSentAt: lastMsgSentAt,
            lastMsgDelivered: lastMsgDelivered,
            sortIndex: sortIndex,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String kind,
            Value<String?> subject = const Value.absent(),
            Value<String?> studentId = const Value.absent(),
            Value<String?> studentName = const Value.absent(),
            required String priority,
            required int lastMessageAt,
            required bool unread,
            required int unreadCount,
            required bool muted,
            Value<String?> otherId = const Value.absent(),
            Value<String?> otherName = const Value.absent(),
            Value<String?> otherAvatar = const Value.absent(),
            Value<bool?> otherOnline = const Value.absent(),
            Value<String?> lastMsgBody = const Value.absent(),
            Value<String?> lastMsgSenderId = const Value.absent(),
            Value<int?> lastMsgSentAt = const Value.absent(),
            Value<bool?> lastMsgDelivered = const Value.absent(),
            required int sortIndex,
            Value<int> rowid = const Value.absent(),
          }) =>
              InboxThreadsCompanion.insert(
            id: id,
            kind: kind,
            subject: subject,
            studentId: studentId,
            studentName: studentName,
            priority: priority,
            lastMessageAt: lastMessageAt,
            unread: unread,
            unreadCount: unreadCount,
            muted: muted,
            otherId: otherId,
            otherName: otherName,
            otherAvatar: otherAvatar,
            otherOnline: otherOnline,
            lastMsgBody: lastMsgBody,
            lastMsgSenderId: lastMsgSenderId,
            lastMsgSentAt: lastMsgSentAt,
            lastMsgDelivered: lastMsgDelivered,
            sortIndex: sortIndex,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$InboxThreadsTableProcessedTableManager = ProcessedTableManager<
    _$ThreadsDriftDb,
    $InboxThreadsTable,
    InboxThread,
    $$InboxThreadsTableFilterComposer,
    $$InboxThreadsTableOrderingComposer,
    $$InboxThreadsTableAnnotationComposer,
    $$InboxThreadsTableCreateCompanionBuilder,
    $$InboxThreadsTableUpdateCompanionBuilder,
    (
      InboxThread,
      BaseReferences<_$ThreadsDriftDb, $InboxThreadsTable, InboxThread>
    ),
    InboxThread,
    PrefetchHooks Function()>;
typedef $$ThreadMessagesTableCreateCompanionBuilder = ThreadMessagesCompanion
    Function({
  required String id,
  required String threadId,
  required String senderId,
  required String senderName,
  required String body,
  required int sentAt,
  Value<int> rowid,
});
typedef $$ThreadMessagesTableUpdateCompanionBuilder = ThreadMessagesCompanion
    Function({
  Value<String> id,
  Value<String> threadId,
  Value<String> senderId,
  Value<String> senderName,
  Value<String> body,
  Value<int> sentAt,
  Value<int> rowid,
});

class $$ThreadMessagesTableFilterComposer
    extends Composer<_$ThreadsDriftDb, $ThreadMessagesTable> {
  $$ThreadMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get threadId => $composableBuilder(
      column: $table.threadId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sentAt => $composableBuilder(
      column: $table.sentAt, builder: (column) => ColumnFilters(column));
}

class $$ThreadMessagesTableOrderingComposer
    extends Composer<_$ThreadsDriftDb, $ThreadMessagesTable> {
  $$ThreadMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get threadId => $composableBuilder(
      column: $table.threadId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sentAt => $composableBuilder(
      column: $table.sentAt, builder: (column) => ColumnOrderings(column));
}

class $$ThreadMessagesTableAnnotationComposer
    extends Composer<_$ThreadsDriftDb, $ThreadMessagesTable> {
  $$ThreadMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get threadId =>
      $composableBuilder(column: $table.threadId, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);
}

class $$ThreadMessagesTableTableManager extends RootTableManager<
    _$ThreadsDriftDb,
    $ThreadMessagesTable,
    ThreadMessageRow,
    $$ThreadMessagesTableFilterComposer,
    $$ThreadMessagesTableOrderingComposer,
    $$ThreadMessagesTableAnnotationComposer,
    $$ThreadMessagesTableCreateCompanionBuilder,
    $$ThreadMessagesTableUpdateCompanionBuilder,
    (
      ThreadMessageRow,
      BaseReferences<_$ThreadsDriftDb, $ThreadMessagesTable, ThreadMessageRow>
    ),
    ThreadMessageRow,
    PrefetchHooks Function()> {
  $$ThreadMessagesTableTableManager(
      _$ThreadsDriftDb db, $ThreadMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ThreadMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ThreadMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ThreadMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> threadId = const Value.absent(),
            Value<String> senderId = const Value.absent(),
            Value<String> senderName = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<int> sentAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ThreadMessagesCompanion(
            id: id,
            threadId: threadId,
            senderId: senderId,
            senderName: senderName,
            body: body,
            sentAt: sentAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String threadId,
            required String senderId,
            required String senderName,
            required String body,
            required int sentAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ThreadMessagesCompanion.insert(
            id: id,
            threadId: threadId,
            senderId: senderId,
            senderName: senderName,
            body: body,
            sentAt: sentAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ThreadMessagesTableProcessedTableManager = ProcessedTableManager<
    _$ThreadsDriftDb,
    $ThreadMessagesTable,
    ThreadMessageRow,
    $$ThreadMessagesTableFilterComposer,
    $$ThreadMessagesTableOrderingComposer,
    $$ThreadMessagesTableAnnotationComposer,
    $$ThreadMessagesTableCreateCompanionBuilder,
    $$ThreadMessagesTableUpdateCompanionBuilder,
    (
      ThreadMessageRow,
      BaseReferences<_$ThreadsDriftDb, $ThreadMessagesTable, ThreadMessageRow>
    ),
    ThreadMessageRow,
    PrefetchHooks Function()>;
typedef $$ThreadMetaTableCreateCompanionBuilder = ThreadMetaCompanion Function({
  required String threadId,
  Value<int?> otherLastReadAt,
  Value<int?> otherLastActiveAt,
  Value<int> rowid,
});
typedef $$ThreadMetaTableUpdateCompanionBuilder = ThreadMetaCompanion Function({
  Value<String> threadId,
  Value<int?> otherLastReadAt,
  Value<int?> otherLastActiveAt,
  Value<int> rowid,
});

class $$ThreadMetaTableFilterComposer
    extends Composer<_$ThreadsDriftDb, $ThreadMetaTable> {
  $$ThreadMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get threadId => $composableBuilder(
      column: $table.threadId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get otherLastReadAt => $composableBuilder(
      column: $table.otherLastReadAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get otherLastActiveAt => $composableBuilder(
      column: $table.otherLastActiveAt,
      builder: (column) => ColumnFilters(column));
}

class $$ThreadMetaTableOrderingComposer
    extends Composer<_$ThreadsDriftDb, $ThreadMetaTable> {
  $$ThreadMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get threadId => $composableBuilder(
      column: $table.threadId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get otherLastReadAt => $composableBuilder(
      column: $table.otherLastReadAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get otherLastActiveAt => $composableBuilder(
      column: $table.otherLastActiveAt,
      builder: (column) => ColumnOrderings(column));
}

class $$ThreadMetaTableAnnotationComposer
    extends Composer<_$ThreadsDriftDb, $ThreadMetaTable> {
  $$ThreadMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get threadId =>
      $composableBuilder(column: $table.threadId, builder: (column) => column);

  GeneratedColumn<int> get otherLastReadAt => $composableBuilder(
      column: $table.otherLastReadAt, builder: (column) => column);

  GeneratedColumn<int> get otherLastActiveAt => $composableBuilder(
      column: $table.otherLastActiveAt, builder: (column) => column);
}

class $$ThreadMetaTableTableManager extends RootTableManager<
    _$ThreadsDriftDb,
    $ThreadMetaTable,
    ThreadMetaData,
    $$ThreadMetaTableFilterComposer,
    $$ThreadMetaTableOrderingComposer,
    $$ThreadMetaTableAnnotationComposer,
    $$ThreadMetaTableCreateCompanionBuilder,
    $$ThreadMetaTableUpdateCompanionBuilder,
    (
      ThreadMetaData,
      BaseReferences<_$ThreadsDriftDb, $ThreadMetaTable, ThreadMetaData>
    ),
    ThreadMetaData,
    PrefetchHooks Function()> {
  $$ThreadMetaTableTableManager(_$ThreadsDriftDb db, $ThreadMetaTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ThreadMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ThreadMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ThreadMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> threadId = const Value.absent(),
            Value<int?> otherLastReadAt = const Value.absent(),
            Value<int?> otherLastActiveAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ThreadMetaCompanion(
            threadId: threadId,
            otherLastReadAt: otherLastReadAt,
            otherLastActiveAt: otherLastActiveAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String threadId,
            Value<int?> otherLastReadAt = const Value.absent(),
            Value<int?> otherLastActiveAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ThreadMetaCompanion.insert(
            threadId: threadId,
            otherLastReadAt: otherLastReadAt,
            otherLastActiveAt: otherLastActiveAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ThreadMetaTableProcessedTableManager = ProcessedTableManager<
    _$ThreadsDriftDb,
    $ThreadMetaTable,
    ThreadMetaData,
    $$ThreadMetaTableFilterComposer,
    $$ThreadMetaTableOrderingComposer,
    $$ThreadMetaTableAnnotationComposer,
    $$ThreadMetaTableCreateCompanionBuilder,
    $$ThreadMetaTableUpdateCompanionBuilder,
    (
      ThreadMetaData,
      BaseReferences<_$ThreadsDriftDb, $ThreadMetaTable, ThreadMetaData>
    ),
    ThreadMetaData,
    PrefetchHooks Function()>;
typedef $$ContactsTableCreateCompanionBuilder = ContactsCompanion Function({
  required String userId,
  required String name,
  Value<String?> avatar,
  required String role,
  required String studentsJson,
  required int sortIndex,
  Value<int> rowid,
});
typedef $$ContactsTableUpdateCompanionBuilder = ContactsCompanion Function({
  Value<String> userId,
  Value<String> name,
  Value<String?> avatar,
  Value<String> role,
  Value<String> studentsJson,
  Value<int> sortIndex,
  Value<int> rowid,
});

class $$ContactsTableFilterComposer
    extends Composer<_$ThreadsDriftDb, $ContactsTable> {
  $$ContactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatar => $composableBuilder(
      column: $table.avatar, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get studentsJson => $composableBuilder(
      column: $table.studentsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortIndex => $composableBuilder(
      column: $table.sortIndex, builder: (column) => ColumnFilters(column));
}

class $$ContactsTableOrderingComposer
    extends Composer<_$ThreadsDriftDb, $ContactsTable> {
  $$ContactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatar => $composableBuilder(
      column: $table.avatar, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get studentsJson => $composableBuilder(
      column: $table.studentsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortIndex => $composableBuilder(
      column: $table.sortIndex, builder: (column) => ColumnOrderings(column));
}

class $$ContactsTableAnnotationComposer
    extends Composer<_$ThreadsDriftDb, $ContactsTable> {
  $$ContactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get avatar =>
      $composableBuilder(column: $table.avatar, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get studentsJson => $composableBuilder(
      column: $table.studentsJson, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);
}

class $$ContactsTableTableManager extends RootTableManager<
    _$ThreadsDriftDb,
    $ContactsTable,
    ContactRow,
    $$ContactsTableFilterComposer,
    $$ContactsTableOrderingComposer,
    $$ContactsTableAnnotationComposer,
    $$ContactsTableCreateCompanionBuilder,
    $$ContactsTableUpdateCompanionBuilder,
    (ContactRow, BaseReferences<_$ThreadsDriftDb, $ContactsTable, ContactRow>),
    ContactRow,
    PrefetchHooks Function()> {
  $$ContactsTableTableManager(_$ThreadsDriftDb db, $ContactsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> avatar = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<String> studentsJson = const Value.absent(),
            Value<int> sortIndex = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ContactsCompanion(
            userId: userId,
            name: name,
            avatar: avatar,
            role: role,
            studentsJson: studentsJson,
            sortIndex: sortIndex,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String name,
            Value<String?> avatar = const Value.absent(),
            required String role,
            required String studentsJson,
            required int sortIndex,
            Value<int> rowid = const Value.absent(),
          }) =>
              ContactsCompanion.insert(
            userId: userId,
            name: name,
            avatar: avatar,
            role: role,
            studentsJson: studentsJson,
            sortIndex: sortIndex,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ContactsTableProcessedTableManager = ProcessedTableManager<
    _$ThreadsDriftDb,
    $ContactsTable,
    ContactRow,
    $$ContactsTableFilterComposer,
    $$ContactsTableOrderingComposer,
    $$ContactsTableAnnotationComposer,
    $$ContactsTableCreateCompanionBuilder,
    $$ContactsTableUpdateCompanionBuilder,
    (ContactRow, BaseReferences<_$ThreadsDriftDb, $ContactsTable, ContactRow>),
    ContactRow,
    PrefetchHooks Function()>;

class $ThreadsDriftDbManager {
  final _$ThreadsDriftDb _db;
  $ThreadsDriftDbManager(this._db);
  $$InboxThreadsTableTableManager get inboxThreads =>
      $$InboxThreadsTableTableManager(_db, _db.inboxThreads);
  $$ThreadMessagesTableTableManager get threadMessages =>
      $$ThreadMessagesTableTableManager(_db, _db.threadMessages);
  $$ThreadMetaTableTableManager get threadMeta =>
      $$ThreadMetaTableTableManager(_db, _db.threadMeta);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db, _db.contacts);
}
