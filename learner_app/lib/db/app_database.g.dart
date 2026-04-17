// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LearnerProfilesTable extends LearnerProfiles
    with TableInfo<$LearnerProfilesTable, LearnerProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearnerProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homeLanguageCodeMeta = const VerificationMeta(
    'homeLanguageCode',
  );
  @override
  late final GeneratedColumn<String> homeLanguageCode = GeneratedColumn<String>(
    'home_language_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pairedTeacherCodeMeta = const VerificationMeta(
    'pairedTeacherCode',
  );
  @override
  late final GeneratedColumn<String> pairedTeacherCode =
      GeneratedColumn<String>(
        'paired_teacher_code',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    homeLanguageCode,
    pairedTeacherCode,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learner_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearnerProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('home_language_code')) {
      context.handle(
        _homeLanguageCodeMeta,
        homeLanguageCode.isAcceptableOrUnknown(
          data['home_language_code']!,
          _homeLanguageCodeMeta,
        ),
      );
    }
    if (data.containsKey('paired_teacher_code')) {
      context.handle(
        _pairedTeacherCodeMeta,
        pairedTeacherCode.isAcceptableOrUnknown(
          data['paired_teacher_code']!,
          _pairedTeacherCodeMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LearnerProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearnerProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      homeLanguageCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_language_code'],
      ),
      pairedTeacherCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paired_teacher_code'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LearnerProfilesTable createAlias(String alias) {
    return $LearnerProfilesTable(attachedDatabase, alias);
  }
}

class LearnerProfile extends DataClass implements Insertable<LearnerProfile> {
  final String id;
  final String displayName;
  final String? homeLanguageCode;
  final String? pairedTeacherCode;
  final DateTime createdAt;
  const LearnerProfile({
    required this.id,
    required this.displayName,
    this.homeLanguageCode,
    this.pairedTeacherCode,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || homeLanguageCode != null) {
      map['home_language_code'] = Variable<String>(homeLanguageCode);
    }
    if (!nullToAbsent || pairedTeacherCode != null) {
      map['paired_teacher_code'] = Variable<String>(pairedTeacherCode);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LearnerProfilesCompanion toCompanion(bool nullToAbsent) {
    return LearnerProfilesCompanion(
      id: Value(id),
      displayName: Value(displayName),
      homeLanguageCode: homeLanguageCode == null && nullToAbsent
          ? const Value.absent()
          : Value(homeLanguageCode),
      pairedTeacherCode: pairedTeacherCode == null && nullToAbsent
          ? const Value.absent()
          : Value(pairedTeacherCode),
      createdAt: Value(createdAt),
    );
  }

  factory LearnerProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearnerProfile(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      homeLanguageCode: serializer.fromJson<String?>(json['homeLanguageCode']),
      pairedTeacherCode: serializer.fromJson<String?>(
        json['pairedTeacherCode'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'homeLanguageCode': serializer.toJson<String?>(homeLanguageCode),
      'pairedTeacherCode': serializer.toJson<String?>(pairedTeacherCode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LearnerProfile copyWith({
    String? id,
    String? displayName,
    Value<String?> homeLanguageCode = const Value.absent(),
    Value<String?> pairedTeacherCode = const Value.absent(),
    DateTime? createdAt,
  }) => LearnerProfile(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    homeLanguageCode: homeLanguageCode.present
        ? homeLanguageCode.value
        : this.homeLanguageCode,
    pairedTeacherCode: pairedTeacherCode.present
        ? pairedTeacherCode.value
        : this.pairedTeacherCode,
    createdAt: createdAt ?? this.createdAt,
  );
  LearnerProfile copyWithCompanion(LearnerProfilesCompanion data) {
    return LearnerProfile(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      homeLanguageCode: data.homeLanguageCode.present
          ? data.homeLanguageCode.value
          : this.homeLanguageCode,
      pairedTeacherCode: data.pairedTeacherCode.present
          ? data.pairedTeacherCode.value
          : this.pairedTeacherCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearnerProfile(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('homeLanguageCode: $homeLanguageCode, ')
          ..write('pairedTeacherCode: $pairedTeacherCode, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    homeLanguageCode,
    pairedTeacherCode,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearnerProfile &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.homeLanguageCode == this.homeLanguageCode &&
          other.pairedTeacherCode == this.pairedTeacherCode &&
          other.createdAt == this.createdAt);
}

class LearnerProfilesCompanion extends UpdateCompanion<LearnerProfile> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String?> homeLanguageCode;
  final Value<String?> pairedTeacherCode;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LearnerProfilesCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.homeLanguageCode = const Value.absent(),
    this.pairedTeacherCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearnerProfilesCompanion.insert({
    required String id,
    required String displayName,
    this.homeLanguageCode = const Value.absent(),
    this.pairedTeacherCode = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       displayName = Value(displayName),
       createdAt = Value(createdAt);
  static Insertable<LearnerProfile> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? homeLanguageCode,
    Expression<String>? pairedTeacherCode,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (homeLanguageCode != null) 'home_language_code': homeLanguageCode,
      if (pairedTeacherCode != null) 'paired_teacher_code': pairedTeacherCode,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearnerProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? displayName,
    Value<String?>? homeLanguageCode,
    Value<String?>? pairedTeacherCode,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LearnerProfilesCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      homeLanguageCode: homeLanguageCode ?? this.homeLanguageCode,
      pairedTeacherCode: pairedTeacherCode ?? this.pairedTeacherCode,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (homeLanguageCode.present) {
      map['home_language_code'] = Variable<String>(homeLanguageCode.value);
    }
    if (pairedTeacherCode.present) {
      map['paired_teacher_code'] = Variable<String>(pairedTeacherCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearnerProfilesCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('homeLanguageCode: $homeLanguageCode, ')
          ..write('pairedTeacherCode: $pairedTeacherCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuestsTable extends Quests with TableInfo<$QuestsTable, Quest> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topicMeta = const VerificationMeta('topic');
  @override
  late final GeneratedColumn<String> topic = GeneratedColumn<String>(
    'topic',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxDifficultyStepMeta = const VerificationMeta(
    'maxDifficultyStep',
  );
  @override
  late final GeneratedColumn<int> maxDifficultyStep = GeneratedColumn<int>(
    'max_difficulty_step',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionTimeLimitSecMeta =
      const VerificationMeta('sessionTimeLimitSec');
  @override
  late final GeneratedColumn<int> sessionTimeLimitSec = GeneratedColumn<int>(
    'session_time_limit_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxTasksMeta = const VerificationMeta(
    'maxTasks',
  );
  @override
  late final GeneratedColumn<int> maxTasks = GeneratedColumn<int>(
    'max_tasks',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startsAtMeta = const VerificationMeta(
    'startsAt',
  );
  @override
  late final GeneratedColumn<DateTime> startsAt = GeneratedColumn<DateTime>(
    'starts_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endsAtMeta = const VerificationMeta('endsAt');
  @override
  late final GeneratedColumn<DateTime> endsAt = GeneratedColumn<DateTime>(
    'ends_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    topic,
    level,
    maxDifficultyStep,
    sessionTimeLimitSec,
    maxTasks,
    startsAt,
    endsAt,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quests';
  @override
  VerificationContext validateIntegrity(
    Insertable<Quest> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('topic')) {
      context.handle(
        _topicMeta,
        topic.isAcceptableOrUnknown(data['topic']!, _topicMeta),
      );
    } else if (isInserting) {
      context.missing(_topicMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('max_difficulty_step')) {
      context.handle(
        _maxDifficultyStepMeta,
        maxDifficultyStep.isAcceptableOrUnknown(
          data['max_difficulty_step']!,
          _maxDifficultyStepMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_maxDifficultyStepMeta);
    }
    if (data.containsKey('session_time_limit_sec')) {
      context.handle(
        _sessionTimeLimitSecMeta,
        sessionTimeLimitSec.isAcceptableOrUnknown(
          data['session_time_limit_sec']!,
          _sessionTimeLimitSecMeta,
        ),
      );
    }
    if (data.containsKey('max_tasks')) {
      context.handle(
        _maxTasksMeta,
        maxTasks.isAcceptableOrUnknown(data['max_tasks']!, _maxTasksMeta),
      );
    }
    if (data.containsKey('starts_at')) {
      context.handle(
        _startsAtMeta,
        startsAt.isAcceptableOrUnknown(data['starts_at']!, _startsAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startsAtMeta);
    }
    if (data.containsKey('ends_at')) {
      context.handle(
        _endsAtMeta,
        endsAt.isAcceptableOrUnknown(data['ends_at']!, _endsAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endsAtMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Quest map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Quest(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      topic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      )!,
      maxDifficultyStep: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_difficulty_step'],
      )!,
      sessionTimeLimitSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_time_limit_sec'],
      ),
      maxTasks: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_tasks'],
      ),
      startsAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}starts_at'],
      )!,
      endsAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ends_at'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $QuestsTable createAlias(String alias) {
    return $QuestsTable(attachedDatabase, alias);
  }
}

class Quest extends DataClass implements Insertable<Quest> {
  final String id;
  final String topic;
  final String level;
  final int maxDifficultyStep;
  final int? sessionTimeLimitSec;
  final int? maxTasks;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isActive;
  const Quest({
    required this.id,
    required this.topic,
    required this.level,
    required this.maxDifficultyStep,
    this.sessionTimeLimitSec,
    this.maxTasks,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['topic'] = Variable<String>(topic);
    map['level'] = Variable<String>(level);
    map['max_difficulty_step'] = Variable<int>(maxDifficultyStep);
    if (!nullToAbsent || sessionTimeLimitSec != null) {
      map['session_time_limit_sec'] = Variable<int>(sessionTimeLimitSec);
    }
    if (!nullToAbsent || maxTasks != null) {
      map['max_tasks'] = Variable<int>(maxTasks);
    }
    map['starts_at'] = Variable<DateTime>(startsAt);
    map['ends_at'] = Variable<DateTime>(endsAt);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  QuestsCompanion toCompanion(bool nullToAbsent) {
    return QuestsCompanion(
      id: Value(id),
      topic: Value(topic),
      level: Value(level),
      maxDifficultyStep: Value(maxDifficultyStep),
      sessionTimeLimitSec: sessionTimeLimitSec == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionTimeLimitSec),
      maxTasks: maxTasks == null && nullToAbsent
          ? const Value.absent()
          : Value(maxTasks),
      startsAt: Value(startsAt),
      endsAt: Value(endsAt),
      isActive: Value(isActive),
    );
  }

  factory Quest.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Quest(
      id: serializer.fromJson<String>(json['id']),
      topic: serializer.fromJson<String>(json['topic']),
      level: serializer.fromJson<String>(json['level']),
      maxDifficultyStep: serializer.fromJson<int>(json['maxDifficultyStep']),
      sessionTimeLimitSec: serializer.fromJson<int?>(
        json['sessionTimeLimitSec'],
      ),
      maxTasks: serializer.fromJson<int?>(json['maxTasks']),
      startsAt: serializer.fromJson<DateTime>(json['startsAt']),
      endsAt: serializer.fromJson<DateTime>(json['endsAt']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'topic': serializer.toJson<String>(topic),
      'level': serializer.toJson<String>(level),
      'maxDifficultyStep': serializer.toJson<int>(maxDifficultyStep),
      'sessionTimeLimitSec': serializer.toJson<int?>(sessionTimeLimitSec),
      'maxTasks': serializer.toJson<int?>(maxTasks),
      'startsAt': serializer.toJson<DateTime>(startsAt),
      'endsAt': serializer.toJson<DateTime>(endsAt),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Quest copyWith({
    String? id,
    String? topic,
    String? level,
    int? maxDifficultyStep,
    Value<int?> sessionTimeLimitSec = const Value.absent(),
    Value<int?> maxTasks = const Value.absent(),
    DateTime? startsAt,
    DateTime? endsAt,
    bool? isActive,
  }) => Quest(
    id: id ?? this.id,
    topic: topic ?? this.topic,
    level: level ?? this.level,
    maxDifficultyStep: maxDifficultyStep ?? this.maxDifficultyStep,
    sessionTimeLimitSec: sessionTimeLimitSec.present
        ? sessionTimeLimitSec.value
        : this.sessionTimeLimitSec,
    maxTasks: maxTasks.present ? maxTasks.value : this.maxTasks,
    startsAt: startsAt ?? this.startsAt,
    endsAt: endsAt ?? this.endsAt,
    isActive: isActive ?? this.isActive,
  );
  Quest copyWithCompanion(QuestsCompanion data) {
    return Quest(
      id: data.id.present ? data.id.value : this.id,
      topic: data.topic.present ? data.topic.value : this.topic,
      level: data.level.present ? data.level.value : this.level,
      maxDifficultyStep: data.maxDifficultyStep.present
          ? data.maxDifficultyStep.value
          : this.maxDifficultyStep,
      sessionTimeLimitSec: data.sessionTimeLimitSec.present
          ? data.sessionTimeLimitSec.value
          : this.sessionTimeLimitSec,
      maxTasks: data.maxTasks.present ? data.maxTasks.value : this.maxTasks,
      startsAt: data.startsAt.present ? data.startsAt.value : this.startsAt,
      endsAt: data.endsAt.present ? data.endsAt.value : this.endsAt,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Quest(')
          ..write('id: $id, ')
          ..write('topic: $topic, ')
          ..write('level: $level, ')
          ..write('maxDifficultyStep: $maxDifficultyStep, ')
          ..write('sessionTimeLimitSec: $sessionTimeLimitSec, ')
          ..write('maxTasks: $maxTasks, ')
          ..write('startsAt: $startsAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    topic,
    level,
    maxDifficultyStep,
    sessionTimeLimitSec,
    maxTasks,
    startsAt,
    endsAt,
    isActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Quest &&
          other.id == this.id &&
          other.topic == this.topic &&
          other.level == this.level &&
          other.maxDifficultyStep == this.maxDifficultyStep &&
          other.sessionTimeLimitSec == this.sessionTimeLimitSec &&
          other.maxTasks == this.maxTasks &&
          other.startsAt == this.startsAt &&
          other.endsAt == this.endsAt &&
          other.isActive == this.isActive);
}

class QuestsCompanion extends UpdateCompanion<Quest> {
  final Value<String> id;
  final Value<String> topic;
  final Value<String> level;
  final Value<int> maxDifficultyStep;
  final Value<int?> sessionTimeLimitSec;
  final Value<int?> maxTasks;
  final Value<DateTime> startsAt;
  final Value<DateTime> endsAt;
  final Value<bool> isActive;
  final Value<int> rowid;
  const QuestsCompanion({
    this.id = const Value.absent(),
    this.topic = const Value.absent(),
    this.level = const Value.absent(),
    this.maxDifficultyStep = const Value.absent(),
    this.sessionTimeLimitSec = const Value.absent(),
    this.maxTasks = const Value.absent(),
    this.startsAt = const Value.absent(),
    this.endsAt = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuestsCompanion.insert({
    required String id,
    required String topic,
    required String level,
    required int maxDifficultyStep,
    this.sessionTimeLimitSec = const Value.absent(),
    this.maxTasks = const Value.absent(),
    required DateTime startsAt,
    required DateTime endsAt,
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       topic = Value(topic),
       level = Value(level),
       maxDifficultyStep = Value(maxDifficultyStep),
       startsAt = Value(startsAt),
       endsAt = Value(endsAt);
  static Insertable<Quest> custom({
    Expression<String>? id,
    Expression<String>? topic,
    Expression<String>? level,
    Expression<int>? maxDifficultyStep,
    Expression<int>? sessionTimeLimitSec,
    Expression<int>? maxTasks,
    Expression<DateTime>? startsAt,
    Expression<DateTime>? endsAt,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (topic != null) 'topic': topic,
      if (level != null) 'level': level,
      if (maxDifficultyStep != null) 'max_difficulty_step': maxDifficultyStep,
      if (sessionTimeLimitSec != null)
        'session_time_limit_sec': sessionTimeLimitSec,
      if (maxTasks != null) 'max_tasks': maxTasks,
      if (startsAt != null) 'starts_at': startsAt,
      if (endsAt != null) 'ends_at': endsAt,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuestsCompanion copyWith({
    Value<String>? id,
    Value<String>? topic,
    Value<String>? level,
    Value<int>? maxDifficultyStep,
    Value<int?>? sessionTimeLimitSec,
    Value<int?>? maxTasks,
    Value<DateTime>? startsAt,
    Value<DateTime>? endsAt,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return QuestsCompanion(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      level: level ?? this.level,
      maxDifficultyStep: maxDifficultyStep ?? this.maxDifficultyStep,
      sessionTimeLimitSec: sessionTimeLimitSec ?? this.sessionTimeLimitSec,
      maxTasks: maxTasks ?? this.maxTasks,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (topic.present) {
      map['topic'] = Variable<String>(topic.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (maxDifficultyStep.present) {
      map['max_difficulty_step'] = Variable<int>(maxDifficultyStep.value);
    }
    if (sessionTimeLimitSec.present) {
      map['session_time_limit_sec'] = Variable<int>(sessionTimeLimitSec.value);
    }
    if (maxTasks.present) {
      map['max_tasks'] = Variable<int>(maxTasks.value);
    }
    if (startsAt.present) {
      map['starts_at'] = Variable<DateTime>(startsAt.value);
    }
    if (endsAt.present) {
      map['ends_at'] = Variable<DateTime>(endsAt.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuestsCompanion(')
          ..write('id: $id, ')
          ..write('topic: $topic, ')
          ..write('level: $level, ')
          ..write('maxDifficultyStep: $maxDifficultyStep, ')
          ..write('sessionTimeLimitSec: $sessionTimeLimitSec, ')
          ..write('maxTasks: $maxTasks, ')
          ..write('startsAt: $startsAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskRecordsTable extends TaskRecords
    with TableInfo<$TaskRecordsTable, TaskRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskTypeMeta = const VerificationMeta(
    'taskType',
  );
  @override
  late final GeneratedColumn<String> taskType = GeneratedColumn<String>(
    'task_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skillIdMeta = const VerificationMeta(
    'skillId',
  );
  @override
  late final GeneratedColumn<String> skillId = GeneratedColumn<String>(
    'skill_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<int> difficulty = GeneratedColumn<int>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topicMeta = const VerificationMeta('topic');
  @override
  late final GeneratedColumn<String> topic = GeneratedColumn<String>(
    'topic',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskType,
    skillId,
    difficulty,
    topic,
    payloadJson,
    source,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_type')) {
      context.handle(
        _taskTypeMeta,
        taskType.isAcceptableOrUnknown(data['task_type']!, _taskTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_taskTypeMeta);
    }
    if (data.containsKey('skill_id')) {
      context.handle(
        _skillIdMeta,
        skillId.isAcceptableOrUnknown(data['skill_id']!, _skillIdMeta),
      );
    } else if (isInserting) {
      context.missing(_skillIdMeta);
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    } else if (isInserting) {
      context.missing(_difficultyMeta);
    }
    if (data.containsKey('topic')) {
      context.handle(
        _topicMeta,
        topic.isAcceptableOrUnknown(data['topic']!, _topicMeta),
      );
    } else if (isInserting) {
      context.missing(_topicMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_type'],
      )!,
      skillId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skill_id'],
      )!,
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}difficulty'],
      )!,
      topic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TaskRecordsTable createAlias(String alias) {
    return $TaskRecordsTable(attachedDatabase, alias);
  }
}

class TaskRecord extends DataClass implements Insertable<TaskRecord> {
  final String id;
  final String taskType;
  final String skillId;
  final int difficulty;
  final String topic;
  final String payloadJson;
  final String source;
  final DateTime createdAt;
  const TaskRecord({
    required this.id,
    required this.taskType,
    required this.skillId,
    required this.difficulty,
    required this.topic,
    required this.payloadJson,
    required this.source,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_type'] = Variable<String>(taskType);
    map['skill_id'] = Variable<String>(skillId);
    map['difficulty'] = Variable<int>(difficulty);
    map['topic'] = Variable<String>(topic);
    map['payload_json'] = Variable<String>(payloadJson);
    map['source'] = Variable<String>(source);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TaskRecordsCompanion toCompanion(bool nullToAbsent) {
    return TaskRecordsCompanion(
      id: Value(id),
      taskType: Value(taskType),
      skillId: Value(skillId),
      difficulty: Value(difficulty),
      topic: Value(topic),
      payloadJson: Value(payloadJson),
      source: Value(source),
      createdAt: Value(createdAt),
    );
  }

  factory TaskRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRecord(
      id: serializer.fromJson<String>(json['id']),
      taskType: serializer.fromJson<String>(json['taskType']),
      skillId: serializer.fromJson<String>(json['skillId']),
      difficulty: serializer.fromJson<int>(json['difficulty']),
      topic: serializer.fromJson<String>(json['topic']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      source: serializer.fromJson<String>(json['source']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskType': serializer.toJson<String>(taskType),
      'skillId': serializer.toJson<String>(skillId),
      'difficulty': serializer.toJson<int>(difficulty),
      'topic': serializer.toJson<String>(topic),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'source': serializer.toJson<String>(source),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TaskRecord copyWith({
    String? id,
    String? taskType,
    String? skillId,
    int? difficulty,
    String? topic,
    String? payloadJson,
    String? source,
    DateTime? createdAt,
  }) => TaskRecord(
    id: id ?? this.id,
    taskType: taskType ?? this.taskType,
    skillId: skillId ?? this.skillId,
    difficulty: difficulty ?? this.difficulty,
    topic: topic ?? this.topic,
    payloadJson: payloadJson ?? this.payloadJson,
    source: source ?? this.source,
    createdAt: createdAt ?? this.createdAt,
  );
  TaskRecord copyWithCompanion(TaskRecordsCompanion data) {
    return TaskRecord(
      id: data.id.present ? data.id.value : this.id,
      taskType: data.taskType.present ? data.taskType.value : this.taskType,
      skillId: data.skillId.present ? data.skillId.value : this.skillId,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      topic: data.topic.present ? data.topic.value : this.topic,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRecord(')
          ..write('id: $id, ')
          ..write('taskType: $taskType, ')
          ..write('skillId: $skillId, ')
          ..write('difficulty: $difficulty, ')
          ..write('topic: $topic, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskType,
    skillId,
    difficulty,
    topic,
    payloadJson,
    source,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRecord &&
          other.id == this.id &&
          other.taskType == this.taskType &&
          other.skillId == this.skillId &&
          other.difficulty == this.difficulty &&
          other.topic == this.topic &&
          other.payloadJson == this.payloadJson &&
          other.source == this.source &&
          other.createdAt == this.createdAt);
}

class TaskRecordsCompanion extends UpdateCompanion<TaskRecord> {
  final Value<String> id;
  final Value<String> taskType;
  final Value<String> skillId;
  final Value<int> difficulty;
  final Value<String> topic;
  final Value<String> payloadJson;
  final Value<String> source;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TaskRecordsCompanion({
    this.id = const Value.absent(),
    this.taskType = const Value.absent(),
    this.skillId = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.topic = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskRecordsCompanion.insert({
    required String id,
    required String taskType,
    required String skillId,
    required int difficulty,
    required String topic,
    required String payloadJson,
    required String source,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskType = Value(taskType),
       skillId = Value(skillId),
       difficulty = Value(difficulty),
       topic = Value(topic),
       payloadJson = Value(payloadJson),
       source = Value(source),
       createdAt = Value(createdAt);
  static Insertable<TaskRecord> custom({
    Expression<String>? id,
    Expression<String>? taskType,
    Expression<String>? skillId,
    Expression<int>? difficulty,
    Expression<String>? topic,
    Expression<String>? payloadJson,
    Expression<String>? source,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskType != null) 'task_type': taskType,
      if (skillId != null) 'skill_id': skillId,
      if (difficulty != null) 'difficulty': difficulty,
      if (topic != null) 'topic': topic,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? taskType,
    Value<String>? skillId,
    Value<int>? difficulty,
    Value<String>? topic,
    Value<String>? payloadJson,
    Value<String>? source,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TaskRecordsCompanion(
      id: id ?? this.id,
      taskType: taskType ?? this.taskType,
      skillId: skillId ?? this.skillId,
      difficulty: difficulty ?? this.difficulty,
      topic: topic ?? this.topic,
      payloadJson: payloadJson ?? this.payloadJson,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskType.present) {
      map['task_type'] = Variable<String>(taskType.value);
    }
    if (skillId.present) {
      map['skill_id'] = Variable<String>(skillId.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<int>(difficulty.value);
    }
    if (topic.present) {
      map['topic'] = Variable<String>(topic.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskRecordsCompanion(')
          ..write('id: $id, ')
          ..write('taskType: $taskType, ')
          ..write('skillId: $skillId, ')
          ..write('difficulty: $difficulty, ')
          ..write('topic: $topic, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questIdMeta = const VerificationMeta(
    'questId',
  );
  @override
  late final GeneratedColumn<String> questId = GeneratedColumn<String>(
    'quest_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tasksCompletedMeta = const VerificationMeta(
    'tasksCompleted',
  );
  @override
  late final GeneratedColumn<int> tasksCompleted = GeneratedColumn<int>(
    'tasks_completed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _accuracyMeta = const VerificationMeta(
    'accuracy',
  );
  @override
  late final GeneratedColumn<double> accuracy = GeneratedColumn<double>(
    'accuracy',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hintRateMeta = const VerificationMeta(
    'hintRate',
  );
  @override
  late final GeneratedColumn<double> hintRate = GeneratedColumn<double>(
    'hint_rate',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    questId,
    startedAt,
    endedAt,
    tasksCompleted,
    accuracy,
    hintRate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Session> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('quest_id')) {
      context.handle(
        _questIdMeta,
        questId.isAcceptableOrUnknown(data['quest_id']!, _questIdMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('tasks_completed')) {
      context.handle(
        _tasksCompletedMeta,
        tasksCompleted.isAcceptableOrUnknown(
          data['tasks_completed']!,
          _tasksCompletedMeta,
        ),
      );
    }
    if (data.containsKey('accuracy')) {
      context.handle(
        _accuracyMeta,
        accuracy.isAcceptableOrUnknown(data['accuracy']!, _accuracyMeta),
      );
    }
    if (data.containsKey('hint_rate')) {
      context.handle(
        _hintRateMeta,
        hintRate.isAcceptableOrUnknown(data['hint_rate']!, _hintRateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      questId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quest_id'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      tasksCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tasks_completed'],
      )!,
      accuracy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}accuracy'],
      ),
      hintRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}hint_rate'],
      ),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final String id;
  final String? questId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int tasksCompleted;
  final double? accuracy;
  final double? hintRate;
  const Session({
    required this.id,
    this.questId,
    required this.startedAt,
    this.endedAt,
    required this.tasksCompleted,
    this.accuracy,
    this.hintRate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || questId != null) {
      map['quest_id'] = Variable<String>(questId);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['tasks_completed'] = Variable<int>(tasksCompleted);
    if (!nullToAbsent || accuracy != null) {
      map['accuracy'] = Variable<double>(accuracy);
    }
    if (!nullToAbsent || hintRate != null) {
      map['hint_rate'] = Variable<double>(hintRate);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      questId: questId == null && nullToAbsent
          ? const Value.absent()
          : Value(questId),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      tasksCompleted: Value(tasksCompleted),
      accuracy: accuracy == null && nullToAbsent
          ? const Value.absent()
          : Value(accuracy),
      hintRate: hintRate == null && nullToAbsent
          ? const Value.absent()
          : Value(hintRate),
    );
  }

  factory Session.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<String>(json['id']),
      questId: serializer.fromJson<String?>(json['questId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      tasksCompleted: serializer.fromJson<int>(json['tasksCompleted']),
      accuracy: serializer.fromJson<double?>(json['accuracy']),
      hintRate: serializer.fromJson<double?>(json['hintRate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'questId': serializer.toJson<String?>(questId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'tasksCompleted': serializer.toJson<int>(tasksCompleted),
      'accuracy': serializer.toJson<double?>(accuracy),
      'hintRate': serializer.toJson<double?>(hintRate),
    };
  }

  Session copyWith({
    String? id,
    Value<String?> questId = const Value.absent(),
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    int? tasksCompleted,
    Value<double?> accuracy = const Value.absent(),
    Value<double?> hintRate = const Value.absent(),
  }) => Session(
    id: id ?? this.id,
    questId: questId.present ? questId.value : this.questId,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    tasksCompleted: tasksCompleted ?? this.tasksCompleted,
    accuracy: accuracy.present ? accuracy.value : this.accuracy,
    hintRate: hintRate.present ? hintRate.value : this.hintRate,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      questId: data.questId.present ? data.questId.value : this.questId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      tasksCompleted: data.tasksCompleted.present
          ? data.tasksCompleted.value
          : this.tasksCompleted,
      accuracy: data.accuracy.present ? data.accuracy.value : this.accuracy,
      hintRate: data.hintRate.present ? data.hintRate.value : this.hintRate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('questId: $questId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('tasksCompleted: $tasksCompleted, ')
          ..write('accuracy: $accuracy, ')
          ..write('hintRate: $hintRate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    questId,
    startedAt,
    endedAt,
    tasksCompleted,
    accuracy,
    hintRate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.questId == this.questId &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.tasksCompleted == this.tasksCompleted &&
          other.accuracy == this.accuracy &&
          other.hintRate == this.hintRate);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<String> id;
  final Value<String?> questId;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int> tasksCompleted;
  final Value<double?> accuracy;
  final Value<double?> hintRate;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.questId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.tasksCompleted = const Value.absent(),
    this.accuracy = const Value.absent(),
    this.hintRate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    this.questId = const Value.absent(),
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.tasksCompleted = const Value.absent(),
    this.accuracy = const Value.absent(),
    this.hintRate = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt);
  static Insertable<Session> custom({
    Expression<String>? id,
    Expression<String>? questId,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? tasksCompleted,
    Expression<double>? accuracy,
    Expression<double>? hintRate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (questId != null) 'quest_id': questId,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (tasksCompleted != null) 'tasks_completed': tasksCompleted,
      if (accuracy != null) 'accuracy': accuracy,
      if (hintRate != null) 'hint_rate': hintRate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? questId,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int>? tasksCompleted,
    Value<double?>? accuracy,
    Value<double?>? hintRate,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      questId: questId ?? this.questId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      tasksCompleted: tasksCompleted ?? this.tasksCompleted,
      accuracy: accuracy ?? this.accuracy,
      hintRate: hintRate ?? this.hintRate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (questId.present) {
      map['quest_id'] = Variable<String>(questId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (tasksCompleted.present) {
      map['tasks_completed'] = Variable<int>(tasksCompleted.value);
    }
    if (accuracy.present) {
      map['accuracy'] = Variable<double>(accuracy.value);
    }
    if (hintRate.present) {
      map['hint_rate'] = Variable<double>(hintRate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('questId: $questId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('tasksCompleted: $tasksCompleted, ')
          ..write('accuracy: $accuracy, ')
          ..write('hintRate: $hintRate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttemptsTable extends Attempts with TableInfo<$AttemptsTable, Attempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _learnerAnswerJsonMeta = const VerificationMeta(
    'learnerAnswerJson',
  );
  @override
  late final GeneratedColumn<String> learnerAnswerJson =
      GeneratedColumn<String>(
        'learner_answer_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _correctMeta = const VerificationMeta(
    'correct',
  );
  @override
  late final GeneratedColumn<bool> correct = GeneratedColumn<bool>(
    'correct',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("correct" IN (0, 1))',
    ),
  );
  static const VerificationMeta _usedHintMeta = const VerificationMeta(
    'usedHint',
  );
  @override
  late final GeneratedColumn<bool> usedHint = GeneratedColumn<bool>(
    'used_hint',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("used_hint" IN (0, 1))',
    ),
  );
  static const VerificationMeta _hintStepsMeta = const VerificationMeta(
    'hintSteps',
  );
  @override
  late final GeneratedColumn<int> hintSteps = GeneratedColumn<int>(
    'hint_steps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _latencyMsMeta = const VerificationMeta(
    'latencyMs',
  );
  @override
  late final GeneratedColumn<int> latencyMs = GeneratedColumn<int>(
    'latency_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    sessionId,
    learnerAnswerJson,
    correct,
    usedHint,
    hintSteps,
    latencyMs,
    timestamp,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attempt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('learner_answer_json')) {
      context.handle(
        _learnerAnswerJsonMeta,
        learnerAnswerJson.isAcceptableOrUnknown(
          data['learner_answer_json']!,
          _learnerAnswerJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_learnerAnswerJsonMeta);
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    } else if (isInserting) {
      context.missing(_correctMeta);
    }
    if (data.containsKey('used_hint')) {
      context.handle(
        _usedHintMeta,
        usedHint.isAcceptableOrUnknown(data['used_hint']!, _usedHintMeta),
      );
    } else if (isInserting) {
      context.missing(_usedHintMeta);
    }
    if (data.containsKey('hint_steps')) {
      context.handle(
        _hintStepsMeta,
        hintSteps.isAcceptableOrUnknown(data['hint_steps']!, _hintStepsMeta),
      );
    }
    if (data.containsKey('latency_ms')) {
      context.handle(
        _latencyMsMeta,
        latencyMs.isAcceptableOrUnknown(data['latency_ms']!, _latencyMsMeta),
      );
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attempt(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      learnerAnswerJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}learner_answer_json'],
      )!,
      correct: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}correct'],
      )!,
      usedHint: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}used_hint'],
      )!,
      hintSteps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hint_steps'],
      )!,
      latencyMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latency_ms'],
      ),
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
    );
  }

  @override
  $AttemptsTable createAlias(String alias) {
    return $AttemptsTable(attachedDatabase, alias);
  }
}

class Attempt extends DataClass implements Insertable<Attempt> {
  final String id;
  final String taskId;
  final String sessionId;
  final String learnerAnswerJson;
  final bool correct;
  final bool usedHint;
  final int hintSteps;
  final int? latencyMs;
  final DateTime timestamp;
  const Attempt({
    required this.id,
    required this.taskId,
    required this.sessionId,
    required this.learnerAnswerJson,
    required this.correct,
    required this.usedHint,
    required this.hintSteps,
    this.latencyMs,
    required this.timestamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['session_id'] = Variable<String>(sessionId);
    map['learner_answer_json'] = Variable<String>(learnerAnswerJson);
    map['correct'] = Variable<bool>(correct);
    map['used_hint'] = Variable<bool>(usedHint);
    map['hint_steps'] = Variable<int>(hintSteps);
    if (!nullToAbsent || latencyMs != null) {
      map['latency_ms'] = Variable<int>(latencyMs);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  AttemptsCompanion toCompanion(bool nullToAbsent) {
    return AttemptsCompanion(
      id: Value(id),
      taskId: Value(taskId),
      sessionId: Value(sessionId),
      learnerAnswerJson: Value(learnerAnswerJson),
      correct: Value(correct),
      usedHint: Value(usedHint),
      hintSteps: Value(hintSteps),
      latencyMs: latencyMs == null && nullToAbsent
          ? const Value.absent()
          : Value(latencyMs),
      timestamp: Value(timestamp),
    );
  }

  factory Attempt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attempt(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      learnerAnswerJson: serializer.fromJson<String>(json['learnerAnswerJson']),
      correct: serializer.fromJson<bool>(json['correct']),
      usedHint: serializer.fromJson<bool>(json['usedHint']),
      hintSteps: serializer.fromJson<int>(json['hintSteps']),
      latencyMs: serializer.fromJson<int?>(json['latencyMs']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'sessionId': serializer.toJson<String>(sessionId),
      'learnerAnswerJson': serializer.toJson<String>(learnerAnswerJson),
      'correct': serializer.toJson<bool>(correct),
      'usedHint': serializer.toJson<bool>(usedHint),
      'hintSteps': serializer.toJson<int>(hintSteps),
      'latencyMs': serializer.toJson<int?>(latencyMs),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  Attempt copyWith({
    String? id,
    String? taskId,
    String? sessionId,
    String? learnerAnswerJson,
    bool? correct,
    bool? usedHint,
    int? hintSteps,
    Value<int?> latencyMs = const Value.absent(),
    DateTime? timestamp,
  }) => Attempt(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    sessionId: sessionId ?? this.sessionId,
    learnerAnswerJson: learnerAnswerJson ?? this.learnerAnswerJson,
    correct: correct ?? this.correct,
    usedHint: usedHint ?? this.usedHint,
    hintSteps: hintSteps ?? this.hintSteps,
    latencyMs: latencyMs.present ? latencyMs.value : this.latencyMs,
    timestamp: timestamp ?? this.timestamp,
  );
  Attempt copyWithCompanion(AttemptsCompanion data) {
    return Attempt(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      learnerAnswerJson: data.learnerAnswerJson.present
          ? data.learnerAnswerJson.value
          : this.learnerAnswerJson,
      correct: data.correct.present ? data.correct.value : this.correct,
      usedHint: data.usedHint.present ? data.usedHint.value : this.usedHint,
      hintSteps: data.hintSteps.present ? data.hintSteps.value : this.hintSteps,
      latencyMs: data.latencyMs.present ? data.latencyMs.value : this.latencyMs,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attempt(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('sessionId: $sessionId, ')
          ..write('learnerAnswerJson: $learnerAnswerJson, ')
          ..write('correct: $correct, ')
          ..write('usedHint: $usedHint, ')
          ..write('hintSteps: $hintSteps, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    sessionId,
    learnerAnswerJson,
    correct,
    usedHint,
    hintSteps,
    latencyMs,
    timestamp,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attempt &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.sessionId == this.sessionId &&
          other.learnerAnswerJson == this.learnerAnswerJson &&
          other.correct == this.correct &&
          other.usedHint == this.usedHint &&
          other.hintSteps == this.hintSteps &&
          other.latencyMs == this.latencyMs &&
          other.timestamp == this.timestamp);
}

class AttemptsCompanion extends UpdateCompanion<Attempt> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<String> sessionId;
  final Value<String> learnerAnswerJson;
  final Value<bool> correct;
  final Value<bool> usedHint;
  final Value<int> hintSteps;
  final Value<int?> latencyMs;
  final Value<DateTime> timestamp;
  final Value<int> rowid;
  const AttemptsCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.learnerAnswerJson = const Value.absent(),
    this.correct = const Value.absent(),
    this.usedHint = const Value.absent(),
    this.hintSteps = const Value.absent(),
    this.latencyMs = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttemptsCompanion.insert({
    required String id,
    required String taskId,
    required String sessionId,
    required String learnerAnswerJson,
    required bool correct,
    required bool usedHint,
    this.hintSteps = const Value.absent(),
    this.latencyMs = const Value.absent(),
    required DateTime timestamp,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       sessionId = Value(sessionId),
       learnerAnswerJson = Value(learnerAnswerJson),
       correct = Value(correct),
       usedHint = Value(usedHint),
       timestamp = Value(timestamp);
  static Insertable<Attempt> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? sessionId,
    Expression<String>? learnerAnswerJson,
    Expression<bool>? correct,
    Expression<bool>? usedHint,
    Expression<int>? hintSteps,
    Expression<int>? latencyMs,
    Expression<DateTime>? timestamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (sessionId != null) 'session_id': sessionId,
      if (learnerAnswerJson != null) 'learner_answer_json': learnerAnswerJson,
      if (correct != null) 'correct': correct,
      if (usedHint != null) 'used_hint': usedHint,
      if (hintSteps != null) 'hint_steps': hintSteps,
      if (latencyMs != null) 'latency_ms': latencyMs,
      if (timestamp != null) 'timestamp': timestamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttemptsCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<String>? sessionId,
    Value<String>? learnerAnswerJson,
    Value<bool>? correct,
    Value<bool>? usedHint,
    Value<int>? hintSteps,
    Value<int?>? latencyMs,
    Value<DateTime>? timestamp,
    Value<int>? rowid,
  }) {
    return AttemptsCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      sessionId: sessionId ?? this.sessionId,
      learnerAnswerJson: learnerAnswerJson ?? this.learnerAnswerJson,
      correct: correct ?? this.correct,
      usedHint: usedHint ?? this.usedHint,
      hintSteps: hintSteps ?? this.hintSteps,
      latencyMs: latencyMs ?? this.latencyMs,
      timestamp: timestamp ?? this.timestamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (learnerAnswerJson.present) {
      map['learner_answer_json'] = Variable<String>(learnerAnswerJson.value);
    }
    if (correct.present) {
      map['correct'] = Variable<bool>(correct.value);
    }
    if (usedHint.present) {
      map['used_hint'] = Variable<bool>(usedHint.value);
    }
    if (hintSteps.present) {
      map['hint_steps'] = Variable<int>(hintSteps.value);
    }
    if (latencyMs.present) {
      map['latency_ms'] = Variable<int>(latencyMs.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttemptsCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('sessionId: $sessionId, ')
          ..write('learnerAnswerJson: $learnerAnswerJson, ')
          ..write('correct: $correct, ')
          ..write('usedHint: $usedHint, ')
          ..write('hintSteps: $hintSteps, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('timestamp: $timestamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxEntriesTable extends SyncOutboxEntries
    with TableInfo<$SyncOutboxEntriesTable, SyncOutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    payloadJson,
    entityType,
    retryCount,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncOutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $SyncOutboxEntriesTable createAlias(String alias) {
    return $SyncOutboxEntriesTable(attachedDatabase, alias);
  }
}

class SyncOutboxEntry extends DataClass implements Insertable<SyncOutboxEntry> {
  final String id;
  final String payloadJson;
  final String entityType;
  final int retryCount;
  final String? lastError;
  const SyncOutboxEntry({
    required this.id,
    required this.payloadJson,
    required this.entityType,
    required this.retryCount,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['payload_json'] = Variable<String>(payloadJson);
    map['entity_type'] = Variable<String>(entityType);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SyncOutboxEntriesCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxEntriesCompanion(
      id: Value(id),
      payloadJson: Value(payloadJson),
      entityType: Value(entityType),
      retryCount: Value(retryCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory SyncOutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxEntry(
      id: serializer.fromJson<String>(json['id']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      entityType: serializer.fromJson<String>(json['entityType']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'entityType': serializer.toJson<String>(entityType),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  SyncOutboxEntry copyWith({
    String? id,
    String? payloadJson,
    String? entityType,
    int? retryCount,
    Value<String?> lastError = const Value.absent(),
  }) => SyncOutboxEntry(
    id: id ?? this.id,
    payloadJson: payloadJson ?? this.payloadJson,
    entityType: entityType ?? this.entityType,
    retryCount: retryCount ?? this.retryCount,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  SyncOutboxEntry copyWithCompanion(SyncOutboxEntriesCompanion data) {
    return SyncOutboxEntry(
      id: data.id.present ? data.id.value : this.id,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxEntry(')
          ..write('id: $id, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('entityType: $entityType, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, payloadJson, entityType, retryCount, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxEntry &&
          other.id == this.id &&
          other.payloadJson == this.payloadJson &&
          other.entityType == this.entityType &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError);
}

class SyncOutboxEntriesCompanion extends UpdateCompanion<SyncOutboxEntry> {
  final Value<String> id;
  final Value<String> payloadJson;
  final Value<String> entityType;
  final Value<int> retryCount;
  final Value<String?> lastError;
  final Value<int> rowid;
  const SyncOutboxEntriesCompanion({
    this.id = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.entityType = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxEntriesCompanion.insert({
    required String id,
    required String payloadJson,
    required String entityType,
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       payloadJson = Value(payloadJson),
       entityType = Value(entityType);
  static Insertable<SyncOutboxEntry> custom({
    Expression<String>? id,
    Expression<String>? payloadJson,
    Expression<String>? entityType,
    Expression<int>? retryCount,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (entityType != null) 'entity_type': entityType,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? payloadJson,
    Value<String>? entityType,
    Value<int>? retryCount,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return SyncOutboxEntriesCompanion(
      id: id ?? this.id,
      payloadJson: payloadJson ?? this.payloadJson,
      entityType: entityType ?? this.entityType,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxEntriesCompanion(')
          ..write('id: $id, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('entityType: $entityType, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$IkamvaDatabase extends GeneratedDatabase {
  _$IkamvaDatabase(QueryExecutor e) : super(e);
  $IkamvaDatabaseManager get managers => $IkamvaDatabaseManager(this);
  late final $LearnerProfilesTable learnerProfiles = $LearnerProfilesTable(
    this,
  );
  late final $QuestsTable quests = $QuestsTable(this);
  late final $TaskRecordsTable taskRecords = $TaskRecordsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $AttemptsTable attempts = $AttemptsTable(this);
  late final $SyncOutboxEntriesTable syncOutboxEntries =
      $SyncOutboxEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    learnerProfiles,
    quests,
    taskRecords,
    sessions,
    attempts,
    syncOutboxEntries,
  ];
}

typedef $$LearnerProfilesTableCreateCompanionBuilder =
    LearnerProfilesCompanion Function({
      required String id,
      required String displayName,
      Value<String?> homeLanguageCode,
      Value<String?> pairedTeacherCode,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$LearnerProfilesTableUpdateCompanionBuilder =
    LearnerProfilesCompanion Function({
      Value<String> id,
      Value<String> displayName,
      Value<String?> homeLanguageCode,
      Value<String?> pairedTeacherCode,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$LearnerProfilesTableFilterComposer
    extends Composer<_$IkamvaDatabase, $LearnerProfilesTable> {
  $$LearnerProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get homeLanguageCode => $composableBuilder(
    column: $table.homeLanguageCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pairedTeacherCode => $composableBuilder(
    column: $table.pairedTeacherCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LearnerProfilesTableOrderingComposer
    extends Composer<_$IkamvaDatabase, $LearnerProfilesTable> {
  $$LearnerProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get homeLanguageCode => $composableBuilder(
    column: $table.homeLanguageCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pairedTeacherCode => $composableBuilder(
    column: $table.pairedTeacherCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LearnerProfilesTableAnnotationComposer
    extends Composer<_$IkamvaDatabase, $LearnerProfilesTable> {
  $$LearnerProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get homeLanguageCode => $composableBuilder(
    column: $table.homeLanguageCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pairedTeacherCode => $composableBuilder(
    column: $table.pairedTeacherCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LearnerProfilesTableTableManager
    extends
        RootTableManager<
          _$IkamvaDatabase,
          $LearnerProfilesTable,
          LearnerProfile,
          $$LearnerProfilesTableFilterComposer,
          $$LearnerProfilesTableOrderingComposer,
          $$LearnerProfilesTableAnnotationComposer,
          $$LearnerProfilesTableCreateCompanionBuilder,
          $$LearnerProfilesTableUpdateCompanionBuilder,
          (
            LearnerProfile,
            BaseReferences<
              _$IkamvaDatabase,
              $LearnerProfilesTable,
              LearnerProfile
            >,
          ),
          LearnerProfile,
          PrefetchHooks Function()
        > {
  $$LearnerProfilesTableTableManager(
    _$IkamvaDatabase db,
    $LearnerProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearnerProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearnerProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearnerProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> homeLanguageCode = const Value.absent(),
                Value<String?> pairedTeacherCode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearnerProfilesCompanion(
                id: id,
                displayName: displayName,
                homeLanguageCode: homeLanguageCode,
                pairedTeacherCode: pairedTeacherCode,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String displayName,
                Value<String?> homeLanguageCode = const Value.absent(),
                Value<String?> pairedTeacherCode = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LearnerProfilesCompanion.insert(
                id: id,
                displayName: displayName,
                homeLanguageCode: homeLanguageCode,
                pairedTeacherCode: pairedTeacherCode,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LearnerProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$IkamvaDatabase,
      $LearnerProfilesTable,
      LearnerProfile,
      $$LearnerProfilesTableFilterComposer,
      $$LearnerProfilesTableOrderingComposer,
      $$LearnerProfilesTableAnnotationComposer,
      $$LearnerProfilesTableCreateCompanionBuilder,
      $$LearnerProfilesTableUpdateCompanionBuilder,
      (
        LearnerProfile,
        BaseReferences<_$IkamvaDatabase, $LearnerProfilesTable, LearnerProfile>,
      ),
      LearnerProfile,
      PrefetchHooks Function()
    >;
typedef $$QuestsTableCreateCompanionBuilder =
    QuestsCompanion Function({
      required String id,
      required String topic,
      required String level,
      required int maxDifficultyStep,
      Value<int?> sessionTimeLimitSec,
      Value<int?> maxTasks,
      required DateTime startsAt,
      required DateTime endsAt,
      Value<bool> isActive,
      Value<int> rowid,
    });
typedef $$QuestsTableUpdateCompanionBuilder =
    QuestsCompanion Function({
      Value<String> id,
      Value<String> topic,
      Value<String> level,
      Value<int> maxDifficultyStep,
      Value<int?> sessionTimeLimitSec,
      Value<int?> maxTasks,
      Value<DateTime> startsAt,
      Value<DateTime> endsAt,
      Value<bool> isActive,
      Value<int> rowid,
    });

class $$QuestsTableFilterComposer
    extends Composer<_$IkamvaDatabase, $QuestsTable> {
  $$QuestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topic => $composableBuilder(
    column: $table.topic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxDifficultyStep => $composableBuilder(
    column: $table.maxDifficultyStep,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sessionTimeLimitSec => $composableBuilder(
    column: $table.sessionTimeLimitSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxTasks => $composableBuilder(
    column: $table.maxTasks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startsAt => $composableBuilder(
    column: $table.startsAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuestsTableOrderingComposer
    extends Composer<_$IkamvaDatabase, $QuestsTable> {
  $$QuestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topic => $composableBuilder(
    column: $table.topic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxDifficultyStep => $composableBuilder(
    column: $table.maxDifficultyStep,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sessionTimeLimitSec => $composableBuilder(
    column: $table.sessionTimeLimitSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxTasks => $composableBuilder(
    column: $table.maxTasks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startsAt => $composableBuilder(
    column: $table.startsAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuestsTableAnnotationComposer
    extends Composer<_$IkamvaDatabase, $QuestsTable> {
  $$QuestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get topic =>
      $composableBuilder(column: $table.topic, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<int> get maxDifficultyStep => $composableBuilder(
    column: $table.maxDifficultyStep,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sessionTimeLimitSec => $composableBuilder(
    column: $table.sessionTimeLimitSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxTasks =>
      $composableBuilder(column: $table.maxTasks, builder: (column) => column);

  GeneratedColumn<DateTime> get startsAt =>
      $composableBuilder(column: $table.startsAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endsAt =>
      $composableBuilder(column: $table.endsAt, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$QuestsTableTableManager
    extends
        RootTableManager<
          _$IkamvaDatabase,
          $QuestsTable,
          Quest,
          $$QuestsTableFilterComposer,
          $$QuestsTableOrderingComposer,
          $$QuestsTableAnnotationComposer,
          $$QuestsTableCreateCompanionBuilder,
          $$QuestsTableUpdateCompanionBuilder,
          (Quest, BaseReferences<_$IkamvaDatabase, $QuestsTable, Quest>),
          Quest,
          PrefetchHooks Function()
        > {
  $$QuestsTableTableManager(_$IkamvaDatabase db, $QuestsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> topic = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<int> maxDifficultyStep = const Value.absent(),
                Value<int?> sessionTimeLimitSec = const Value.absent(),
                Value<int?> maxTasks = const Value.absent(),
                Value<DateTime> startsAt = const Value.absent(),
                Value<DateTime> endsAt = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuestsCompanion(
                id: id,
                topic: topic,
                level: level,
                maxDifficultyStep: maxDifficultyStep,
                sessionTimeLimitSec: sessionTimeLimitSec,
                maxTasks: maxTasks,
                startsAt: startsAt,
                endsAt: endsAt,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String topic,
                required String level,
                required int maxDifficultyStep,
                Value<int?> sessionTimeLimitSec = const Value.absent(),
                Value<int?> maxTasks = const Value.absent(),
                required DateTime startsAt,
                required DateTime endsAt,
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuestsCompanion.insert(
                id: id,
                topic: topic,
                level: level,
                maxDifficultyStep: maxDifficultyStep,
                sessionTimeLimitSec: sessionTimeLimitSec,
                maxTasks: maxTasks,
                startsAt: startsAt,
                endsAt: endsAt,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuestsTableProcessedTableManager =
    ProcessedTableManager<
      _$IkamvaDatabase,
      $QuestsTable,
      Quest,
      $$QuestsTableFilterComposer,
      $$QuestsTableOrderingComposer,
      $$QuestsTableAnnotationComposer,
      $$QuestsTableCreateCompanionBuilder,
      $$QuestsTableUpdateCompanionBuilder,
      (Quest, BaseReferences<_$IkamvaDatabase, $QuestsTable, Quest>),
      Quest,
      PrefetchHooks Function()
    >;
typedef $$TaskRecordsTableCreateCompanionBuilder =
    TaskRecordsCompanion Function({
      required String id,
      required String taskType,
      required String skillId,
      required int difficulty,
      required String topic,
      required String payloadJson,
      required String source,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$TaskRecordsTableUpdateCompanionBuilder =
    TaskRecordsCompanion Function({
      Value<String> id,
      Value<String> taskType,
      Value<String> skillId,
      Value<int> difficulty,
      Value<String> topic,
      Value<String> payloadJson,
      Value<String> source,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$TaskRecordsTableFilterComposer
    extends Composer<_$IkamvaDatabase, $TaskRecordsTable> {
  $$TaskRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskType => $composableBuilder(
    column: $table.taskType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skillId => $composableBuilder(
    column: $table.skillId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topic => $composableBuilder(
    column: $table.topic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TaskRecordsTableOrderingComposer
    extends Composer<_$IkamvaDatabase, $TaskRecordsTable> {
  $$TaskRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskType => $composableBuilder(
    column: $table.taskType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skillId => $composableBuilder(
    column: $table.skillId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topic => $composableBuilder(
    column: $table.topic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaskRecordsTableAnnotationComposer
    extends Composer<_$IkamvaDatabase, $TaskRecordsTable> {
  $$TaskRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskType =>
      $composableBuilder(column: $table.taskType, builder: (column) => column);

  GeneratedColumn<String> get skillId =>
      $composableBuilder(column: $table.skillId, builder: (column) => column);

  GeneratedColumn<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<String> get topic =>
      $composableBuilder(column: $table.topic, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TaskRecordsTableTableManager
    extends
        RootTableManager<
          _$IkamvaDatabase,
          $TaskRecordsTable,
          TaskRecord,
          $$TaskRecordsTableFilterComposer,
          $$TaskRecordsTableOrderingComposer,
          $$TaskRecordsTableAnnotationComposer,
          $$TaskRecordsTableCreateCompanionBuilder,
          $$TaskRecordsTableUpdateCompanionBuilder,
          (
            TaskRecord,
            BaseReferences<_$IkamvaDatabase, $TaskRecordsTable, TaskRecord>,
          ),
          TaskRecord,
          PrefetchHooks Function()
        > {
  $$TaskRecordsTableTableManager(_$IkamvaDatabase db, $TaskRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskType = const Value.absent(),
                Value<String> skillId = const Value.absent(),
                Value<int> difficulty = const Value.absent(),
                Value<String> topic = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskRecordsCompanion(
                id: id,
                taskType: taskType,
                skillId: skillId,
                difficulty: difficulty,
                topic: topic,
                payloadJson: payloadJson,
                source: source,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskType,
                required String skillId,
                required int difficulty,
                required String topic,
                required String payloadJson,
                required String source,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TaskRecordsCompanion.insert(
                id: id,
                taskType: taskType,
                skillId: skillId,
                difficulty: difficulty,
                topic: topic,
                payloadJson: payloadJson,
                source: source,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TaskRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$IkamvaDatabase,
      $TaskRecordsTable,
      TaskRecord,
      $$TaskRecordsTableFilterComposer,
      $$TaskRecordsTableOrderingComposer,
      $$TaskRecordsTableAnnotationComposer,
      $$TaskRecordsTableCreateCompanionBuilder,
      $$TaskRecordsTableUpdateCompanionBuilder,
      (
        TaskRecord,
        BaseReferences<_$IkamvaDatabase, $TaskRecordsTable, TaskRecord>,
      ),
      TaskRecord,
      PrefetchHooks Function()
    >;
typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      required String id,
      Value<String?> questId,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<int> tasksCompleted,
      Value<double?> accuracy,
      Value<double?> hintRate,
      Value<int> rowid,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<String> id,
      Value<String?> questId,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<int> tasksCompleted,
      Value<double?> accuracy,
      Value<double?> hintRate,
      Value<int> rowid,
    });

class $$SessionsTableFilterComposer
    extends Composer<_$IkamvaDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questId => $composableBuilder(
    column: $table.questId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tasksCompleted => $composableBuilder(
    column: $table.tasksCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get hintRate => $composableBuilder(
    column: $table.hintRate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionsTableOrderingComposer
    extends Composer<_$IkamvaDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questId => $composableBuilder(
    column: $table.questId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tasksCompleted => $composableBuilder(
    column: $table.tasksCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get hintRate => $composableBuilder(
    column: $table.hintRate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$IkamvaDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get questId =>
      $composableBuilder(column: $table.questId, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get tasksCompleted => $composableBuilder(
    column: $table.tasksCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<double> get accuracy =>
      $composableBuilder(column: $table.accuracy, builder: (column) => column);

  GeneratedColumn<double> get hintRate =>
      $composableBuilder(column: $table.hintRate, builder: (column) => column);
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$IkamvaDatabase,
          $SessionsTable,
          Session,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (Session, BaseReferences<_$IkamvaDatabase, $SessionsTable, Session>),
          Session,
          PrefetchHooks Function()
        > {
  $$SessionsTableTableManager(_$IkamvaDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> questId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> tasksCompleted = const Value.absent(),
                Value<double?> accuracy = const Value.absent(),
                Value<double?> hintRate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                questId: questId,
                startedAt: startedAt,
                endedAt: endedAt,
                tasksCompleted: tasksCompleted,
                accuracy: accuracy,
                hintRate: hintRate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> questId = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> tasksCompleted = const Value.absent(),
                Value<double?> accuracy = const Value.absent(),
                Value<double?> hintRate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                questId: questId,
                startedAt: startedAt,
                endedAt: endedAt,
                tasksCompleted: tasksCompleted,
                accuracy: accuracy,
                hintRate: hintRate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$IkamvaDatabase,
      $SessionsTable,
      Session,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (Session, BaseReferences<_$IkamvaDatabase, $SessionsTable, Session>),
      Session,
      PrefetchHooks Function()
    >;
typedef $$AttemptsTableCreateCompanionBuilder =
    AttemptsCompanion Function({
      required String id,
      required String taskId,
      required String sessionId,
      required String learnerAnswerJson,
      required bool correct,
      required bool usedHint,
      Value<int> hintSteps,
      Value<int?> latencyMs,
      required DateTime timestamp,
      Value<int> rowid,
    });
typedef $$AttemptsTableUpdateCompanionBuilder =
    AttemptsCompanion Function({
      Value<String> id,
      Value<String> taskId,
      Value<String> sessionId,
      Value<String> learnerAnswerJson,
      Value<bool> correct,
      Value<bool> usedHint,
      Value<int> hintSteps,
      Value<int?> latencyMs,
      Value<DateTime> timestamp,
      Value<int> rowid,
    });

class $$AttemptsTableFilterComposer
    extends Composer<_$IkamvaDatabase, $AttemptsTable> {
  $$AttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get learnerAnswerJson => $composableBuilder(
    column: $table.learnerAnswerJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get usedHint => $composableBuilder(
    column: $table.usedHint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hintSteps => $composableBuilder(
    column: $table.hintSteps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttemptsTableOrderingComposer
    extends Composer<_$IkamvaDatabase, $AttemptsTable> {
  $$AttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get learnerAnswerJson => $composableBuilder(
    column: $table.learnerAnswerJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get usedHint => $composableBuilder(
    column: $table.usedHint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hintSteps => $composableBuilder(
    column: $table.hintSteps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttemptsTableAnnotationComposer
    extends Composer<_$IkamvaDatabase, $AttemptsTable> {
  $$AttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get learnerAnswerJson => $composableBuilder(
    column: $table.learnerAnswerJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumn<bool> get usedHint =>
      $composableBuilder(column: $table.usedHint, builder: (column) => column);

  GeneratedColumn<int> get hintSteps =>
      $composableBuilder(column: $table.hintSteps, builder: (column) => column);

  GeneratedColumn<int> get latencyMs =>
      $composableBuilder(column: $table.latencyMs, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$AttemptsTableTableManager
    extends
        RootTableManager<
          _$IkamvaDatabase,
          $AttemptsTable,
          Attempt,
          $$AttemptsTableFilterComposer,
          $$AttemptsTableOrderingComposer,
          $$AttemptsTableAnnotationComposer,
          $$AttemptsTableCreateCompanionBuilder,
          $$AttemptsTableUpdateCompanionBuilder,
          (Attempt, BaseReferences<_$IkamvaDatabase, $AttemptsTable, Attempt>),
          Attempt,
          PrefetchHooks Function()
        > {
  $$AttemptsTableTableManager(_$IkamvaDatabase db, $AttemptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> learnerAnswerJson = const Value.absent(),
                Value<bool> correct = const Value.absent(),
                Value<bool> usedHint = const Value.absent(),
                Value<int> hintSteps = const Value.absent(),
                Value<int?> latencyMs = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttemptsCompanion(
                id: id,
                taskId: taskId,
                sessionId: sessionId,
                learnerAnswerJson: learnerAnswerJson,
                correct: correct,
                usedHint: usedHint,
                hintSteps: hintSteps,
                latencyMs: latencyMs,
                timestamp: timestamp,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                required String sessionId,
                required String learnerAnswerJson,
                required bool correct,
                required bool usedHint,
                Value<int> hintSteps = const Value.absent(),
                Value<int?> latencyMs = const Value.absent(),
                required DateTime timestamp,
                Value<int> rowid = const Value.absent(),
              }) => AttemptsCompanion.insert(
                id: id,
                taskId: taskId,
                sessionId: sessionId,
                learnerAnswerJson: learnerAnswerJson,
                correct: correct,
                usedHint: usedHint,
                hintSteps: hintSteps,
                latencyMs: latencyMs,
                timestamp: timestamp,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$IkamvaDatabase,
      $AttemptsTable,
      Attempt,
      $$AttemptsTableFilterComposer,
      $$AttemptsTableOrderingComposer,
      $$AttemptsTableAnnotationComposer,
      $$AttemptsTableCreateCompanionBuilder,
      $$AttemptsTableUpdateCompanionBuilder,
      (Attempt, BaseReferences<_$IkamvaDatabase, $AttemptsTable, Attempt>),
      Attempt,
      PrefetchHooks Function()
    >;
typedef $$SyncOutboxEntriesTableCreateCompanionBuilder =
    SyncOutboxEntriesCompanion Function({
      required String id,
      required String payloadJson,
      required String entityType,
      Value<int> retryCount,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$SyncOutboxEntriesTableUpdateCompanionBuilder =
    SyncOutboxEntriesCompanion Function({
      Value<String> id,
      Value<String> payloadJson,
      Value<String> entityType,
      Value<int> retryCount,
      Value<String?> lastError,
      Value<int> rowid,
    });

class $$SyncOutboxEntriesTableFilterComposer
    extends Composer<_$IkamvaDatabase, $SyncOutboxEntriesTable> {
  $$SyncOutboxEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxEntriesTableOrderingComposer
    extends Composer<_$IkamvaDatabase, $SyncOutboxEntriesTable> {
  $$SyncOutboxEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxEntriesTableAnnotationComposer
    extends Composer<_$IkamvaDatabase, $SyncOutboxEntriesTable> {
  $$SyncOutboxEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$SyncOutboxEntriesTableTableManager
    extends
        RootTableManager<
          _$IkamvaDatabase,
          $SyncOutboxEntriesTable,
          SyncOutboxEntry,
          $$SyncOutboxEntriesTableFilterComposer,
          $$SyncOutboxEntriesTableOrderingComposer,
          $$SyncOutboxEntriesTableAnnotationComposer,
          $$SyncOutboxEntriesTableCreateCompanionBuilder,
          $$SyncOutboxEntriesTableUpdateCompanionBuilder,
          (
            SyncOutboxEntry,
            BaseReferences<
              _$IkamvaDatabase,
              $SyncOutboxEntriesTable,
              SyncOutboxEntry
            >,
          ),
          SyncOutboxEntry,
          PrefetchHooks Function()
        > {
  $$SyncOutboxEntriesTableTableManager(
    _$IkamvaDatabase db,
    $SyncOutboxEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxEntriesCompanion(
                id: id,
                payloadJson: payloadJson,
                entityType: entityType,
                retryCount: retryCount,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String payloadJson,
                required String entityType,
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxEntriesCompanion.insert(
                id: id,
                payloadJson: payloadJson,
                entityType: entityType,
                retryCount: retryCount,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$IkamvaDatabase,
      $SyncOutboxEntriesTable,
      SyncOutboxEntry,
      $$SyncOutboxEntriesTableFilterComposer,
      $$SyncOutboxEntriesTableOrderingComposer,
      $$SyncOutboxEntriesTableAnnotationComposer,
      $$SyncOutboxEntriesTableCreateCompanionBuilder,
      $$SyncOutboxEntriesTableUpdateCompanionBuilder,
      (
        SyncOutboxEntry,
        BaseReferences<
          _$IkamvaDatabase,
          $SyncOutboxEntriesTable,
          SyncOutboxEntry
        >,
      ),
      SyncOutboxEntry,
      PrefetchHooks Function()
    >;

class $IkamvaDatabaseManager {
  final _$IkamvaDatabase _db;
  $IkamvaDatabaseManager(this._db);
  $$LearnerProfilesTableTableManager get learnerProfiles =>
      $$LearnerProfilesTableTableManager(_db, _db.learnerProfiles);
  $$QuestsTableTableManager get quests =>
      $$QuestsTableTableManager(_db, _db.quests);
  $$TaskRecordsTableTableManager get taskRecords =>
      $$TaskRecordsTableTableManager(_db, _db.taskRecords);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$AttemptsTableTableManager get attempts =>
      $$AttemptsTableTableManager(_db, _db.attempts);
  $$SyncOutboxEntriesTableTableManager get syncOutboxEntries =>
      $$SyncOutboxEntriesTableTableManager(_db, _db.syncOutboxEntries);
}
