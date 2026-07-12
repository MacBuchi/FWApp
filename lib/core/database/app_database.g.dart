// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
mixin _$VehicleDaoMixin on DatabaseAccessor<AppDatabase> {
  $VehiclesTable get vehicles => attachedDatabase.vehicles;
}
mixin _$CompartmentDaoMixin on DatabaseAccessor<AppDatabase> {
  $VehiclesTable get vehicles => attachedDatabase.vehicles;
  $CompartmentsTable get compartments => attachedDatabase.compartments;
}
mixin _$EquipmentDaoMixin on DatabaseAccessor<AppDatabase> {
  $EquipmentItemsTable get equipmentItems => attachedDatabase.equipmentItems;
}
mixin _$AssignmentDaoMixin on DatabaseAccessor<AppDatabase> {
  $VehiclesTable get vehicles => attachedDatabase.vehicles;
  $CompartmentsTable get compartments => attachedDatabase.compartments;
  $EquipmentItemsTable get equipmentItems => attachedDatabase.equipmentItems;
  $EquipmentAssignmentsTable get equipmentAssignments =>
      attachedDatabase.equipmentAssignments;
}
mixin _$InspectionDaoMixin on DatabaseAccessor<AppDatabase> {
  $EquipmentItemsTable get equipmentItems => attachedDatabase.equipmentItems;
  $VehiclesTable get vehicles => attachedDatabase.vehicles;
  $CompartmentsTable get compartments => attachedDatabase.compartments;
  $EquipmentInstancesTable get equipmentInstances =>
      attachedDatabase.equipmentInstances;
  $InspectionSchedulesTable get inspectionSchedules =>
      attachedDatabase.inspectionSchedules;
  $InspectionLogTable get inspectionLog => attachedDatabase.inspectionLog;
}
mixin _$QuizDaoMixin on DatabaseAccessor<AppDatabase> {
  $VehiclesTable get vehicles => attachedDatabase.vehicles;
  $QuizResultsTable get quizResults => attachedDatabase.quizResults;
}

class $VehiclesTable extends Vehicles
    with TableInfo<$VehiclesTable, VehicleData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VehiclesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _licensePlateMeta = const VerificationMeta(
    'licensePlate',
  );
  @override
  late final GeneratedColumn<String> licensePlate = GeneratedColumn<String>(
    'license_plate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    licensePlate,
    imagePath,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vehicles';
  @override
  VerificationContext validateIntegrity(
    Insertable<VehicleData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('license_plate')) {
      context.handle(
        _licensePlateMeta,
        licensePlate.isAcceptableOrUnknown(
          data['license_plate']!,
          _licensePlateMeta,
        ),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VehicleData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VehicleData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      type:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}type'],
          )!,
      licensePlate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}license_plate'],
      ),
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $VehiclesTable createAlias(String alias) {
    return $VehiclesTable(attachedDatabase, alias);
  }
}

class VehicleData extends DataClass implements Insertable<VehicleData> {
  final int id;
  final String name;
  final String type;
  final String? licensePlate;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  const VehicleData({
    required this.id,
    required this.name,
    required this.type,
    this.licensePlate,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || licensePlate != null) {
      map['license_plate'] = Variable<String>(licensePlate);
    }
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  VehiclesCompanion toCompanion(bool nullToAbsent) {
    return VehiclesCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      licensePlate:
          licensePlate == null && nullToAbsent
              ? const Value.absent()
              : Value(licensePlate),
      imagePath:
          imagePath == null && nullToAbsent
              ? const Value.absent()
              : Value(imagePath),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory VehicleData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VehicleData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      licensePlate: serializer.fromJson<String?>(json['licensePlate']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'licensePlate': serializer.toJson<String?>(licensePlate),
      'imagePath': serializer.toJson<String?>(imagePath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  VehicleData copyWith({
    int? id,
    String? name,
    String? type,
    Value<String?> licensePlate = const Value.absent(),
    Value<String?> imagePath = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => VehicleData(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    licensePlate: licensePlate.present ? licensePlate.value : this.licensePlate,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  VehicleData copyWithCompanion(VehiclesCompanion data) {
    return VehicleData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      licensePlate:
          data.licensePlate.present
              ? data.licensePlate.value
              : this.licensePlate,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VehicleData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('licensePlate: $licensePlate, ')
          ..write('imagePath: $imagePath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    licensePlate,
    imagePath,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VehicleData &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.licensePlate == this.licensePlate &&
          other.imagePath == this.imagePath &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class VehiclesCompanion extends UpdateCompanion<VehicleData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> licensePlate;
  final Value<String?> imagePath;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const VehiclesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.licensePlate = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  VehiclesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String type,
    this.licensePlate = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name),
       type = Value(type);
  static Insertable<VehicleData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? licensePlate,
    Expression<String>? imagePath,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (licensePlate != null) 'license_plate': licensePlate,
      if (imagePath != null) 'image_path': imagePath,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  VehiclesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? licensePlate,
    Value<String?>? imagePath,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return VehiclesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      licensePlate: licensePlate ?? this.licensePlate,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (licensePlate.present) {
      map['license_plate'] = Variable<String>(licensePlate.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VehiclesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('licensePlate: $licensePlate, ')
          ..write('imagePath: $imagePath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $CompartmentsTable extends Compartments
    with TableInfo<$CompartmentsTable, CompartmentData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompartmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<int> vehicleId = GeneratedColumn<int>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _gridRowMeta = const VerificationMeta(
    'gridRow',
  );
  @override
  late final GeneratedColumn<int> gridRow = GeneratedColumn<int>(
    'grid_row',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gridColMeta = const VerificationMeta(
    'gridCol',
  );
  @override
  late final GeneratedColumn<int> gridCol = GeneratedColumn<int>(
    'grid_col',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gridColSpanMeta = const VerificationMeta(
    'gridColSpan',
  );
  @override
  late final GeneratedColumn<int> gridColSpan = GeneratedColumn<int>(
    'grid_col_span',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vehicleId,
    label,
    position,
    gridRow,
    gridCol,
    gridColSpan,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'compartments';
  @override
  VerificationContext validateIntegrity(
    Insertable<CompartmentData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('grid_row')) {
      context.handle(
        _gridRowMeta,
        gridRow.isAcceptableOrUnknown(data['grid_row']!, _gridRowMeta),
      );
    }
    if (data.containsKey('grid_col')) {
      context.handle(
        _gridColMeta,
        gridCol.isAcceptableOrUnknown(data['grid_col']!, _gridColMeta),
      );
    }
    if (data.containsKey('grid_col_span')) {
      context.handle(
        _gridColSpanMeta,
        gridColSpan.isAcceptableOrUnknown(
          data['grid_col_span']!,
          _gridColSpanMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CompartmentData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompartmentData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      vehicleId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}vehicle_id'],
          )!,
      label:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}label'],
          )!,
      position:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}position'],
          )!,
      gridRow: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grid_row'],
      ),
      gridCol: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grid_col'],
      ),
      gridColSpan:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}grid_col_span'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $CompartmentsTable createAlias(String alias) {
    return $CompartmentsTable(attachedDatabase, alias);
  }
}

class CompartmentData extends DataClass implements Insertable<CompartmentData> {
  final int id;
  final int vehicleId;
  final String label;
  final int position;
  final int? gridRow;
  final int? gridCol;
  final int gridColSpan;
  final DateTime updatedAt;
  const CompartmentData({
    required this.id,
    required this.vehicleId,
    required this.label,
    required this.position,
    this.gridRow,
    this.gridCol,
    required this.gridColSpan,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['vehicle_id'] = Variable<int>(vehicleId);
    map['label'] = Variable<String>(label);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || gridRow != null) {
      map['grid_row'] = Variable<int>(gridRow);
    }
    if (!nullToAbsent || gridCol != null) {
      map['grid_col'] = Variable<int>(gridCol);
    }
    map['grid_col_span'] = Variable<int>(gridColSpan);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CompartmentsCompanion toCompanion(bool nullToAbsent) {
    return CompartmentsCompanion(
      id: Value(id),
      vehicleId: Value(vehicleId),
      label: Value(label),
      position: Value(position),
      gridRow:
          gridRow == null && nullToAbsent
              ? const Value.absent()
              : Value(gridRow),
      gridCol:
          gridCol == null && nullToAbsent
              ? const Value.absent()
              : Value(gridCol),
      gridColSpan: Value(gridColSpan),
      updatedAt: Value(updatedAt),
    );
  }

  factory CompartmentData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompartmentData(
      id: serializer.fromJson<int>(json['id']),
      vehicleId: serializer.fromJson<int>(json['vehicleId']),
      label: serializer.fromJson<String>(json['label']),
      position: serializer.fromJson<int>(json['position']),
      gridRow: serializer.fromJson<int?>(json['gridRow']),
      gridCol: serializer.fromJson<int?>(json['gridCol']),
      gridColSpan: serializer.fromJson<int>(json['gridColSpan']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'vehicleId': serializer.toJson<int>(vehicleId),
      'label': serializer.toJson<String>(label),
      'position': serializer.toJson<int>(position),
      'gridRow': serializer.toJson<int?>(gridRow),
      'gridCol': serializer.toJson<int?>(gridCol),
      'gridColSpan': serializer.toJson<int>(gridColSpan),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CompartmentData copyWith({
    int? id,
    int? vehicleId,
    String? label,
    int? position,
    Value<int?> gridRow = const Value.absent(),
    Value<int?> gridCol = const Value.absent(),
    int? gridColSpan,
    DateTime? updatedAt,
  }) => CompartmentData(
    id: id ?? this.id,
    vehicleId: vehicleId ?? this.vehicleId,
    label: label ?? this.label,
    position: position ?? this.position,
    gridRow: gridRow.present ? gridRow.value : this.gridRow,
    gridCol: gridCol.present ? gridCol.value : this.gridCol,
    gridColSpan: gridColSpan ?? this.gridColSpan,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CompartmentData copyWithCompanion(CompartmentsCompanion data) {
    return CompartmentData(
      id: data.id.present ? data.id.value : this.id,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      label: data.label.present ? data.label.value : this.label,
      position: data.position.present ? data.position.value : this.position,
      gridRow: data.gridRow.present ? data.gridRow.value : this.gridRow,
      gridCol: data.gridCol.present ? data.gridCol.value : this.gridCol,
      gridColSpan:
          data.gridColSpan.present ? data.gridColSpan.value : this.gridColSpan,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompartmentData(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('label: $label, ')
          ..write('position: $position, ')
          ..write('gridRow: $gridRow, ')
          ..write('gridCol: $gridCol, ')
          ..write('gridColSpan: $gridColSpan, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    label,
    position,
    gridRow,
    gridCol,
    gridColSpan,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompartmentData &&
          other.id == this.id &&
          other.vehicleId == this.vehicleId &&
          other.label == this.label &&
          other.position == this.position &&
          other.gridRow == this.gridRow &&
          other.gridCol == this.gridCol &&
          other.gridColSpan == this.gridColSpan &&
          other.updatedAt == this.updatedAt);
}

class CompartmentsCompanion extends UpdateCompanion<CompartmentData> {
  final Value<int> id;
  final Value<int> vehicleId;
  final Value<String> label;
  final Value<int> position;
  final Value<int?> gridRow;
  final Value<int?> gridCol;
  final Value<int> gridColSpan;
  final Value<DateTime> updatedAt;
  const CompartmentsCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.label = const Value.absent(),
    this.position = const Value.absent(),
    this.gridRow = const Value.absent(),
    this.gridCol = const Value.absent(),
    this.gridColSpan = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  CompartmentsCompanion.insert({
    this.id = const Value.absent(),
    required int vehicleId,
    required String label,
    this.position = const Value.absent(),
    this.gridRow = const Value.absent(),
    this.gridCol = const Value.absent(),
    this.gridColSpan = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : vehicleId = Value(vehicleId),
       label = Value(label);
  static Insertable<CompartmentData> custom({
    Expression<int>? id,
    Expression<int>? vehicleId,
    Expression<String>? label,
    Expression<int>? position,
    Expression<int>? gridRow,
    Expression<int>? gridCol,
    Expression<int>? gridColSpan,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (label != null) 'label': label,
      if (position != null) 'position': position,
      if (gridRow != null) 'grid_row': gridRow,
      if (gridCol != null) 'grid_col': gridCol,
      if (gridColSpan != null) 'grid_col_span': gridColSpan,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  CompartmentsCompanion copyWith({
    Value<int>? id,
    Value<int>? vehicleId,
    Value<String>? label,
    Value<int>? position,
    Value<int?>? gridRow,
    Value<int?>? gridCol,
    Value<int>? gridColSpan,
    Value<DateTime>? updatedAt,
  }) {
    return CompartmentsCompanion(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      label: label ?? this.label,
      position: position ?? this.position,
      gridRow: gridRow ?? this.gridRow,
      gridCol: gridCol ?? this.gridCol,
      gridColSpan: gridColSpan ?? this.gridColSpan,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<int>(vehicleId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (gridRow.present) {
      map['grid_row'] = Variable<int>(gridRow.value);
    }
    if (gridCol.present) {
      map['grid_col'] = Variable<int>(gridCol.value);
    }
    if (gridColSpan.present) {
      map['grid_col_span'] = Variable<int>(gridColSpan.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompartmentsCompanion(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('label: $label, ')
          ..write('position: $position, ')
          ..write('gridRow: $gridRow, ')
          ..write('gridCol: $gridCol, ')
          ..write('gridColSpan: $gridColSpan, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $EquipmentItemsTable extends EquipmentItems
    with TableInfo<$EquipmentItemsTable, EquipmentItemData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EquipmentItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shortNameMeta = const VerificationMeta(
    'shortName',
  );
  @override
  late final GeneratedColumn<String> shortName = GeneratedColumn<String>(
    'short_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _equipmentFunctionsJsonMeta =
      const VerificationMeta('equipmentFunctionsJson');
  @override
  late final GeneratedColumn<String> equipmentFunctionsJson =
      GeneratedColumn<String>(
        'equipment_functions_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _deploymentScenariosJsonMeta =
      const VerificationMeta('deploymentScenariosJson');
  @override
  late final GeneratedColumn<String> deploymentScenariosJson =
      GeneratedColumn<String>(
        'deployment_scenarios_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trainingUrlMeta = const VerificationMeta(
    'trainingUrl',
  );
  @override
  late final GeneratedColumn<String> trainingUrl = GeneratedColumn<String>(
    'training_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _libraryEquipmentIdMeta =
      const VerificationMeta('libraryEquipmentId');
  @override
  late final GeneratedColumn<String> libraryEquipmentId =
      GeneratedColumn<String>(
        'library_equipment_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isCustomMeta = const VerificationMeta(
    'isCustom',
  );
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
    'is_custom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_custom" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _extraAttributesJsonMeta =
      const VerificationMeta('extraAttributesJson');
  @override
  late final GeneratedColumn<String> extraAttributesJson =
      GeneratedColumn<String>(
        'extra_attributes_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      );
  static const VerificationMeta _trainingQuestionsJsonMeta =
      const VerificationMeta('trainingQuestionsJson');
  @override
  late final GeneratedColumn<String> trainingQuestionsJson =
      GeneratedColumn<String>(
        'training_questions_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _typicalUseJsonMeta = const VerificationMeta(
    'typicalUseJson',
  );
  @override
  late final GeneratedColumn<String> typicalUseJson = GeneratedColumn<String>(
    'typical_use_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    shortName,
    equipmentFunctionsJson,
    deploymentScenariosJson,
    description,
    imagePath,
    trainingUrl,
    libraryEquipmentId,
    isCustom,
    extraAttributesJson,
    trainingQuestionsJson,
    typicalUseJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'equipment_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<EquipmentItemData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('short_name')) {
      context.handle(
        _shortNameMeta,
        shortName.isAcceptableOrUnknown(data['short_name']!, _shortNameMeta),
      );
    }
    if (data.containsKey('equipment_functions_json')) {
      context.handle(
        _equipmentFunctionsJsonMeta,
        equipmentFunctionsJson.isAcceptableOrUnknown(
          data['equipment_functions_json']!,
          _equipmentFunctionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('deployment_scenarios_json')) {
      context.handle(
        _deploymentScenariosJsonMeta,
        deploymentScenariosJson.isAcceptableOrUnknown(
          data['deployment_scenarios_json']!,
          _deploymentScenariosJsonMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('training_url')) {
      context.handle(
        _trainingUrlMeta,
        trainingUrl.isAcceptableOrUnknown(
          data['training_url']!,
          _trainingUrlMeta,
        ),
      );
    }
    if (data.containsKey('library_equipment_id')) {
      context.handle(
        _libraryEquipmentIdMeta,
        libraryEquipmentId.isAcceptableOrUnknown(
          data['library_equipment_id']!,
          _libraryEquipmentIdMeta,
        ),
      );
    }
    if (data.containsKey('is_custom')) {
      context.handle(
        _isCustomMeta,
        isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta),
      );
    }
    if (data.containsKey('extra_attributes_json')) {
      context.handle(
        _extraAttributesJsonMeta,
        extraAttributesJson.isAcceptableOrUnknown(
          data['extra_attributes_json']!,
          _extraAttributesJsonMeta,
        ),
      );
    }
    if (data.containsKey('training_questions_json')) {
      context.handle(
        _trainingQuestionsJsonMeta,
        trainingQuestionsJson.isAcceptableOrUnknown(
          data['training_questions_json']!,
          _trainingQuestionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('typical_use_json')) {
      context.handle(
        _typicalUseJsonMeta,
        typicalUseJson.isAcceptableOrUnknown(
          data['typical_use_json']!,
          _typicalUseJsonMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EquipmentItemData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EquipmentItemData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      shortName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}short_name'],
      ),
      equipmentFunctionsJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}equipment_functions_json'],
          )!,
      deploymentScenariosJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}deployment_scenarios_json'],
          )!,
      description:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}description'],
          )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      trainingUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}training_url'],
      ),
      libraryEquipmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}library_equipment_id'],
      ),
      isCustom:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_custom'],
          )!,
      extraAttributesJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}extra_attributes_json'],
          )!,
      trainingQuestionsJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}training_questions_json'],
          )!,
      typicalUseJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}typical_use_json'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $EquipmentItemsTable createAlias(String alias) {
    return $EquipmentItemsTable(attachedDatabase, alias);
  }
}

class EquipmentItemData extends DataClass
    implements Insertable<EquipmentItemData> {
  final int id;
  final String name;
  final String? shortName;
  final String equipmentFunctionsJson;
  final String deploymentScenariosJson;
  final String description;
  final String? imagePath;
  final String? trainingUrl;
  final String? libraryEquipmentId;
  final bool isCustom;
  final String extraAttributesJson;
  final String trainingQuestionsJson;
  final String typicalUseJson;
  final DateTime updatedAt;
  const EquipmentItemData({
    required this.id,
    required this.name,
    this.shortName,
    required this.equipmentFunctionsJson,
    required this.deploymentScenariosJson,
    required this.description,
    this.imagePath,
    this.trainingUrl,
    this.libraryEquipmentId,
    required this.isCustom,
    required this.extraAttributesJson,
    required this.trainingQuestionsJson,
    required this.typicalUseJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || shortName != null) {
      map['short_name'] = Variable<String>(shortName);
    }
    map['equipment_functions_json'] = Variable<String>(equipmentFunctionsJson);
    map['deployment_scenarios_json'] = Variable<String>(
      deploymentScenariosJson,
    );
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    if (!nullToAbsent || trainingUrl != null) {
      map['training_url'] = Variable<String>(trainingUrl);
    }
    if (!nullToAbsent || libraryEquipmentId != null) {
      map['library_equipment_id'] = Variable<String>(libraryEquipmentId);
    }
    map['is_custom'] = Variable<bool>(isCustom);
    map['extra_attributes_json'] = Variable<String>(extraAttributesJson);
    map['training_questions_json'] = Variable<String>(trainingQuestionsJson);
    map['typical_use_json'] = Variable<String>(typicalUseJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EquipmentItemsCompanion toCompanion(bool nullToAbsent) {
    return EquipmentItemsCompanion(
      id: Value(id),
      name: Value(name),
      shortName:
          shortName == null && nullToAbsent
              ? const Value.absent()
              : Value(shortName),
      equipmentFunctionsJson: Value(equipmentFunctionsJson),
      deploymentScenariosJson: Value(deploymentScenariosJson),
      description: Value(description),
      imagePath:
          imagePath == null && nullToAbsent
              ? const Value.absent()
              : Value(imagePath),
      trainingUrl:
          trainingUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(trainingUrl),
      libraryEquipmentId:
          libraryEquipmentId == null && nullToAbsent
              ? const Value.absent()
              : Value(libraryEquipmentId),
      isCustom: Value(isCustom),
      extraAttributesJson: Value(extraAttributesJson),
      trainingQuestionsJson: Value(trainingQuestionsJson),
      typicalUseJson: Value(typicalUseJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory EquipmentItemData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EquipmentItemData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      shortName: serializer.fromJson<String?>(json['shortName']),
      equipmentFunctionsJson: serializer.fromJson<String>(
        json['equipmentFunctionsJson'],
      ),
      deploymentScenariosJson: serializer.fromJson<String>(
        json['deploymentScenariosJson'],
      ),
      description: serializer.fromJson<String>(json['description']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      trainingUrl: serializer.fromJson<String?>(json['trainingUrl']),
      libraryEquipmentId: serializer.fromJson<String?>(
        json['libraryEquipmentId'],
      ),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
      extraAttributesJson: serializer.fromJson<String>(
        json['extraAttributesJson'],
      ),
      trainingQuestionsJson: serializer.fromJson<String>(
        json['trainingQuestionsJson'],
      ),
      typicalUseJson: serializer.fromJson<String>(json['typicalUseJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'shortName': serializer.toJson<String?>(shortName),
      'equipmentFunctionsJson': serializer.toJson<String>(
        equipmentFunctionsJson,
      ),
      'deploymentScenariosJson': serializer.toJson<String>(
        deploymentScenariosJson,
      ),
      'description': serializer.toJson<String>(description),
      'imagePath': serializer.toJson<String?>(imagePath),
      'trainingUrl': serializer.toJson<String?>(trainingUrl),
      'libraryEquipmentId': serializer.toJson<String?>(libraryEquipmentId),
      'isCustom': serializer.toJson<bool>(isCustom),
      'extraAttributesJson': serializer.toJson<String>(extraAttributesJson),
      'trainingQuestionsJson': serializer.toJson<String>(trainingQuestionsJson),
      'typicalUseJson': serializer.toJson<String>(typicalUseJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  EquipmentItemData copyWith({
    int? id,
    String? name,
    Value<String?> shortName = const Value.absent(),
    String? equipmentFunctionsJson,
    String? deploymentScenariosJson,
    String? description,
    Value<String?> imagePath = const Value.absent(),
    Value<String?> trainingUrl = const Value.absent(),
    Value<String?> libraryEquipmentId = const Value.absent(),
    bool? isCustom,
    String? extraAttributesJson,
    String? trainingQuestionsJson,
    String? typicalUseJson,
    DateTime? updatedAt,
  }) => EquipmentItemData(
    id: id ?? this.id,
    name: name ?? this.name,
    shortName: shortName.present ? shortName.value : this.shortName,
    equipmentFunctionsJson:
        equipmentFunctionsJson ?? this.equipmentFunctionsJson,
    deploymentScenariosJson:
        deploymentScenariosJson ?? this.deploymentScenariosJson,
    description: description ?? this.description,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    trainingUrl: trainingUrl.present ? trainingUrl.value : this.trainingUrl,
    libraryEquipmentId:
        libraryEquipmentId.present
            ? libraryEquipmentId.value
            : this.libraryEquipmentId,
    isCustom: isCustom ?? this.isCustom,
    extraAttributesJson: extraAttributesJson ?? this.extraAttributesJson,
    trainingQuestionsJson: trainingQuestionsJson ?? this.trainingQuestionsJson,
    typicalUseJson: typicalUseJson ?? this.typicalUseJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EquipmentItemData copyWithCompanion(EquipmentItemsCompanion data) {
    return EquipmentItemData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      shortName: data.shortName.present ? data.shortName.value : this.shortName,
      equipmentFunctionsJson:
          data.equipmentFunctionsJson.present
              ? data.equipmentFunctionsJson.value
              : this.equipmentFunctionsJson,
      deploymentScenariosJson:
          data.deploymentScenariosJson.present
              ? data.deploymentScenariosJson.value
              : this.deploymentScenariosJson,
      description:
          data.description.present ? data.description.value : this.description,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      trainingUrl:
          data.trainingUrl.present ? data.trainingUrl.value : this.trainingUrl,
      libraryEquipmentId:
          data.libraryEquipmentId.present
              ? data.libraryEquipmentId.value
              : this.libraryEquipmentId,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
      extraAttributesJson:
          data.extraAttributesJson.present
              ? data.extraAttributesJson.value
              : this.extraAttributesJson,
      trainingQuestionsJson:
          data.trainingQuestionsJson.present
              ? data.trainingQuestionsJson.value
              : this.trainingQuestionsJson,
      typicalUseJson:
          data.typicalUseJson.present
              ? data.typicalUseJson.value
              : this.typicalUseJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EquipmentItemData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('shortName: $shortName, ')
          ..write('equipmentFunctionsJson: $equipmentFunctionsJson, ')
          ..write('deploymentScenariosJson: $deploymentScenariosJson, ')
          ..write('description: $description, ')
          ..write('imagePath: $imagePath, ')
          ..write('trainingUrl: $trainingUrl, ')
          ..write('libraryEquipmentId: $libraryEquipmentId, ')
          ..write('isCustom: $isCustom, ')
          ..write('extraAttributesJson: $extraAttributesJson, ')
          ..write('trainingQuestionsJson: $trainingQuestionsJson, ')
          ..write('typicalUseJson: $typicalUseJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    shortName,
    equipmentFunctionsJson,
    deploymentScenariosJson,
    description,
    imagePath,
    trainingUrl,
    libraryEquipmentId,
    isCustom,
    extraAttributesJson,
    trainingQuestionsJson,
    typicalUseJson,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EquipmentItemData &&
          other.id == this.id &&
          other.name == this.name &&
          other.shortName == this.shortName &&
          other.equipmentFunctionsJson == this.equipmentFunctionsJson &&
          other.deploymentScenariosJson == this.deploymentScenariosJson &&
          other.description == this.description &&
          other.imagePath == this.imagePath &&
          other.trainingUrl == this.trainingUrl &&
          other.libraryEquipmentId == this.libraryEquipmentId &&
          other.isCustom == this.isCustom &&
          other.extraAttributesJson == this.extraAttributesJson &&
          other.trainingQuestionsJson == this.trainingQuestionsJson &&
          other.typicalUseJson == this.typicalUseJson &&
          other.updatedAt == this.updatedAt);
}

class EquipmentItemsCompanion extends UpdateCompanion<EquipmentItemData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> shortName;
  final Value<String> equipmentFunctionsJson;
  final Value<String> deploymentScenariosJson;
  final Value<String> description;
  final Value<String?> imagePath;
  final Value<String?> trainingUrl;
  final Value<String?> libraryEquipmentId;
  final Value<bool> isCustom;
  final Value<String> extraAttributesJson;
  final Value<String> trainingQuestionsJson;
  final Value<String> typicalUseJson;
  final Value<DateTime> updatedAt;
  const EquipmentItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.shortName = const Value.absent(),
    this.equipmentFunctionsJson = const Value.absent(),
    this.deploymentScenariosJson = const Value.absent(),
    this.description = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.trainingUrl = const Value.absent(),
    this.libraryEquipmentId = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.extraAttributesJson = const Value.absent(),
    this.trainingQuestionsJson = const Value.absent(),
    this.typicalUseJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  EquipmentItemsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.shortName = const Value.absent(),
    this.equipmentFunctionsJson = const Value.absent(),
    this.deploymentScenariosJson = const Value.absent(),
    this.description = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.trainingUrl = const Value.absent(),
    this.libraryEquipmentId = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.extraAttributesJson = const Value.absent(),
    this.trainingQuestionsJson = const Value.absent(),
    this.typicalUseJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<EquipmentItemData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? shortName,
    Expression<String>? equipmentFunctionsJson,
    Expression<String>? deploymentScenariosJson,
    Expression<String>? description,
    Expression<String>? imagePath,
    Expression<String>? trainingUrl,
    Expression<String>? libraryEquipmentId,
    Expression<bool>? isCustom,
    Expression<String>? extraAttributesJson,
    Expression<String>? trainingQuestionsJson,
    Expression<String>? typicalUseJson,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (shortName != null) 'short_name': shortName,
      if (equipmentFunctionsJson != null)
        'equipment_functions_json': equipmentFunctionsJson,
      if (deploymentScenariosJson != null)
        'deployment_scenarios_json': deploymentScenariosJson,
      if (description != null) 'description': description,
      if (imagePath != null) 'image_path': imagePath,
      if (trainingUrl != null) 'training_url': trainingUrl,
      if (libraryEquipmentId != null)
        'library_equipment_id': libraryEquipmentId,
      if (isCustom != null) 'is_custom': isCustom,
      if (extraAttributesJson != null)
        'extra_attributes_json': extraAttributesJson,
      if (trainingQuestionsJson != null)
        'training_questions_json': trainingQuestionsJson,
      if (typicalUseJson != null) 'typical_use_json': typicalUseJson,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  EquipmentItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? shortName,
    Value<String>? equipmentFunctionsJson,
    Value<String>? deploymentScenariosJson,
    Value<String>? description,
    Value<String?>? imagePath,
    Value<String?>? trainingUrl,
    Value<String?>? libraryEquipmentId,
    Value<bool>? isCustom,
    Value<String>? extraAttributesJson,
    Value<String>? trainingQuestionsJson,
    Value<String>? typicalUseJson,
    Value<DateTime>? updatedAt,
  }) {
    return EquipmentItemsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      equipmentFunctionsJson:
          equipmentFunctionsJson ?? this.equipmentFunctionsJson,
      deploymentScenariosJson:
          deploymentScenariosJson ?? this.deploymentScenariosJson,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      trainingUrl: trainingUrl ?? this.trainingUrl,
      libraryEquipmentId: libraryEquipmentId ?? this.libraryEquipmentId,
      isCustom: isCustom ?? this.isCustom,
      extraAttributesJson: extraAttributesJson ?? this.extraAttributesJson,
      trainingQuestionsJson:
          trainingQuestionsJson ?? this.trainingQuestionsJson,
      typicalUseJson: typicalUseJson ?? this.typicalUseJson,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (shortName.present) {
      map['short_name'] = Variable<String>(shortName.value);
    }
    if (equipmentFunctionsJson.present) {
      map['equipment_functions_json'] = Variable<String>(
        equipmentFunctionsJson.value,
      );
    }
    if (deploymentScenariosJson.present) {
      map['deployment_scenarios_json'] = Variable<String>(
        deploymentScenariosJson.value,
      );
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (trainingUrl.present) {
      map['training_url'] = Variable<String>(trainingUrl.value);
    }
    if (libraryEquipmentId.present) {
      map['library_equipment_id'] = Variable<String>(libraryEquipmentId.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    if (extraAttributesJson.present) {
      map['extra_attributes_json'] = Variable<String>(
        extraAttributesJson.value,
      );
    }
    if (trainingQuestionsJson.present) {
      map['training_questions_json'] = Variable<String>(
        trainingQuestionsJson.value,
      );
    }
    if (typicalUseJson.present) {
      map['typical_use_json'] = Variable<String>(typicalUseJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EquipmentItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('shortName: $shortName, ')
          ..write('equipmentFunctionsJson: $equipmentFunctionsJson, ')
          ..write('deploymentScenariosJson: $deploymentScenariosJson, ')
          ..write('description: $description, ')
          ..write('imagePath: $imagePath, ')
          ..write('trainingUrl: $trainingUrl, ')
          ..write('libraryEquipmentId: $libraryEquipmentId, ')
          ..write('isCustom: $isCustom, ')
          ..write('extraAttributesJson: $extraAttributesJson, ')
          ..write('trainingQuestionsJson: $trainingQuestionsJson, ')
          ..write('typicalUseJson: $typicalUseJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $EquipmentAssignmentsTable extends EquipmentAssignments
    with TableInfo<$EquipmentAssignmentsTable, AssignmentData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EquipmentAssignmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _compartmentIdMeta = const VerificationMeta(
    'compartmentId',
  );
  @override
  late final GeneratedColumn<int> compartmentId = GeneratedColumn<int>(
    'compartment_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES compartments (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _equipmentIdMeta = const VerificationMeta(
    'equipmentId',
  );
  @override
  late final GeneratedColumn<int> equipmentId = GeneratedColumn<int>(
    'equipment_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES equipment_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    compartmentId,
    equipmentId,
    quantity,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'equipment_assignments';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssignmentData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('compartment_id')) {
      context.handle(
        _compartmentIdMeta,
        compartmentId.isAcceptableOrUnknown(
          data['compartment_id']!,
          _compartmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_compartmentIdMeta);
    }
    if (data.containsKey('equipment_id')) {
      context.handle(
        _equipmentIdMeta,
        equipmentId.isAcceptableOrUnknown(
          data['equipment_id']!,
          _equipmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_equipmentIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AssignmentData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssignmentData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      compartmentId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}compartment_id'],
          )!,
      equipmentId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}equipment_id'],
          )!,
      quantity:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}quantity'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $EquipmentAssignmentsTable createAlias(String alias) {
    return $EquipmentAssignmentsTable(attachedDatabase, alias);
  }
}

class AssignmentData extends DataClass implements Insertable<AssignmentData> {
  final int id;
  final int compartmentId;
  final int equipmentId;
  final int quantity;
  final DateTime updatedAt;
  const AssignmentData({
    required this.id,
    required this.compartmentId,
    required this.equipmentId,
    required this.quantity,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['compartment_id'] = Variable<int>(compartmentId);
    map['equipment_id'] = Variable<int>(equipmentId);
    map['quantity'] = Variable<int>(quantity);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EquipmentAssignmentsCompanion toCompanion(bool nullToAbsent) {
    return EquipmentAssignmentsCompanion(
      id: Value(id),
      compartmentId: Value(compartmentId),
      equipmentId: Value(equipmentId),
      quantity: Value(quantity),
      updatedAt: Value(updatedAt),
    );
  }

  factory AssignmentData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssignmentData(
      id: serializer.fromJson<int>(json['id']),
      compartmentId: serializer.fromJson<int>(json['compartmentId']),
      equipmentId: serializer.fromJson<int>(json['equipmentId']),
      quantity: serializer.fromJson<int>(json['quantity']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'compartmentId': serializer.toJson<int>(compartmentId),
      'equipmentId': serializer.toJson<int>(equipmentId),
      'quantity': serializer.toJson<int>(quantity),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AssignmentData copyWith({
    int? id,
    int? compartmentId,
    int? equipmentId,
    int? quantity,
    DateTime? updatedAt,
  }) => AssignmentData(
    id: id ?? this.id,
    compartmentId: compartmentId ?? this.compartmentId,
    equipmentId: equipmentId ?? this.equipmentId,
    quantity: quantity ?? this.quantity,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AssignmentData copyWithCompanion(EquipmentAssignmentsCompanion data) {
    return AssignmentData(
      id: data.id.present ? data.id.value : this.id,
      compartmentId:
          data.compartmentId.present
              ? data.compartmentId.value
              : this.compartmentId,
      equipmentId:
          data.equipmentId.present ? data.equipmentId.value : this.equipmentId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssignmentData(')
          ..write('id: $id, ')
          ..write('compartmentId: $compartmentId, ')
          ..write('equipmentId: $equipmentId, ')
          ..write('quantity: $quantity, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, compartmentId, equipmentId, quantity, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssignmentData &&
          other.id == this.id &&
          other.compartmentId == this.compartmentId &&
          other.equipmentId == this.equipmentId &&
          other.quantity == this.quantity &&
          other.updatedAt == this.updatedAt);
}

class EquipmentAssignmentsCompanion extends UpdateCompanion<AssignmentData> {
  final Value<int> id;
  final Value<int> compartmentId;
  final Value<int> equipmentId;
  final Value<int> quantity;
  final Value<DateTime> updatedAt;
  const EquipmentAssignmentsCompanion({
    this.id = const Value.absent(),
    this.compartmentId = const Value.absent(),
    this.equipmentId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  EquipmentAssignmentsCompanion.insert({
    this.id = const Value.absent(),
    required int compartmentId,
    required int equipmentId,
    this.quantity = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : compartmentId = Value(compartmentId),
       equipmentId = Value(equipmentId);
  static Insertable<AssignmentData> custom({
    Expression<int>? id,
    Expression<int>? compartmentId,
    Expression<int>? equipmentId,
    Expression<int>? quantity,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (compartmentId != null) 'compartment_id': compartmentId,
      if (equipmentId != null) 'equipment_id': equipmentId,
      if (quantity != null) 'quantity': quantity,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  EquipmentAssignmentsCompanion copyWith({
    Value<int>? id,
    Value<int>? compartmentId,
    Value<int>? equipmentId,
    Value<int>? quantity,
    Value<DateTime>? updatedAt,
  }) {
    return EquipmentAssignmentsCompanion(
      id: id ?? this.id,
      compartmentId: compartmentId ?? this.compartmentId,
      equipmentId: equipmentId ?? this.equipmentId,
      quantity: quantity ?? this.quantity,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (compartmentId.present) {
      map['compartment_id'] = Variable<int>(compartmentId.value);
    }
    if (equipmentId.present) {
      map['equipment_id'] = Variable<int>(equipmentId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EquipmentAssignmentsCompanion(')
          ..write('id: $id, ')
          ..write('compartmentId: $compartmentId, ')
          ..write('equipmentId: $equipmentId, ')
          ..write('quantity: $quantity, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $QuizResultsTable extends QuizResults
    with TableInfo<$QuizResultsTable, QuizResultData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuizResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _quizTypeMeta = const VerificationMeta(
    'quizType',
  );
  @override
  late final GeneratedColumn<String> quizType = GeneratedColumn<String>(
    'quiz_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<int> vehicleId = GeneratedColumn<int>(
    'vehicle_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _playedAtMeta = const VerificationMeta(
    'playedAt',
  );
  @override
  late final GeneratedColumn<DateTime> playedAt = GeneratedColumn<DateTime>(
    'played_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    quizType,
    score,
    total,
    vehicleId,
    playedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quiz_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuizResultData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('quiz_type')) {
      context.handle(
        _quizTypeMeta,
        quizType.isAcceptableOrUnknown(data['quiz_type']!, _quizTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_quizTypeMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    }
    if (data.containsKey('played_at')) {
      context.handle(
        _playedAtMeta,
        playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QuizResultData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuizResultData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      quizType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}quiz_type'],
          )!,
      score:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}score'],
          )!,
      total:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}total'],
          )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}vehicle_id'],
      ),
      playedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}played_at'],
          )!,
    );
  }

  @override
  $QuizResultsTable createAlias(String alias) {
    return $QuizResultsTable(attachedDatabase, alias);
  }
}

class QuizResultData extends DataClass implements Insertable<QuizResultData> {
  final int id;
  final String quizType;
  final int score;
  final int total;
  final int? vehicleId;
  final DateTime playedAt;
  const QuizResultData({
    required this.id,
    required this.quizType,
    required this.score,
    required this.total,
    this.vehicleId,
    required this.playedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['quiz_type'] = Variable<String>(quizType);
    map['score'] = Variable<int>(score);
    map['total'] = Variable<int>(total);
    if (!nullToAbsent || vehicleId != null) {
      map['vehicle_id'] = Variable<int>(vehicleId);
    }
    map['played_at'] = Variable<DateTime>(playedAt);
    return map;
  }

  QuizResultsCompanion toCompanion(bool nullToAbsent) {
    return QuizResultsCompanion(
      id: Value(id),
      quizType: Value(quizType),
      score: Value(score),
      total: Value(total),
      vehicleId:
          vehicleId == null && nullToAbsent
              ? const Value.absent()
              : Value(vehicleId),
      playedAt: Value(playedAt),
    );
  }

  factory QuizResultData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuizResultData(
      id: serializer.fromJson<int>(json['id']),
      quizType: serializer.fromJson<String>(json['quizType']),
      score: serializer.fromJson<int>(json['score']),
      total: serializer.fromJson<int>(json['total']),
      vehicleId: serializer.fromJson<int?>(json['vehicleId']),
      playedAt: serializer.fromJson<DateTime>(json['playedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'quizType': serializer.toJson<String>(quizType),
      'score': serializer.toJson<int>(score),
      'total': serializer.toJson<int>(total),
      'vehicleId': serializer.toJson<int?>(vehicleId),
      'playedAt': serializer.toJson<DateTime>(playedAt),
    };
  }

  QuizResultData copyWith({
    int? id,
    String? quizType,
    int? score,
    int? total,
    Value<int?> vehicleId = const Value.absent(),
    DateTime? playedAt,
  }) => QuizResultData(
    id: id ?? this.id,
    quizType: quizType ?? this.quizType,
    score: score ?? this.score,
    total: total ?? this.total,
    vehicleId: vehicleId.present ? vehicleId.value : this.vehicleId,
    playedAt: playedAt ?? this.playedAt,
  );
  QuizResultData copyWithCompanion(QuizResultsCompanion data) {
    return QuizResultData(
      id: data.id.present ? data.id.value : this.id,
      quizType: data.quizType.present ? data.quizType.value : this.quizType,
      score: data.score.present ? data.score.value : this.score,
      total: data.total.present ? data.total.value : this.total,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuizResultData(')
          ..write('id: $id, ')
          ..write('quizType: $quizType, ')
          ..write('score: $score, ')
          ..write('total: $total, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('playedAt: $playedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, quizType, score, total, vehicleId, playedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuizResultData &&
          other.id == this.id &&
          other.quizType == this.quizType &&
          other.score == this.score &&
          other.total == this.total &&
          other.vehicleId == this.vehicleId &&
          other.playedAt == this.playedAt);
}

class QuizResultsCompanion extends UpdateCompanion<QuizResultData> {
  final Value<int> id;
  final Value<String> quizType;
  final Value<int> score;
  final Value<int> total;
  final Value<int?> vehicleId;
  final Value<DateTime> playedAt;
  const QuizResultsCompanion({
    this.id = const Value.absent(),
    this.quizType = const Value.absent(),
    this.score = const Value.absent(),
    this.total = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.playedAt = const Value.absent(),
  });
  QuizResultsCompanion.insert({
    this.id = const Value.absent(),
    required String quizType,
    required int score,
    required int total,
    this.vehicleId = const Value.absent(),
    this.playedAt = const Value.absent(),
  }) : quizType = Value(quizType),
       score = Value(score),
       total = Value(total);
  static Insertable<QuizResultData> custom({
    Expression<int>? id,
    Expression<String>? quizType,
    Expression<int>? score,
    Expression<int>? total,
    Expression<int>? vehicleId,
    Expression<DateTime>? playedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (quizType != null) 'quiz_type': quizType,
      if (score != null) 'score': score,
      if (total != null) 'total': total,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (playedAt != null) 'played_at': playedAt,
    });
  }

  QuizResultsCompanion copyWith({
    Value<int>? id,
    Value<String>? quizType,
    Value<int>? score,
    Value<int>? total,
    Value<int?>? vehicleId,
    Value<DateTime>? playedAt,
  }) {
    return QuizResultsCompanion(
      id: id ?? this.id,
      quizType: quizType ?? this.quizType,
      score: score ?? this.score,
      total: total ?? this.total,
      vehicleId: vehicleId ?? this.vehicleId,
      playedAt: playedAt ?? this.playedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (quizType.present) {
      map['quiz_type'] = Variable<String>(quizType.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<int>(vehicleId.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<DateTime>(playedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuizResultsCompanion(')
          ..write('id: $id, ')
          ..write('quizType: $quizType, ')
          ..write('score: $score, ')
          ..write('total: $total, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('playedAt: $playedAt')
          ..write(')'))
        .toString();
  }
}

class $EquipmentInstancesTable extends EquipmentInstances
    with TableInfo<$EquipmentInstancesTable, EquipmentInstanceData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EquipmentInstancesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _equipmentIdMeta = const VerificationMeta(
    'equipmentId',
  );
  @override
  late final GeneratedColumn<int> equipmentId = GeneratedColumn<int>(
    'equipment_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES equipment_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<int> vehicleId = GeneratedColumn<int>(
    'vehicle_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _compartmentIdMeta = const VerificationMeta(
    'compartmentId',
  );
  @override
  late final GeneratedColumn<int> compartmentId = GeneratedColumn<int>(
    'compartment_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES compartments (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _identifierMeta = const VerificationMeta(
    'identifier',
  );
  @override
  late final GeneratedColumn<String> identifier = GeneratedColumn<String>(
    'identifier',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    equipmentId,
    vehicleId,
    compartmentId,
    identifier,
    notes,
    isActive,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'equipment_instances';
  @override
  VerificationContext validateIntegrity(
    Insertable<EquipmentInstanceData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('equipment_id')) {
      context.handle(
        _equipmentIdMeta,
        equipmentId.isAcceptableOrUnknown(
          data['equipment_id']!,
          _equipmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_equipmentIdMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    }
    if (data.containsKey('compartment_id')) {
      context.handle(
        _compartmentIdMeta,
        compartmentId.isAcceptableOrUnknown(
          data['compartment_id']!,
          _compartmentIdMeta,
        ),
      );
    }
    if (data.containsKey('identifier')) {
      context.handle(
        _identifierMeta,
        identifier.isAcceptableOrUnknown(data['identifier']!, _identifierMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EquipmentInstanceData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EquipmentInstanceData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      equipmentId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}equipment_id'],
          )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}vehicle_id'],
      ),
      compartmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}compartment_id'],
      ),
      identifier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}identifier'],
      ),
      notes:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}notes'],
          )!,
      isActive:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_active'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $EquipmentInstancesTable createAlias(String alias) {
    return $EquipmentInstancesTable(attachedDatabase, alias);
  }
}

class EquipmentInstanceData extends DataClass
    implements Insertable<EquipmentInstanceData> {
  final int id;
  final int equipmentId;
  final int? vehicleId;
  final int? compartmentId;
  final String? identifier;
  final String notes;
  final bool isActive;
  final DateTime updatedAt;
  const EquipmentInstanceData({
    required this.id,
    required this.equipmentId,
    this.vehicleId,
    this.compartmentId,
    this.identifier,
    required this.notes,
    required this.isActive,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['equipment_id'] = Variable<int>(equipmentId);
    if (!nullToAbsent || vehicleId != null) {
      map['vehicle_id'] = Variable<int>(vehicleId);
    }
    if (!nullToAbsent || compartmentId != null) {
      map['compartment_id'] = Variable<int>(compartmentId);
    }
    if (!nullToAbsent || identifier != null) {
      map['identifier'] = Variable<String>(identifier);
    }
    map['notes'] = Variable<String>(notes);
    map['is_active'] = Variable<bool>(isActive);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EquipmentInstancesCompanion toCompanion(bool nullToAbsent) {
    return EquipmentInstancesCompanion(
      id: Value(id),
      equipmentId: Value(equipmentId),
      vehicleId:
          vehicleId == null && nullToAbsent
              ? const Value.absent()
              : Value(vehicleId),
      compartmentId:
          compartmentId == null && nullToAbsent
              ? const Value.absent()
              : Value(compartmentId),
      identifier:
          identifier == null && nullToAbsent
              ? const Value.absent()
              : Value(identifier),
      notes: Value(notes),
      isActive: Value(isActive),
      updatedAt: Value(updatedAt),
    );
  }

  factory EquipmentInstanceData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EquipmentInstanceData(
      id: serializer.fromJson<int>(json['id']),
      equipmentId: serializer.fromJson<int>(json['equipmentId']),
      vehicleId: serializer.fromJson<int?>(json['vehicleId']),
      compartmentId: serializer.fromJson<int?>(json['compartmentId']),
      identifier: serializer.fromJson<String?>(json['identifier']),
      notes: serializer.fromJson<String>(json['notes']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'equipmentId': serializer.toJson<int>(equipmentId),
      'vehicleId': serializer.toJson<int?>(vehicleId),
      'compartmentId': serializer.toJson<int?>(compartmentId),
      'identifier': serializer.toJson<String?>(identifier),
      'notes': serializer.toJson<String>(notes),
      'isActive': serializer.toJson<bool>(isActive),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  EquipmentInstanceData copyWith({
    int? id,
    int? equipmentId,
    Value<int?> vehicleId = const Value.absent(),
    Value<int?> compartmentId = const Value.absent(),
    Value<String?> identifier = const Value.absent(),
    String? notes,
    bool? isActive,
    DateTime? updatedAt,
  }) => EquipmentInstanceData(
    id: id ?? this.id,
    equipmentId: equipmentId ?? this.equipmentId,
    vehicleId: vehicleId.present ? vehicleId.value : this.vehicleId,
    compartmentId:
        compartmentId.present ? compartmentId.value : this.compartmentId,
    identifier: identifier.present ? identifier.value : this.identifier,
    notes: notes ?? this.notes,
    isActive: isActive ?? this.isActive,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EquipmentInstanceData copyWithCompanion(EquipmentInstancesCompanion data) {
    return EquipmentInstanceData(
      id: data.id.present ? data.id.value : this.id,
      equipmentId:
          data.equipmentId.present ? data.equipmentId.value : this.equipmentId,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      compartmentId:
          data.compartmentId.present
              ? data.compartmentId.value
              : this.compartmentId,
      identifier:
          data.identifier.present ? data.identifier.value : this.identifier,
      notes: data.notes.present ? data.notes.value : this.notes,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EquipmentInstanceData(')
          ..write('id: $id, ')
          ..write('equipmentId: $equipmentId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('compartmentId: $compartmentId, ')
          ..write('identifier: $identifier, ')
          ..write('notes: $notes, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    equipmentId,
    vehicleId,
    compartmentId,
    identifier,
    notes,
    isActive,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EquipmentInstanceData &&
          other.id == this.id &&
          other.equipmentId == this.equipmentId &&
          other.vehicleId == this.vehicleId &&
          other.compartmentId == this.compartmentId &&
          other.identifier == this.identifier &&
          other.notes == this.notes &&
          other.isActive == this.isActive &&
          other.updatedAt == this.updatedAt);
}

class EquipmentInstancesCompanion
    extends UpdateCompanion<EquipmentInstanceData> {
  final Value<int> id;
  final Value<int> equipmentId;
  final Value<int?> vehicleId;
  final Value<int?> compartmentId;
  final Value<String?> identifier;
  final Value<String> notes;
  final Value<bool> isActive;
  final Value<DateTime> updatedAt;
  const EquipmentInstancesCompanion({
    this.id = const Value.absent(),
    this.equipmentId = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.compartmentId = const Value.absent(),
    this.identifier = const Value.absent(),
    this.notes = const Value.absent(),
    this.isActive = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  EquipmentInstancesCompanion.insert({
    this.id = const Value.absent(),
    required int equipmentId,
    this.vehicleId = const Value.absent(),
    this.compartmentId = const Value.absent(),
    this.identifier = const Value.absent(),
    this.notes = const Value.absent(),
    this.isActive = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : equipmentId = Value(equipmentId);
  static Insertable<EquipmentInstanceData> custom({
    Expression<int>? id,
    Expression<int>? equipmentId,
    Expression<int>? vehicleId,
    Expression<int>? compartmentId,
    Expression<String>? identifier,
    Expression<String>? notes,
    Expression<bool>? isActive,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (equipmentId != null) 'equipment_id': equipmentId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (compartmentId != null) 'compartment_id': compartmentId,
      if (identifier != null) 'identifier': identifier,
      if (notes != null) 'notes': notes,
      if (isActive != null) 'is_active': isActive,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  EquipmentInstancesCompanion copyWith({
    Value<int>? id,
    Value<int>? equipmentId,
    Value<int?>? vehicleId,
    Value<int?>? compartmentId,
    Value<String?>? identifier,
    Value<String>? notes,
    Value<bool>? isActive,
    Value<DateTime>? updatedAt,
  }) {
    return EquipmentInstancesCompanion(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      vehicleId: vehicleId ?? this.vehicleId,
      compartmentId: compartmentId ?? this.compartmentId,
      identifier: identifier ?? this.identifier,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (equipmentId.present) {
      map['equipment_id'] = Variable<int>(equipmentId.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<int>(vehicleId.value);
    }
    if (compartmentId.present) {
      map['compartment_id'] = Variable<int>(compartmentId.value);
    }
    if (identifier.present) {
      map['identifier'] = Variable<String>(identifier.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EquipmentInstancesCompanion(')
          ..write('id: $id, ')
          ..write('equipmentId: $equipmentId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('compartmentId: $compartmentId, ')
          ..write('identifier: $identifier, ')
          ..write('notes: $notes, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $InspectionSchedulesTable extends InspectionSchedules
    with TableInfo<$InspectionSchedulesTable, InspectionScheduleData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InspectionSchedulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _instanceIdMeta = const VerificationMeta(
    'instanceId',
  );
  @override
  late final GeneratedColumn<int> instanceId = GeneratedColumn<int>(
    'instance_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES equipment_instances (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intervalMonthsMeta = const VerificationMeta(
    'intervalMonths',
  );
  @override
  late final GeneratedColumn<int> intervalMonths = GeneratedColumn<int>(
    'interval_months',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastDoneAtMeta = const VerificationMeta(
    'lastDoneAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastDoneAt = GeneratedColumn<DateTime>(
    'last_done_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    instanceId,
    kind,
    title,
    intervalMonths,
    lastDoneAt,
    dueAt,
    notes,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inspection_schedules';
  @override
  VerificationContext validateIntegrity(
    Insertable<InspectionScheduleData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('instance_id')) {
      context.handle(
        _instanceIdMeta,
        instanceId.isAcceptableOrUnknown(data['instance_id']!, _instanceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_instanceIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('interval_months')) {
      context.handle(
        _intervalMonthsMeta,
        intervalMonths.isAcceptableOrUnknown(
          data['interval_months']!,
          _intervalMonthsMeta,
        ),
      );
    }
    if (data.containsKey('last_done_at')) {
      context.handle(
        _lastDoneAtMeta,
        lastDoneAt.isAcceptableOrUnknown(
          data['last_done_at']!,
          _lastDoneAtMeta,
        ),
      );
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    } else if (isInserting) {
      context.missing(_dueAtMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InspectionScheduleData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InspectionScheduleData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      instanceId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}instance_id'],
          )!,
      kind:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}kind'],
          )!,
      title:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}title'],
          )!,
      intervalMonths: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_months'],
      ),
      lastDoneAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_done_at'],
      ),
      dueAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}due_at'],
          )!,
      notes:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}notes'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $InspectionSchedulesTable createAlias(String alias) {
    return $InspectionSchedulesTable(attachedDatabase, alias);
  }
}

class InspectionScheduleData extends DataClass
    implements Insertable<InspectionScheduleData> {
  final int id;
  final int instanceId;
  final String kind;
  final String title;
  final int? intervalMonths;
  final DateTime? lastDoneAt;
  final DateTime dueAt;
  final String notes;
  final DateTime updatedAt;
  const InspectionScheduleData({
    required this.id,
    required this.instanceId,
    required this.kind,
    required this.title,
    this.intervalMonths,
    this.lastDoneAt,
    required this.dueAt,
    required this.notes,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['instance_id'] = Variable<int>(instanceId);
    map['kind'] = Variable<String>(kind);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || intervalMonths != null) {
      map['interval_months'] = Variable<int>(intervalMonths);
    }
    if (!nullToAbsent || lastDoneAt != null) {
      map['last_done_at'] = Variable<DateTime>(lastDoneAt);
    }
    map['due_at'] = Variable<DateTime>(dueAt);
    map['notes'] = Variable<String>(notes);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  InspectionSchedulesCompanion toCompanion(bool nullToAbsent) {
    return InspectionSchedulesCompanion(
      id: Value(id),
      instanceId: Value(instanceId),
      kind: Value(kind),
      title: Value(title),
      intervalMonths:
          intervalMonths == null && nullToAbsent
              ? const Value.absent()
              : Value(intervalMonths),
      lastDoneAt:
          lastDoneAt == null && nullToAbsent
              ? const Value.absent()
              : Value(lastDoneAt),
      dueAt: Value(dueAt),
      notes: Value(notes),
      updatedAt: Value(updatedAt),
    );
  }

  factory InspectionScheduleData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InspectionScheduleData(
      id: serializer.fromJson<int>(json['id']),
      instanceId: serializer.fromJson<int>(json['instanceId']),
      kind: serializer.fromJson<String>(json['kind']),
      title: serializer.fromJson<String>(json['title']),
      intervalMonths: serializer.fromJson<int?>(json['intervalMonths']),
      lastDoneAt: serializer.fromJson<DateTime?>(json['lastDoneAt']),
      dueAt: serializer.fromJson<DateTime>(json['dueAt']),
      notes: serializer.fromJson<String>(json['notes']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'instanceId': serializer.toJson<int>(instanceId),
      'kind': serializer.toJson<String>(kind),
      'title': serializer.toJson<String>(title),
      'intervalMonths': serializer.toJson<int?>(intervalMonths),
      'lastDoneAt': serializer.toJson<DateTime?>(lastDoneAt),
      'dueAt': serializer.toJson<DateTime>(dueAt),
      'notes': serializer.toJson<String>(notes),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  InspectionScheduleData copyWith({
    int? id,
    int? instanceId,
    String? kind,
    String? title,
    Value<int?> intervalMonths = const Value.absent(),
    Value<DateTime?> lastDoneAt = const Value.absent(),
    DateTime? dueAt,
    String? notes,
    DateTime? updatedAt,
  }) => InspectionScheduleData(
    id: id ?? this.id,
    instanceId: instanceId ?? this.instanceId,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    intervalMonths:
        intervalMonths.present ? intervalMonths.value : this.intervalMonths,
    lastDoneAt: lastDoneAt.present ? lastDoneAt.value : this.lastDoneAt,
    dueAt: dueAt ?? this.dueAt,
    notes: notes ?? this.notes,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  InspectionScheduleData copyWithCompanion(InspectionSchedulesCompanion data) {
    return InspectionScheduleData(
      id: data.id.present ? data.id.value : this.id,
      instanceId:
          data.instanceId.present ? data.instanceId.value : this.instanceId,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      intervalMonths:
          data.intervalMonths.present
              ? data.intervalMonths.value
              : this.intervalMonths,
      lastDoneAt:
          data.lastDoneAt.present ? data.lastDoneAt.value : this.lastDoneAt,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      notes: data.notes.present ? data.notes.value : this.notes,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InspectionScheduleData(')
          ..write('id: $id, ')
          ..write('instanceId: $instanceId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('intervalMonths: $intervalMonths, ')
          ..write('lastDoneAt: $lastDoneAt, ')
          ..write('dueAt: $dueAt, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    instanceId,
    kind,
    title,
    intervalMonths,
    lastDoneAt,
    dueAt,
    notes,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InspectionScheduleData &&
          other.id == this.id &&
          other.instanceId == this.instanceId &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.intervalMonths == this.intervalMonths &&
          other.lastDoneAt == this.lastDoneAt &&
          other.dueAt == this.dueAt &&
          other.notes == this.notes &&
          other.updatedAt == this.updatedAt);
}

class InspectionSchedulesCompanion
    extends UpdateCompanion<InspectionScheduleData> {
  final Value<int> id;
  final Value<int> instanceId;
  final Value<String> kind;
  final Value<String> title;
  final Value<int?> intervalMonths;
  final Value<DateTime?> lastDoneAt;
  final Value<DateTime> dueAt;
  final Value<String> notes;
  final Value<DateTime> updatedAt;
  const InspectionSchedulesCompanion({
    this.id = const Value.absent(),
    this.instanceId = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.intervalMonths = const Value.absent(),
    this.lastDoneAt = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  InspectionSchedulesCompanion.insert({
    this.id = const Value.absent(),
    required int instanceId,
    required String kind,
    required String title,
    this.intervalMonths = const Value.absent(),
    this.lastDoneAt = const Value.absent(),
    required DateTime dueAt,
    this.notes = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : instanceId = Value(instanceId),
       kind = Value(kind),
       title = Value(title),
       dueAt = Value(dueAt);
  static Insertable<InspectionScheduleData> custom({
    Expression<int>? id,
    Expression<int>? instanceId,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<int>? intervalMonths,
    Expression<DateTime>? lastDoneAt,
    Expression<DateTime>? dueAt,
    Expression<String>? notes,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (instanceId != null) 'instance_id': instanceId,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (intervalMonths != null) 'interval_months': intervalMonths,
      if (lastDoneAt != null) 'last_done_at': lastDoneAt,
      if (dueAt != null) 'due_at': dueAt,
      if (notes != null) 'notes': notes,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  InspectionSchedulesCompanion copyWith({
    Value<int>? id,
    Value<int>? instanceId,
    Value<String>? kind,
    Value<String>? title,
    Value<int?>? intervalMonths,
    Value<DateTime?>? lastDoneAt,
    Value<DateTime>? dueAt,
    Value<String>? notes,
    Value<DateTime>? updatedAt,
  }) {
    return InspectionSchedulesCompanion(
      id: id ?? this.id,
      instanceId: instanceId ?? this.instanceId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      intervalMonths: intervalMonths ?? this.intervalMonths,
      lastDoneAt: lastDoneAt ?? this.lastDoneAt,
      dueAt: dueAt ?? this.dueAt,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (instanceId.present) {
      map['instance_id'] = Variable<int>(instanceId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (intervalMonths.present) {
      map['interval_months'] = Variable<int>(intervalMonths.value);
    }
    if (lastDoneAt.present) {
      map['last_done_at'] = Variable<DateTime>(lastDoneAt.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InspectionSchedulesCompanion(')
          ..write('id: $id, ')
          ..write('instanceId: $instanceId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('intervalMonths: $intervalMonths, ')
          ..write('lastDoneAt: $lastDoneAt, ')
          ..write('dueAt: $dueAt, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $InspectionLogTable extends InspectionLog
    with TableInfo<$InspectionLogTable, InspectionLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InspectionLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _scheduleIdMeta = const VerificationMeta(
    'scheduleId',
  );
  @override
  late final GeneratedColumn<int> scheduleId = GeneratedColumn<int>(
    'schedule_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES inspection_schedules (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _doneAtMeta = const VerificationMeta('doneAt');
  @override
  late final GeneratedColumn<DateTime> doneAt = GeneratedColumn<DateTime>(
    'done_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _doneByMeta = const VerificationMeta('doneBy');
  @override
  late final GeneratedColumn<String> doneBy = GeneratedColumn<String>(
    'done_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [id, scheduleId, doneAt, doneBy, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inspection_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<InspectionLogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('schedule_id')) {
      context.handle(
        _scheduleIdMeta,
        scheduleId.isAcceptableOrUnknown(data['schedule_id']!, _scheduleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scheduleIdMeta);
    }
    if (data.containsKey('done_at')) {
      context.handle(
        _doneAtMeta,
        doneAt.isAcceptableOrUnknown(data['done_at']!, _doneAtMeta),
      );
    } else if (isInserting) {
      context.missing(_doneAtMeta);
    }
    if (data.containsKey('done_by')) {
      context.handle(
        _doneByMeta,
        doneBy.isAcceptableOrUnknown(data['done_by']!, _doneByMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InspectionLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InspectionLogData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      scheduleId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}schedule_id'],
          )!,
      doneAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}done_at'],
          )!,
      doneBy:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}done_by'],
          )!,
      note:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}note'],
          )!,
    );
  }

  @override
  $InspectionLogTable createAlias(String alias) {
    return $InspectionLogTable(attachedDatabase, alias);
  }
}

class InspectionLogData extends DataClass
    implements Insertable<InspectionLogData> {
  final int id;
  final int scheduleId;
  final DateTime doneAt;
  final String doneBy;
  final String note;
  const InspectionLogData({
    required this.id,
    required this.scheduleId,
    required this.doneAt,
    required this.doneBy,
    required this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['schedule_id'] = Variable<int>(scheduleId);
    map['done_at'] = Variable<DateTime>(doneAt);
    map['done_by'] = Variable<String>(doneBy);
    map['note'] = Variable<String>(note);
    return map;
  }

  InspectionLogCompanion toCompanion(bool nullToAbsent) {
    return InspectionLogCompanion(
      id: Value(id),
      scheduleId: Value(scheduleId),
      doneAt: Value(doneAt),
      doneBy: Value(doneBy),
      note: Value(note),
    );
  }

  factory InspectionLogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InspectionLogData(
      id: serializer.fromJson<int>(json['id']),
      scheduleId: serializer.fromJson<int>(json['scheduleId']),
      doneAt: serializer.fromJson<DateTime>(json['doneAt']),
      doneBy: serializer.fromJson<String>(json['doneBy']),
      note: serializer.fromJson<String>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'scheduleId': serializer.toJson<int>(scheduleId),
      'doneAt': serializer.toJson<DateTime>(doneAt),
      'doneBy': serializer.toJson<String>(doneBy),
      'note': serializer.toJson<String>(note),
    };
  }

  InspectionLogData copyWith({
    int? id,
    int? scheduleId,
    DateTime? doneAt,
    String? doneBy,
    String? note,
  }) => InspectionLogData(
    id: id ?? this.id,
    scheduleId: scheduleId ?? this.scheduleId,
    doneAt: doneAt ?? this.doneAt,
    doneBy: doneBy ?? this.doneBy,
    note: note ?? this.note,
  );
  InspectionLogData copyWithCompanion(InspectionLogCompanion data) {
    return InspectionLogData(
      id: data.id.present ? data.id.value : this.id,
      scheduleId:
          data.scheduleId.present ? data.scheduleId.value : this.scheduleId,
      doneAt: data.doneAt.present ? data.doneAt.value : this.doneAt,
      doneBy: data.doneBy.present ? data.doneBy.value : this.doneBy,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InspectionLogData(')
          ..write('id: $id, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('doneAt: $doneAt, ')
          ..write('doneBy: $doneBy, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, scheduleId, doneAt, doneBy, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InspectionLogData &&
          other.id == this.id &&
          other.scheduleId == this.scheduleId &&
          other.doneAt == this.doneAt &&
          other.doneBy == this.doneBy &&
          other.note == this.note);
}

class InspectionLogCompanion extends UpdateCompanion<InspectionLogData> {
  final Value<int> id;
  final Value<int> scheduleId;
  final Value<DateTime> doneAt;
  final Value<String> doneBy;
  final Value<String> note;
  const InspectionLogCompanion({
    this.id = const Value.absent(),
    this.scheduleId = const Value.absent(),
    this.doneAt = const Value.absent(),
    this.doneBy = const Value.absent(),
    this.note = const Value.absent(),
  });
  InspectionLogCompanion.insert({
    this.id = const Value.absent(),
    required int scheduleId,
    required DateTime doneAt,
    this.doneBy = const Value.absent(),
    this.note = const Value.absent(),
  }) : scheduleId = Value(scheduleId),
       doneAt = Value(doneAt);
  static Insertable<InspectionLogData> custom({
    Expression<int>? id,
    Expression<int>? scheduleId,
    Expression<DateTime>? doneAt,
    Expression<String>? doneBy,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scheduleId != null) 'schedule_id': scheduleId,
      if (doneAt != null) 'done_at': doneAt,
      if (doneBy != null) 'done_by': doneBy,
      if (note != null) 'note': note,
    });
  }

  InspectionLogCompanion copyWith({
    Value<int>? id,
    Value<int>? scheduleId,
    Value<DateTime>? doneAt,
    Value<String>? doneBy,
    Value<String>? note,
  }) {
    return InspectionLogCompanion(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      doneAt: doneAt ?? this.doneAt,
      doneBy: doneBy ?? this.doneBy,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (scheduleId.present) {
      map['schedule_id'] = Variable<int>(scheduleId.value);
    }
    if (doneAt.present) {
      map['done_at'] = Variable<DateTime>(doneAt.value);
    }
    if (doneBy.present) {
      map['done_by'] = Variable<String>(doneBy.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InspectionLogCompanion(')
          ..write('id: $id, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('doneAt: $doneAt, ')
          ..write('doneBy: $doneBy, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $UserAliasesTable extends UserAliases
    with TableInfo<$UserAliasesTable, UserAliasData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserAliasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _aliasMeta = const VerificationMeta('alias');
  @override
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
    'alias',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _equipmentIdMeta = const VerificationMeta(
    'equipmentId',
  );
  @override
  late final GeneratedColumn<int> equipmentId = GeneratedColumn<int>(
    'equipment_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES equipment_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, alias, equipmentId, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_aliases';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserAliasData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('alias')) {
      context.handle(
        _aliasMeta,
        alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta),
      );
    } else if (isInserting) {
      context.missing(_aliasMeta);
    }
    if (data.containsKey('equipment_id')) {
      context.handle(
        _equipmentIdMeta,
        equipmentId.isAcceptableOrUnknown(
          data['equipment_id']!,
          _equipmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_equipmentIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserAliasData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserAliasData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      alias:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}alias'],
          )!,
      equipmentId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}equipment_id'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $UserAliasesTable createAlias(String alias) {
    return $UserAliasesTable(attachedDatabase, alias);
  }
}

class UserAliasData extends DataClass implements Insertable<UserAliasData> {
  final int id;
  final String alias;
  final int equipmentId;
  final DateTime updatedAt;
  const UserAliasData({
    required this.id,
    required this.alias,
    required this.equipmentId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['alias'] = Variable<String>(alias);
    map['equipment_id'] = Variable<int>(equipmentId);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserAliasesCompanion toCompanion(bool nullToAbsent) {
    return UserAliasesCompanion(
      id: Value(id),
      alias: Value(alias),
      equipmentId: Value(equipmentId),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserAliasData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserAliasData(
      id: serializer.fromJson<int>(json['id']),
      alias: serializer.fromJson<String>(json['alias']),
      equipmentId: serializer.fromJson<int>(json['equipmentId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'alias': serializer.toJson<String>(alias),
      'equipmentId': serializer.toJson<int>(equipmentId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserAliasData copyWith({
    int? id,
    String? alias,
    int? equipmentId,
    DateTime? updatedAt,
  }) => UserAliasData(
    id: id ?? this.id,
    alias: alias ?? this.alias,
    equipmentId: equipmentId ?? this.equipmentId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserAliasData copyWithCompanion(UserAliasesCompanion data) {
    return UserAliasData(
      id: data.id.present ? data.id.value : this.id,
      alias: data.alias.present ? data.alias.value : this.alias,
      equipmentId:
          data.equipmentId.present ? data.equipmentId.value : this.equipmentId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserAliasData(')
          ..write('id: $id, ')
          ..write('alias: $alias, ')
          ..write('equipmentId: $equipmentId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, alias, equipmentId, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserAliasData &&
          other.id == this.id &&
          other.alias == this.alias &&
          other.equipmentId == this.equipmentId &&
          other.updatedAt == this.updatedAt);
}

class UserAliasesCompanion extends UpdateCompanion<UserAliasData> {
  final Value<int> id;
  final Value<String> alias;
  final Value<int> equipmentId;
  final Value<DateTime> updatedAt;
  const UserAliasesCompanion({
    this.id = const Value.absent(),
    this.alias = const Value.absent(),
    this.equipmentId = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  UserAliasesCompanion.insert({
    this.id = const Value.absent(),
    required String alias,
    required int equipmentId,
    this.updatedAt = const Value.absent(),
  }) : alias = Value(alias),
       equipmentId = Value(equipmentId);
  static Insertable<UserAliasData> custom({
    Expression<int>? id,
    Expression<String>? alias,
    Expression<int>? equipmentId,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (alias != null) 'alias': alias,
      if (equipmentId != null) 'equipment_id': equipmentId,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  UserAliasesCompanion copyWith({
    Value<int>? id,
    Value<String>? alias,
    Value<int>? equipmentId,
    Value<DateTime>? updatedAt,
  }) {
    return UserAliasesCompanion(
      id: id ?? this.id,
      alias: alias ?? this.alias,
      equipmentId: equipmentId ?? this.equipmentId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    if (equipmentId.present) {
      map['equipment_id'] = Variable<int>(equipmentId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserAliasesCompanion(')
          ..write('id: $id, ')
          ..write('alias: $alias, ')
          ..write('equipmentId: $equipmentId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncMetaTable extends SyncMeta
    with TableInfo<$SyncMetaTable, SyncMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastPulledVersionMeta = const VerificationMeta(
    'lastPulledVersion',
  );
  @override
  late final GeneratedColumn<int> lastPulledVersion = GeneratedColumn<int>(
    'last_pulled_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPulledAtMeta = const VerificationMeta(
    'lastPulledAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPulledAt = GeneratedColumn<DateTime>(
    'last_pulled_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localDirtyMeta = const VerificationMeta(
    'localDirty',
  );
  @override
  late final GeneratedColumn<bool> localDirty = GeneratedColumn<bool>(
    'local_dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("local_dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lastPulledVersion,
    lastPulledAt,
    localDirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('last_pulled_version')) {
      context.handle(
        _lastPulledVersionMeta,
        lastPulledVersion.isAcceptableOrUnknown(
          data['last_pulled_version']!,
          _lastPulledVersionMeta,
        ),
      );
    }
    if (data.containsKey('last_pulled_at')) {
      context.handle(
        _lastPulledAtMeta,
        lastPulledAt.isAcceptableOrUnknown(
          data['last_pulled_at']!,
          _lastPulledAtMeta,
        ),
      );
    }
    if (data.containsKey('local_dirty')) {
      context.handle(
        _localDirtyMeta,
        localDirty.isAcceptableOrUnknown(data['local_dirty']!, _localDirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetaData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      lastPulledVersion:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}last_pulled_version'],
          )!,
      lastPulledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_pulled_at'],
      ),
      localDirty:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}local_dirty'],
          )!,
    );
  }

  @override
  $SyncMetaTable createAlias(String alias) {
    return $SyncMetaTable(attachedDatabase, alias);
  }
}

class SyncMetaData extends DataClass implements Insertable<SyncMetaData> {
  final int id;
  final int lastPulledVersion;
  final DateTime? lastPulledAt;
  final bool localDirty;
  const SyncMetaData({
    required this.id,
    required this.lastPulledVersion,
    this.lastPulledAt,
    required this.localDirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['last_pulled_version'] = Variable<int>(lastPulledVersion);
    if (!nullToAbsent || lastPulledAt != null) {
      map['last_pulled_at'] = Variable<DateTime>(lastPulledAt);
    }
    map['local_dirty'] = Variable<bool>(localDirty);
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(
      id: Value(id),
      lastPulledVersion: Value(lastPulledVersion),
      lastPulledAt:
          lastPulledAt == null && nullToAbsent
              ? const Value.absent()
              : Value(lastPulledAt),
      localDirty: Value(localDirty),
    );
  }

  factory SyncMetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetaData(
      id: serializer.fromJson<int>(json['id']),
      lastPulledVersion: serializer.fromJson<int>(json['lastPulledVersion']),
      lastPulledAt: serializer.fromJson<DateTime?>(json['lastPulledAt']),
      localDirty: serializer.fromJson<bool>(json['localDirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lastPulledVersion': serializer.toJson<int>(lastPulledVersion),
      'lastPulledAt': serializer.toJson<DateTime?>(lastPulledAt),
      'localDirty': serializer.toJson<bool>(localDirty),
    };
  }

  SyncMetaData copyWith({
    int? id,
    int? lastPulledVersion,
    Value<DateTime?> lastPulledAt = const Value.absent(),
    bool? localDirty,
  }) => SyncMetaData(
    id: id ?? this.id,
    lastPulledVersion: lastPulledVersion ?? this.lastPulledVersion,
    lastPulledAt: lastPulledAt.present ? lastPulledAt.value : this.lastPulledAt,
    localDirty: localDirty ?? this.localDirty,
  );
  SyncMetaData copyWithCompanion(SyncMetaCompanion data) {
    return SyncMetaData(
      id: data.id.present ? data.id.value : this.id,
      lastPulledVersion:
          data.lastPulledVersion.present
              ? data.lastPulledVersion.value
              : this.lastPulledVersion,
      lastPulledAt:
          data.lastPulledAt.present
              ? data.lastPulledAt.value
              : this.lastPulledAt,
      localDirty:
          data.localDirty.present ? data.localDirty.value : this.localDirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaData(')
          ..write('id: $id, ')
          ..write('lastPulledVersion: $lastPulledVersion, ')
          ..write('lastPulledAt: $lastPulledAt, ')
          ..write('localDirty: $localDirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, lastPulledVersion, lastPulledAt, localDirty);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetaData &&
          other.id == this.id &&
          other.lastPulledVersion == this.lastPulledVersion &&
          other.lastPulledAt == this.lastPulledAt &&
          other.localDirty == this.localDirty);
}

class SyncMetaCompanion extends UpdateCompanion<SyncMetaData> {
  final Value<int> id;
  final Value<int> lastPulledVersion;
  final Value<DateTime?> lastPulledAt;
  final Value<bool> localDirty;
  const SyncMetaCompanion({
    this.id = const Value.absent(),
    this.lastPulledVersion = const Value.absent(),
    this.lastPulledAt = const Value.absent(),
    this.localDirty = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    this.id = const Value.absent(),
    this.lastPulledVersion = const Value.absent(),
    this.lastPulledAt = const Value.absent(),
    this.localDirty = const Value.absent(),
  });
  static Insertable<SyncMetaData> custom({
    Expression<int>? id,
    Expression<int>? lastPulledVersion,
    Expression<DateTime>? lastPulledAt,
    Expression<bool>? localDirty,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lastPulledVersion != null) 'last_pulled_version': lastPulledVersion,
      if (lastPulledAt != null) 'last_pulled_at': lastPulledAt,
      if (localDirty != null) 'local_dirty': localDirty,
    });
  }

  SyncMetaCompanion copyWith({
    Value<int>? id,
    Value<int>? lastPulledVersion,
    Value<DateTime?>? lastPulledAt,
    Value<bool>? localDirty,
  }) {
    return SyncMetaCompanion(
      id: id ?? this.id,
      lastPulledVersion: lastPulledVersion ?? this.lastPulledVersion,
      lastPulledAt: lastPulledAt ?? this.lastPulledAt,
      localDirty: localDirty ?? this.localDirty,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lastPulledVersion.present) {
      map['last_pulled_version'] = Variable<int>(lastPulledVersion.value);
    }
    if (lastPulledAt.present) {
      map['last_pulled_at'] = Variable<DateTime>(lastPulledAt.value);
    }
    if (localDirty.present) {
      map['local_dirty'] = Variable<bool>(localDirty.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaCompanion(')
          ..write('id: $id, ')
          ..write('lastPulledVersion: $lastPulledVersion, ')
          ..write('lastPulledAt: $lastPulledAt, ')
          ..write('localDirty: $localDirty')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $VehiclesTable vehicles = $VehiclesTable(this);
  late final $CompartmentsTable compartments = $CompartmentsTable(this);
  late final $EquipmentItemsTable equipmentItems = $EquipmentItemsTable(this);
  late final $EquipmentAssignmentsTable equipmentAssignments =
      $EquipmentAssignmentsTable(this);
  late final $QuizResultsTable quizResults = $QuizResultsTable(this);
  late final $EquipmentInstancesTable equipmentInstances =
      $EquipmentInstancesTable(this);
  late final $InspectionSchedulesTable inspectionSchedules =
      $InspectionSchedulesTable(this);
  late final $InspectionLogTable inspectionLog = $InspectionLogTable(this);
  late final $UserAliasesTable userAliases = $UserAliasesTable(this);
  late final $SyncMetaTable syncMeta = $SyncMetaTable(this);
  late final VehicleDao vehicleDao = VehicleDao(this as AppDatabase);
  late final CompartmentDao compartmentDao = CompartmentDao(
    this as AppDatabase,
  );
  late final EquipmentDao equipmentDao = EquipmentDao(this as AppDatabase);
  late final AssignmentDao assignmentDao = AssignmentDao(this as AppDatabase);
  late final QuizDao quizDao = QuizDao(this as AppDatabase);
  late final InspectionDao inspectionDao = InspectionDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    vehicles,
    compartments,
    equipmentItems,
    equipmentAssignments,
    quizResults,
    equipmentInstances,
    inspectionSchedules,
    inspectionLog,
    userAliases,
    syncMeta,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vehicles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('compartments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'compartments',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('equipment_assignments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'equipment_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('equipment_assignments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vehicles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('quiz_results', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'equipment_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('equipment_instances', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vehicles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('equipment_instances', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'compartments',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('equipment_instances', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'equipment_instances',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('inspection_schedules', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'inspection_schedules',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('inspection_log', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'equipment_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('user_aliases', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$VehiclesTableCreateCompanionBuilder =
    VehiclesCompanion Function({
      Value<int> id,
      required String name,
      required String type,
      Value<String?> licensePlate,
      Value<String?> imagePath,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$VehiclesTableUpdateCompanionBuilder =
    VehiclesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> type,
      Value<String?> licensePlate,
      Value<String?> imagePath,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$VehiclesTableReferences
    extends BaseReferences<_$AppDatabase, $VehiclesTable, VehicleData> {
  $$VehiclesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CompartmentsTable, List<CompartmentData>>
  _compartmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.compartments,
    aliasName: $_aliasNameGenerator(db.vehicles.id, db.compartments.vehicleId),
  );

  $$CompartmentsTableProcessedTableManager get compartmentsRefs {
    final manager = $$CompartmentsTableTableManager(
      $_db,
      $_db.compartments,
    ).filter((f) => f.vehicleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_compartmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$QuizResultsTable, List<QuizResultData>>
  _quizResultsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.quizResults,
    aliasName: $_aliasNameGenerator(db.vehicles.id, db.quizResults.vehicleId),
  );

  $$QuizResultsTableProcessedTableManager get quizResultsRefs {
    final manager = $$QuizResultsTableTableManager(
      $_db,
      $_db.quizResults,
    ).filter((f) => f.vehicleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_quizResultsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $EquipmentInstancesTable,
    List<EquipmentInstanceData>
  >
  _equipmentInstancesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.equipmentInstances,
        aliasName: $_aliasNameGenerator(
          db.vehicles.id,
          db.equipmentInstances.vehicleId,
        ),
      );

  $$EquipmentInstancesTableProcessedTableManager get equipmentInstancesRefs {
    final manager = $$EquipmentInstancesTableTableManager(
      $_db,
      $_db.equipmentInstances,
    ).filter((f) => f.vehicleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _equipmentInstancesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VehiclesTableFilterComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get licensePlate => $composableBuilder(
    column: $table.licensePlate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> compartmentsRefs(
    Expression<bool> Function($$CompartmentsTableFilterComposer f) f,
  ) {
    final $$CompartmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.compartments,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompartmentsTableFilterComposer(
            $db: $db,
            $table: $db.compartments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> quizResultsRefs(
    Expression<bool> Function($$QuizResultsTableFilterComposer f) f,
  ) {
    final $$QuizResultsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.quizResults,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuizResultsTableFilterComposer(
            $db: $db,
            $table: $db.quizResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> equipmentInstancesRefs(
    Expression<bool> Function($$EquipmentInstancesTableFilterComposer f) f,
  ) {
    final $$EquipmentInstancesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.equipmentInstances,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentInstancesTableFilterComposer(
            $db: $db,
            $table: $db.equipmentInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VehiclesTableOrderingComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get licensePlate => $composableBuilder(
    column: $table.licensePlate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VehiclesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get licensePlate => $composableBuilder(
    column: $table.licensePlate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> compartmentsRefs<T extends Object>(
    Expression<T> Function($$CompartmentsTableAnnotationComposer a) f,
  ) {
    final $$CompartmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.compartments,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompartmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.compartments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> quizResultsRefs<T extends Object>(
    Expression<T> Function($$QuizResultsTableAnnotationComposer a) f,
  ) {
    final $$QuizResultsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.quizResults,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuizResultsTableAnnotationComposer(
            $db: $db,
            $table: $db.quizResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> equipmentInstancesRefs<T extends Object>(
    Expression<T> Function($$EquipmentInstancesTableAnnotationComposer a) f,
  ) {
    final $$EquipmentInstancesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.equipmentInstances,
          getReferencedColumn: (t) => t.vehicleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EquipmentInstancesTableAnnotationComposer(
                $db: $db,
                $table: $db.equipmentInstances,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$VehiclesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VehiclesTable,
          VehicleData,
          $$VehiclesTableFilterComposer,
          $$VehiclesTableOrderingComposer,
          $$VehiclesTableAnnotationComposer,
          $$VehiclesTableCreateCompanionBuilder,
          $$VehiclesTableUpdateCompanionBuilder,
          (VehicleData, $$VehiclesTableReferences),
          VehicleData,
          PrefetchHooks Function({
            bool compartmentsRefs,
            bool quizResultsRefs,
            bool equipmentInstancesRefs,
          })
        > {
  $$VehiclesTableTableManager(_$AppDatabase db, $VehiclesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$VehiclesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$VehiclesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$VehiclesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> licensePlate = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => VehiclesCompanion(
                id: id,
                name: name,
                type: type,
                licensePlate: licensePlate,
                imagePath: imagePath,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String type,
                Value<String?> licensePlate = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => VehiclesCompanion.insert(
                id: id,
                name: name,
                type: type,
                licensePlate: licensePlate,
                imagePath: imagePath,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$VehiclesTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            compartmentsRefs = false,
            quizResultsRefs = false,
            equipmentInstancesRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (compartmentsRefs) db.compartments,
                if (quizResultsRefs) db.quizResults,
                if (equipmentInstancesRefs) db.equipmentInstances,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (compartmentsRefs)
                    await $_getPrefetchedData<
                      VehicleData,
                      $VehiclesTable,
                      CompartmentData
                    >(
                      currentTable: table,
                      referencedTable: $$VehiclesTableReferences
                          ._compartmentsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$VehiclesTableReferences(
                                db,
                                table,
                                p0,
                              ).compartmentsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.vehicleId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (quizResultsRefs)
                    await $_getPrefetchedData<
                      VehicleData,
                      $VehiclesTable,
                      QuizResultData
                    >(
                      currentTable: table,
                      referencedTable: $$VehiclesTableReferences
                          ._quizResultsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$VehiclesTableReferences(
                                db,
                                table,
                                p0,
                              ).quizResultsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.vehicleId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (equipmentInstancesRefs)
                    await $_getPrefetchedData<
                      VehicleData,
                      $VehiclesTable,
                      EquipmentInstanceData
                    >(
                      currentTable: table,
                      referencedTable: $$VehiclesTableReferences
                          ._equipmentInstancesRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$VehiclesTableReferences(
                                db,
                                table,
                                p0,
                              ).equipmentInstancesRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.vehicleId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$VehiclesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VehiclesTable,
      VehicleData,
      $$VehiclesTableFilterComposer,
      $$VehiclesTableOrderingComposer,
      $$VehiclesTableAnnotationComposer,
      $$VehiclesTableCreateCompanionBuilder,
      $$VehiclesTableUpdateCompanionBuilder,
      (VehicleData, $$VehiclesTableReferences),
      VehicleData,
      PrefetchHooks Function({
        bool compartmentsRefs,
        bool quizResultsRefs,
        bool equipmentInstancesRefs,
      })
    >;
typedef $$CompartmentsTableCreateCompanionBuilder =
    CompartmentsCompanion Function({
      Value<int> id,
      required int vehicleId,
      required String label,
      Value<int> position,
      Value<int?> gridRow,
      Value<int?> gridCol,
      Value<int> gridColSpan,
      Value<DateTime> updatedAt,
    });
typedef $$CompartmentsTableUpdateCompanionBuilder =
    CompartmentsCompanion Function({
      Value<int> id,
      Value<int> vehicleId,
      Value<String> label,
      Value<int> position,
      Value<int?> gridRow,
      Value<int?> gridCol,
      Value<int> gridColSpan,
      Value<DateTime> updatedAt,
    });

final class $$CompartmentsTableReferences
    extends BaseReferences<_$AppDatabase, $CompartmentsTable, CompartmentData> {
  $$CompartmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $VehiclesTable _vehicleIdTable(_$AppDatabase db) =>
      db.vehicles.createAlias(
        $_aliasNameGenerator(db.compartments.vehicleId, db.vehicles.id),
      );

  $$VehiclesTableProcessedTableManager get vehicleId {
    final $_column = $_itemColumn<int>('vehicle_id')!;

    final manager = $$VehiclesTableTableManager(
      $_db,
      $_db.vehicles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vehicleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$EquipmentAssignmentsTable, List<AssignmentData>>
  _equipmentAssignmentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.equipmentAssignments,
        aliasName: $_aliasNameGenerator(
          db.compartments.id,
          db.equipmentAssignments.compartmentId,
        ),
      );

  $$EquipmentAssignmentsTableProcessedTableManager
  get equipmentAssignmentsRefs {
    final manager = $$EquipmentAssignmentsTableTableManager(
      $_db,
      $_db.equipmentAssignments,
    ).filter((f) => f.compartmentId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _equipmentAssignmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $EquipmentInstancesTable,
    List<EquipmentInstanceData>
  >
  _equipmentInstancesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.equipmentInstances,
        aliasName: $_aliasNameGenerator(
          db.compartments.id,
          db.equipmentInstances.compartmentId,
        ),
      );

  $$EquipmentInstancesTableProcessedTableManager get equipmentInstancesRefs {
    final manager = $$EquipmentInstancesTableTableManager(
      $_db,
      $_db.equipmentInstances,
    ).filter((f) => f.compartmentId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _equipmentInstancesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CompartmentsTableFilterComposer
    extends Composer<_$AppDatabase, $CompartmentsTable> {
  $$CompartmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gridRow => $composableBuilder(
    column: $table.gridRow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gridCol => $composableBuilder(
    column: $table.gridCol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gridColSpan => $composableBuilder(
    column: $table.gridColSpan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$VehiclesTableFilterComposer get vehicleId {
    final $$VehiclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableFilterComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> equipmentAssignmentsRefs(
    Expression<bool> Function($$EquipmentAssignmentsTableFilterComposer f) f,
  ) {
    final $$EquipmentAssignmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.equipmentAssignments,
      getReferencedColumn: (t) => t.compartmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentAssignmentsTableFilterComposer(
            $db: $db,
            $table: $db.equipmentAssignments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> equipmentInstancesRefs(
    Expression<bool> Function($$EquipmentInstancesTableFilterComposer f) f,
  ) {
    final $$EquipmentInstancesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.equipmentInstances,
      getReferencedColumn: (t) => t.compartmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentInstancesTableFilterComposer(
            $db: $db,
            $table: $db.equipmentInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CompartmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $CompartmentsTable> {
  $$CompartmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gridRow => $composableBuilder(
    column: $table.gridRow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gridCol => $composableBuilder(
    column: $table.gridCol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gridColSpan => $composableBuilder(
    column: $table.gridColSpan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$VehiclesTableOrderingComposer get vehicleId {
    final $$VehiclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableOrderingComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CompartmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CompartmentsTable> {
  $$CompartmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get gridRow =>
      $composableBuilder(column: $table.gridRow, builder: (column) => column);

  GeneratedColumn<int> get gridCol =>
      $composableBuilder(column: $table.gridCol, builder: (column) => column);

  GeneratedColumn<int> get gridColSpan => $composableBuilder(
    column: $table.gridColSpan,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$VehiclesTableAnnotationComposer get vehicleId {
    final $$VehiclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableAnnotationComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> equipmentAssignmentsRefs<T extends Object>(
    Expression<T> Function($$EquipmentAssignmentsTableAnnotationComposer a) f,
  ) {
    final $$EquipmentAssignmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.equipmentAssignments,
          getReferencedColumn: (t) => t.compartmentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EquipmentAssignmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.equipmentAssignments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> equipmentInstancesRefs<T extends Object>(
    Expression<T> Function($$EquipmentInstancesTableAnnotationComposer a) f,
  ) {
    final $$EquipmentInstancesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.equipmentInstances,
          getReferencedColumn: (t) => t.compartmentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EquipmentInstancesTableAnnotationComposer(
                $db: $db,
                $table: $db.equipmentInstances,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CompartmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CompartmentsTable,
          CompartmentData,
          $$CompartmentsTableFilterComposer,
          $$CompartmentsTableOrderingComposer,
          $$CompartmentsTableAnnotationComposer,
          $$CompartmentsTableCreateCompanionBuilder,
          $$CompartmentsTableUpdateCompanionBuilder,
          (CompartmentData, $$CompartmentsTableReferences),
          CompartmentData,
          PrefetchHooks Function({
            bool vehicleId,
            bool equipmentAssignmentsRefs,
            bool equipmentInstancesRefs,
          })
        > {
  $$CompartmentsTableTableManager(_$AppDatabase db, $CompartmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$CompartmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$CompartmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$CompartmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> vehicleId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int?> gridRow = const Value.absent(),
                Value<int?> gridCol = const Value.absent(),
                Value<int> gridColSpan = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => CompartmentsCompanion(
                id: id,
                vehicleId: vehicleId,
                label: label,
                position: position,
                gridRow: gridRow,
                gridCol: gridCol,
                gridColSpan: gridColSpan,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int vehicleId,
                required String label,
                Value<int> position = const Value.absent(),
                Value<int?> gridRow = const Value.absent(),
                Value<int?> gridCol = const Value.absent(),
                Value<int> gridColSpan = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => CompartmentsCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                label: label,
                position: position,
                gridRow: gridRow,
                gridCol: gridCol,
                gridColSpan: gridColSpan,
                updatedAt: updatedAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$CompartmentsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            vehicleId = false,
            equipmentAssignmentsRefs = false,
            equipmentInstancesRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (equipmentAssignmentsRefs) db.equipmentAssignments,
                if (equipmentInstancesRefs) db.equipmentInstances,
              ],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (vehicleId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.vehicleId,
                            referencedTable: $$CompartmentsTableReferences
                                ._vehicleIdTable(db),
                            referencedColumn:
                                $$CompartmentsTableReferences
                                    ._vehicleIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (equipmentAssignmentsRefs)
                    await $_getPrefetchedData<
                      CompartmentData,
                      $CompartmentsTable,
                      AssignmentData
                    >(
                      currentTable: table,
                      referencedTable: $$CompartmentsTableReferences
                          ._equipmentAssignmentsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$CompartmentsTableReferences(
                                db,
                                table,
                                p0,
                              ).equipmentAssignmentsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.compartmentId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (equipmentInstancesRefs)
                    await $_getPrefetchedData<
                      CompartmentData,
                      $CompartmentsTable,
                      EquipmentInstanceData
                    >(
                      currentTable: table,
                      referencedTable: $$CompartmentsTableReferences
                          ._equipmentInstancesRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$CompartmentsTableReferences(
                                db,
                                table,
                                p0,
                              ).equipmentInstancesRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.compartmentId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CompartmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CompartmentsTable,
      CompartmentData,
      $$CompartmentsTableFilterComposer,
      $$CompartmentsTableOrderingComposer,
      $$CompartmentsTableAnnotationComposer,
      $$CompartmentsTableCreateCompanionBuilder,
      $$CompartmentsTableUpdateCompanionBuilder,
      (CompartmentData, $$CompartmentsTableReferences),
      CompartmentData,
      PrefetchHooks Function({
        bool vehicleId,
        bool equipmentAssignmentsRefs,
        bool equipmentInstancesRefs,
      })
    >;
typedef $$EquipmentItemsTableCreateCompanionBuilder =
    EquipmentItemsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> shortName,
      Value<String> equipmentFunctionsJson,
      Value<String> deploymentScenariosJson,
      Value<String> description,
      Value<String?> imagePath,
      Value<String?> trainingUrl,
      Value<String?> libraryEquipmentId,
      Value<bool> isCustom,
      Value<String> extraAttributesJson,
      Value<String> trainingQuestionsJson,
      Value<String> typicalUseJson,
      Value<DateTime> updatedAt,
    });
typedef $$EquipmentItemsTableUpdateCompanionBuilder =
    EquipmentItemsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> shortName,
      Value<String> equipmentFunctionsJson,
      Value<String> deploymentScenariosJson,
      Value<String> description,
      Value<String?> imagePath,
      Value<String?> trainingUrl,
      Value<String?> libraryEquipmentId,
      Value<bool> isCustom,
      Value<String> extraAttributesJson,
      Value<String> trainingQuestionsJson,
      Value<String> typicalUseJson,
      Value<DateTime> updatedAt,
    });

final class $$EquipmentItemsTableReferences
    extends
        BaseReferences<_$AppDatabase, $EquipmentItemsTable, EquipmentItemData> {
  $$EquipmentItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$EquipmentAssignmentsTable, List<AssignmentData>>
  _equipmentAssignmentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.equipmentAssignments,
        aliasName: $_aliasNameGenerator(
          db.equipmentItems.id,
          db.equipmentAssignments.equipmentId,
        ),
      );

  $$EquipmentAssignmentsTableProcessedTableManager
  get equipmentAssignmentsRefs {
    final manager = $$EquipmentAssignmentsTableTableManager(
      $_db,
      $_db.equipmentAssignments,
    ).filter((f) => f.equipmentId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _equipmentAssignmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $EquipmentInstancesTable,
    List<EquipmentInstanceData>
  >
  _equipmentInstancesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.equipmentInstances,
        aliasName: $_aliasNameGenerator(
          db.equipmentItems.id,
          db.equipmentInstances.equipmentId,
        ),
      );

  $$EquipmentInstancesTableProcessedTableManager get equipmentInstancesRefs {
    final manager = $$EquipmentInstancesTableTableManager(
      $_db,
      $_db.equipmentInstances,
    ).filter((f) => f.equipmentId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _equipmentInstancesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$UserAliasesTable, List<UserAliasData>>
  _userAliasesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.userAliases,
    aliasName: $_aliasNameGenerator(
      db.equipmentItems.id,
      db.userAliases.equipmentId,
    ),
  );

  $$UserAliasesTableProcessedTableManager get userAliasesRefs {
    final manager = $$UserAliasesTableTableManager(
      $_db,
      $_db.userAliases,
    ).filter((f) => f.equipmentId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_userAliasesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EquipmentItemsTableFilterComposer
    extends Composer<_$AppDatabase, $EquipmentItemsTable> {
  $$EquipmentItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shortName => $composableBuilder(
    column: $table.shortName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get equipmentFunctionsJson => $composableBuilder(
    column: $table.equipmentFunctionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deploymentScenariosJson => $composableBuilder(
    column: $table.deploymentScenariosJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trainingUrl => $composableBuilder(
    column: $table.trainingUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get libraryEquipmentId => $composableBuilder(
    column: $table.libraryEquipmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extraAttributesJson => $composableBuilder(
    column: $table.extraAttributesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trainingQuestionsJson => $composableBuilder(
    column: $table.trainingQuestionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get typicalUseJson => $composableBuilder(
    column: $table.typicalUseJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> equipmentAssignmentsRefs(
    Expression<bool> Function($$EquipmentAssignmentsTableFilterComposer f) f,
  ) {
    final $$EquipmentAssignmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.equipmentAssignments,
      getReferencedColumn: (t) => t.equipmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentAssignmentsTableFilterComposer(
            $db: $db,
            $table: $db.equipmentAssignments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> equipmentInstancesRefs(
    Expression<bool> Function($$EquipmentInstancesTableFilterComposer f) f,
  ) {
    final $$EquipmentInstancesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.equipmentInstances,
      getReferencedColumn: (t) => t.equipmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentInstancesTableFilterComposer(
            $db: $db,
            $table: $db.equipmentInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> userAliasesRefs(
    Expression<bool> Function($$UserAliasesTableFilterComposer f) f,
  ) {
    final $$UserAliasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userAliases,
      getReferencedColumn: (t) => t.equipmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserAliasesTableFilterComposer(
            $db: $db,
            $table: $db.userAliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EquipmentItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $EquipmentItemsTable> {
  $$EquipmentItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shortName => $composableBuilder(
    column: $table.shortName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equipmentFunctionsJson => $composableBuilder(
    column: $table.equipmentFunctionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deploymentScenariosJson => $composableBuilder(
    column: $table.deploymentScenariosJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trainingUrl => $composableBuilder(
    column: $table.trainingUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get libraryEquipmentId => $composableBuilder(
    column: $table.libraryEquipmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extraAttributesJson => $composableBuilder(
    column: $table.extraAttributesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trainingQuestionsJson => $composableBuilder(
    column: $table.trainingQuestionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get typicalUseJson => $composableBuilder(
    column: $table.typicalUseJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EquipmentItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EquipmentItemsTable> {
  $$EquipmentItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get shortName =>
      $composableBuilder(column: $table.shortName, builder: (column) => column);

  GeneratedColumn<String> get equipmentFunctionsJson => $composableBuilder(
    column: $table.equipmentFunctionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deploymentScenariosJson => $composableBuilder(
    column: $table.deploymentScenariosJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get trainingUrl => $composableBuilder(
    column: $table.trainingUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get libraryEquipmentId => $composableBuilder(
    column: $table.libraryEquipmentId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);

  GeneratedColumn<String> get extraAttributesJson => $composableBuilder(
    column: $table.extraAttributesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trainingQuestionsJson => $composableBuilder(
    column: $table.trainingQuestionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get typicalUseJson => $composableBuilder(
    column: $table.typicalUseJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> equipmentAssignmentsRefs<T extends Object>(
    Expression<T> Function($$EquipmentAssignmentsTableAnnotationComposer a) f,
  ) {
    final $$EquipmentAssignmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.equipmentAssignments,
          getReferencedColumn: (t) => t.equipmentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EquipmentAssignmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.equipmentAssignments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> equipmentInstancesRefs<T extends Object>(
    Expression<T> Function($$EquipmentInstancesTableAnnotationComposer a) f,
  ) {
    final $$EquipmentInstancesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.equipmentInstances,
          getReferencedColumn: (t) => t.equipmentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EquipmentInstancesTableAnnotationComposer(
                $db: $db,
                $table: $db.equipmentInstances,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> userAliasesRefs<T extends Object>(
    Expression<T> Function($$UserAliasesTableAnnotationComposer a) f,
  ) {
    final $$UserAliasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userAliases,
      getReferencedColumn: (t) => t.equipmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserAliasesTableAnnotationComposer(
            $db: $db,
            $table: $db.userAliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EquipmentItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EquipmentItemsTable,
          EquipmentItemData,
          $$EquipmentItemsTableFilterComposer,
          $$EquipmentItemsTableOrderingComposer,
          $$EquipmentItemsTableAnnotationComposer,
          $$EquipmentItemsTableCreateCompanionBuilder,
          $$EquipmentItemsTableUpdateCompanionBuilder,
          (EquipmentItemData, $$EquipmentItemsTableReferences),
          EquipmentItemData,
          PrefetchHooks Function({
            bool equipmentAssignmentsRefs,
            bool equipmentInstancesRefs,
            bool userAliasesRefs,
          })
        > {
  $$EquipmentItemsTableTableManager(
    _$AppDatabase db,
    $EquipmentItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$EquipmentItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$EquipmentItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$EquipmentItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> shortName = const Value.absent(),
                Value<String> equipmentFunctionsJson = const Value.absent(),
                Value<String> deploymentScenariosJson = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<String?> trainingUrl = const Value.absent(),
                Value<String?> libraryEquipmentId = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<String> extraAttributesJson = const Value.absent(),
                Value<String> trainingQuestionsJson = const Value.absent(),
                Value<String> typicalUseJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => EquipmentItemsCompanion(
                id: id,
                name: name,
                shortName: shortName,
                equipmentFunctionsJson: equipmentFunctionsJson,
                deploymentScenariosJson: deploymentScenariosJson,
                description: description,
                imagePath: imagePath,
                trainingUrl: trainingUrl,
                libraryEquipmentId: libraryEquipmentId,
                isCustom: isCustom,
                extraAttributesJson: extraAttributesJson,
                trainingQuestionsJson: trainingQuestionsJson,
                typicalUseJson: typicalUseJson,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> shortName = const Value.absent(),
                Value<String> equipmentFunctionsJson = const Value.absent(),
                Value<String> deploymentScenariosJson = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<String?> trainingUrl = const Value.absent(),
                Value<String?> libraryEquipmentId = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<String> extraAttributesJson = const Value.absent(),
                Value<String> trainingQuestionsJson = const Value.absent(),
                Value<String> typicalUseJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => EquipmentItemsCompanion.insert(
                id: id,
                name: name,
                shortName: shortName,
                equipmentFunctionsJson: equipmentFunctionsJson,
                deploymentScenariosJson: deploymentScenariosJson,
                description: description,
                imagePath: imagePath,
                trainingUrl: trainingUrl,
                libraryEquipmentId: libraryEquipmentId,
                isCustom: isCustom,
                extraAttributesJson: extraAttributesJson,
                trainingQuestionsJson: trainingQuestionsJson,
                typicalUseJson: typicalUseJson,
                updatedAt: updatedAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$EquipmentItemsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            equipmentAssignmentsRefs = false,
            equipmentInstancesRefs = false,
            userAliasesRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (equipmentAssignmentsRefs) db.equipmentAssignments,
                if (equipmentInstancesRefs) db.equipmentInstances,
                if (userAliasesRefs) db.userAliases,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (equipmentAssignmentsRefs)
                    await $_getPrefetchedData<
                      EquipmentItemData,
                      $EquipmentItemsTable,
                      AssignmentData
                    >(
                      currentTable: table,
                      referencedTable: $$EquipmentItemsTableReferences
                          ._equipmentAssignmentsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$EquipmentItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).equipmentAssignmentsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.equipmentId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (equipmentInstancesRefs)
                    await $_getPrefetchedData<
                      EquipmentItemData,
                      $EquipmentItemsTable,
                      EquipmentInstanceData
                    >(
                      currentTable: table,
                      referencedTable: $$EquipmentItemsTableReferences
                          ._equipmentInstancesRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$EquipmentItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).equipmentInstancesRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.equipmentId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (userAliasesRefs)
                    await $_getPrefetchedData<
                      EquipmentItemData,
                      $EquipmentItemsTable,
                      UserAliasData
                    >(
                      currentTable: table,
                      referencedTable: $$EquipmentItemsTableReferences
                          ._userAliasesRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$EquipmentItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).userAliasesRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.equipmentId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$EquipmentItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EquipmentItemsTable,
      EquipmentItemData,
      $$EquipmentItemsTableFilterComposer,
      $$EquipmentItemsTableOrderingComposer,
      $$EquipmentItemsTableAnnotationComposer,
      $$EquipmentItemsTableCreateCompanionBuilder,
      $$EquipmentItemsTableUpdateCompanionBuilder,
      (EquipmentItemData, $$EquipmentItemsTableReferences),
      EquipmentItemData,
      PrefetchHooks Function({
        bool equipmentAssignmentsRefs,
        bool equipmentInstancesRefs,
        bool userAliasesRefs,
      })
    >;
typedef $$EquipmentAssignmentsTableCreateCompanionBuilder =
    EquipmentAssignmentsCompanion Function({
      Value<int> id,
      required int compartmentId,
      required int equipmentId,
      Value<int> quantity,
      Value<DateTime> updatedAt,
    });
typedef $$EquipmentAssignmentsTableUpdateCompanionBuilder =
    EquipmentAssignmentsCompanion Function({
      Value<int> id,
      Value<int> compartmentId,
      Value<int> equipmentId,
      Value<int> quantity,
      Value<DateTime> updatedAt,
    });

final class $$EquipmentAssignmentsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $EquipmentAssignmentsTable,
          AssignmentData
        > {
  $$EquipmentAssignmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CompartmentsTable _compartmentIdTable(_$AppDatabase db) =>
      db.compartments.createAlias(
        $_aliasNameGenerator(
          db.equipmentAssignments.compartmentId,
          db.compartments.id,
        ),
      );

  $$CompartmentsTableProcessedTableManager get compartmentId {
    final $_column = $_itemColumn<int>('compartment_id')!;

    final manager = $$CompartmentsTableTableManager(
      $_db,
      $_db.compartments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_compartmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $EquipmentItemsTable _equipmentIdTable(_$AppDatabase db) =>
      db.equipmentItems.createAlias(
        $_aliasNameGenerator(
          db.equipmentAssignments.equipmentId,
          db.equipmentItems.id,
        ),
      );

  $$EquipmentItemsTableProcessedTableManager get equipmentId {
    final $_column = $_itemColumn<int>('equipment_id')!;

    final manager = $$EquipmentItemsTableTableManager(
      $_db,
      $_db.equipmentItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_equipmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EquipmentAssignmentsTableFilterComposer
    extends Composer<_$AppDatabase, $EquipmentAssignmentsTable> {
  $$EquipmentAssignmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CompartmentsTableFilterComposer get compartmentId {
    final $$CompartmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.compartmentId,
      referencedTable: $db.compartments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompartmentsTableFilterComposer(
            $db: $db,
            $table: $db.compartments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EquipmentItemsTableFilterComposer get equipmentId {
    final $$EquipmentItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.equipmentId,
      referencedTable: $db.equipmentItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentItemsTableFilterComposer(
            $db: $db,
            $table: $db.equipmentItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EquipmentAssignmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $EquipmentAssignmentsTable> {
  $$EquipmentAssignmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompartmentsTableOrderingComposer get compartmentId {
    final $$CompartmentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.compartmentId,
      referencedTable: $db.compartments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompartmentsTableOrderingComposer(
            $db: $db,
            $table: $db.compartments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EquipmentItemsTableOrderingComposer get equipmentId {
    final $$EquipmentItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.equipmentId,
      referencedTable: $db.equipmentItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentItemsTableOrderingComposer(
            $db: $db,
            $table: $db.equipmentItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EquipmentAssignmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EquipmentAssignmentsTable> {
  $$EquipmentAssignmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CompartmentsTableAnnotationComposer get compartmentId {
    final $$CompartmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.compartmentId,
      referencedTable: $db.compartments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompartmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.compartments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EquipmentItemsTableAnnotationComposer get equipmentId {
    final $$EquipmentItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.equipmentId,
      referencedTable: $db.equipmentItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.equipmentItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EquipmentAssignmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EquipmentAssignmentsTable,
          AssignmentData,
          $$EquipmentAssignmentsTableFilterComposer,
          $$EquipmentAssignmentsTableOrderingComposer,
          $$EquipmentAssignmentsTableAnnotationComposer,
          $$EquipmentAssignmentsTableCreateCompanionBuilder,
          $$EquipmentAssignmentsTableUpdateCompanionBuilder,
          (AssignmentData, $$EquipmentAssignmentsTableReferences),
          AssignmentData,
          PrefetchHooks Function({bool compartmentId, bool equipmentId})
        > {
  $$EquipmentAssignmentsTableTableManager(
    _$AppDatabase db,
    $EquipmentAssignmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$EquipmentAssignmentsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$EquipmentAssignmentsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$EquipmentAssignmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> compartmentId = const Value.absent(),
                Value<int> equipmentId = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => EquipmentAssignmentsCompanion(
                id: id,
                compartmentId: compartmentId,
                equipmentId: equipmentId,
                quantity: quantity,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int compartmentId,
                required int equipmentId,
                Value<int> quantity = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => EquipmentAssignmentsCompanion.insert(
                id: id,
                compartmentId: compartmentId,
                equipmentId: equipmentId,
                quantity: quantity,
                updatedAt: updatedAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$EquipmentAssignmentsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            compartmentId = false,
            equipmentId = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (compartmentId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.compartmentId,
                            referencedTable:
                                $$EquipmentAssignmentsTableReferences
                                    ._compartmentIdTable(db),
                            referencedColumn:
                                $$EquipmentAssignmentsTableReferences
                                    ._compartmentIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (equipmentId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.equipmentId,
                            referencedTable:
                                $$EquipmentAssignmentsTableReferences
                                    ._equipmentIdTable(db),
                            referencedColumn:
                                $$EquipmentAssignmentsTableReferences
                                    ._equipmentIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EquipmentAssignmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EquipmentAssignmentsTable,
      AssignmentData,
      $$EquipmentAssignmentsTableFilterComposer,
      $$EquipmentAssignmentsTableOrderingComposer,
      $$EquipmentAssignmentsTableAnnotationComposer,
      $$EquipmentAssignmentsTableCreateCompanionBuilder,
      $$EquipmentAssignmentsTableUpdateCompanionBuilder,
      (AssignmentData, $$EquipmentAssignmentsTableReferences),
      AssignmentData,
      PrefetchHooks Function({bool compartmentId, bool equipmentId})
    >;
typedef $$QuizResultsTableCreateCompanionBuilder =
    QuizResultsCompanion Function({
      Value<int> id,
      required String quizType,
      required int score,
      required int total,
      Value<int?> vehicleId,
      Value<DateTime> playedAt,
    });
typedef $$QuizResultsTableUpdateCompanionBuilder =
    QuizResultsCompanion Function({
      Value<int> id,
      Value<String> quizType,
      Value<int> score,
      Value<int> total,
      Value<int?> vehicleId,
      Value<DateTime> playedAt,
    });

final class $$QuizResultsTableReferences
    extends BaseReferences<_$AppDatabase, $QuizResultsTable, QuizResultData> {
  $$QuizResultsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $VehiclesTable _vehicleIdTable(_$AppDatabase db) =>
      db.vehicles.createAlias(
        $_aliasNameGenerator(db.quizResults.vehicleId, db.vehicles.id),
      );

  $$VehiclesTableProcessedTableManager? get vehicleId {
    final $_column = $_itemColumn<int>('vehicle_id');
    if ($_column == null) return null;
    final manager = $$VehiclesTableTableManager(
      $_db,
      $_db.vehicles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vehicleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$QuizResultsTableFilterComposer
    extends Composer<_$AppDatabase, $QuizResultsTable> {
  $$QuizResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quizType => $composableBuilder(
    column: $table.quizType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$VehiclesTableFilterComposer get vehicleId {
    final $$VehiclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableFilterComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuizResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $QuizResultsTable> {
  $$QuizResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quizType => $composableBuilder(
    column: $table.quizType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$VehiclesTableOrderingComposer get vehicleId {
    final $$VehiclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableOrderingComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuizResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuizResultsTable> {
  $$QuizResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get quizType =>
      $composableBuilder(column: $table.quizType, builder: (column) => column);

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<DateTime> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);

  $$VehiclesTableAnnotationComposer get vehicleId {
    final $$VehiclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableAnnotationComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuizResultsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuizResultsTable,
          QuizResultData,
          $$QuizResultsTableFilterComposer,
          $$QuizResultsTableOrderingComposer,
          $$QuizResultsTableAnnotationComposer,
          $$QuizResultsTableCreateCompanionBuilder,
          $$QuizResultsTableUpdateCompanionBuilder,
          (QuizResultData, $$QuizResultsTableReferences),
          QuizResultData,
          PrefetchHooks Function({bool vehicleId})
        > {
  $$QuizResultsTableTableManager(_$AppDatabase db, $QuizResultsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$QuizResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$QuizResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$QuizResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> quizType = const Value.absent(),
                Value<int> score = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<int?> vehicleId = const Value.absent(),
                Value<DateTime> playedAt = const Value.absent(),
              }) => QuizResultsCompanion(
                id: id,
                quizType: quizType,
                score: score,
                total: total,
                vehicleId: vehicleId,
                playedAt: playedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String quizType,
                required int score,
                required int total,
                Value<int?> vehicleId = const Value.absent(),
                Value<DateTime> playedAt = const Value.absent(),
              }) => QuizResultsCompanion.insert(
                id: id,
                quizType: quizType,
                score: score,
                total: total,
                vehicleId: vehicleId,
                playedAt: playedAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$QuizResultsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({vehicleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (vehicleId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.vehicleId,
                            referencedTable: $$QuizResultsTableReferences
                                ._vehicleIdTable(db),
                            referencedColumn:
                                $$QuizResultsTableReferences
                                    ._vehicleIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$QuizResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuizResultsTable,
      QuizResultData,
      $$QuizResultsTableFilterComposer,
      $$QuizResultsTableOrderingComposer,
      $$QuizResultsTableAnnotationComposer,
      $$QuizResultsTableCreateCompanionBuilder,
      $$QuizResultsTableUpdateCompanionBuilder,
      (QuizResultData, $$QuizResultsTableReferences),
      QuizResultData,
      PrefetchHooks Function({bool vehicleId})
    >;
typedef $$EquipmentInstancesTableCreateCompanionBuilder =
    EquipmentInstancesCompanion Function({
      Value<int> id,
      required int equipmentId,
      Value<int?> vehicleId,
      Value<int?> compartmentId,
      Value<String?> identifier,
      Value<String> notes,
      Value<bool> isActive,
      Value<DateTime> updatedAt,
    });
typedef $$EquipmentInstancesTableUpdateCompanionBuilder =
    EquipmentInstancesCompanion Function({
      Value<int> id,
      Value<int> equipmentId,
      Value<int?> vehicleId,
      Value<int?> compartmentId,
      Value<String?> identifier,
      Value<String> notes,
      Value<bool> isActive,
      Value<DateTime> updatedAt,
    });

final class $$EquipmentInstancesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $EquipmentInstancesTable,
          EquipmentInstanceData
        > {
  $$EquipmentInstancesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EquipmentItemsTable _equipmentIdTable(_$AppDatabase db) =>
      db.equipmentItems.createAlias(
        $_aliasNameGenerator(
          db.equipmentInstances.equipmentId,
          db.equipmentItems.id,
        ),
      );

  $$EquipmentItemsTableProcessedTableManager get equipmentId {
    final $_column = $_itemColumn<int>('equipment_id')!;

    final manager = $$EquipmentItemsTableTableManager(
      $_db,
      $_db.equipmentItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_equipmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $VehiclesTable _vehicleIdTable(_$AppDatabase db) =>
      db.vehicles.createAlias(
        $_aliasNameGenerator(db.equipmentInstances.vehicleId, db.vehicles.id),
      );

  $$VehiclesTableProcessedTableManager? get vehicleId {
    final $_column = $_itemColumn<int>('vehicle_id');
    if ($_column == null) return null;
    final manager = $$VehiclesTableTableManager(
      $_db,
      $_db.vehicles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vehicleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CompartmentsTable _compartmentIdTable(_$AppDatabase db) =>
      db.compartments.createAlias(
        $_aliasNameGenerator(
          db.equipmentInstances.compartmentId,
          db.compartments.id,
        ),
      );

  $$CompartmentsTableProcessedTableManager? get compartmentId {
    final $_column = $_itemColumn<int>('compartment_id');
    if ($_column == null) return null;
    final manager = $$CompartmentsTableTableManager(
      $_db,
      $_db.compartments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_compartmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $InspectionSchedulesTable,
    List<InspectionScheduleData>
  >
  _inspectionSchedulesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.inspectionSchedules,
        aliasName: $_aliasNameGenerator(
          db.equipmentInstances.id,
          db.inspectionSchedules.instanceId,
        ),
      );

  $$InspectionSchedulesTableProcessedTableManager get inspectionSchedulesRefs {
    final manager = $$InspectionSchedulesTableTableManager(
      $_db,
      $_db.inspectionSchedules,
    ).filter((f) => f.instanceId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _inspectionSchedulesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EquipmentInstancesTableFilterComposer
    extends Composer<_$AppDatabase, $EquipmentInstancesTable> {
  $$EquipmentInstancesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get identifier => $composableBuilder(
    column: $table.identifier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$EquipmentItemsTableFilterComposer get equipmentId {
    final $$EquipmentItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.equipmentId,
      referencedTable: $db.equipmentItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentItemsTableFilterComposer(
            $db: $db,
            $table: $db.equipmentItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VehiclesTableFilterComposer get vehicleId {
    final $$VehiclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableFilterComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CompartmentsTableFilterComposer get compartmentId {
    final $$CompartmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.compartmentId,
      referencedTable: $db.compartments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompartmentsTableFilterComposer(
            $db: $db,
            $table: $db.compartments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> inspectionSchedulesRefs(
    Expression<bool> Function($$InspectionSchedulesTableFilterComposer f) f,
  ) {
    final $$InspectionSchedulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.inspectionSchedules,
      getReferencedColumn: (t) => t.instanceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InspectionSchedulesTableFilterComposer(
            $db: $db,
            $table: $db.inspectionSchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EquipmentInstancesTableOrderingComposer
    extends Composer<_$AppDatabase, $EquipmentInstancesTable> {
  $$EquipmentInstancesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get identifier => $composableBuilder(
    column: $table.identifier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$EquipmentItemsTableOrderingComposer get equipmentId {
    final $$EquipmentItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.equipmentId,
      referencedTable: $db.equipmentItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentItemsTableOrderingComposer(
            $db: $db,
            $table: $db.equipmentItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VehiclesTableOrderingComposer get vehicleId {
    final $$VehiclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableOrderingComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CompartmentsTableOrderingComposer get compartmentId {
    final $$CompartmentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.compartmentId,
      referencedTable: $db.compartments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompartmentsTableOrderingComposer(
            $db: $db,
            $table: $db.compartments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EquipmentInstancesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EquipmentInstancesTable> {
  $$EquipmentInstancesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get identifier => $composableBuilder(
    column: $table.identifier,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$EquipmentItemsTableAnnotationComposer get equipmentId {
    final $$EquipmentItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.equipmentId,
      referencedTable: $db.equipmentItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.equipmentItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VehiclesTableAnnotationComposer get vehicleId {
    final $$VehiclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableAnnotationComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CompartmentsTableAnnotationComposer get compartmentId {
    final $$CompartmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.compartmentId,
      referencedTable: $db.compartments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompartmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.compartments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> inspectionSchedulesRefs<T extends Object>(
    Expression<T> Function($$InspectionSchedulesTableAnnotationComposer a) f,
  ) {
    final $$InspectionSchedulesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.inspectionSchedules,
          getReferencedColumn: (t) => t.instanceId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$InspectionSchedulesTableAnnotationComposer(
                $db: $db,
                $table: $db.inspectionSchedules,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$EquipmentInstancesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EquipmentInstancesTable,
          EquipmentInstanceData,
          $$EquipmentInstancesTableFilterComposer,
          $$EquipmentInstancesTableOrderingComposer,
          $$EquipmentInstancesTableAnnotationComposer,
          $$EquipmentInstancesTableCreateCompanionBuilder,
          $$EquipmentInstancesTableUpdateCompanionBuilder,
          (EquipmentInstanceData, $$EquipmentInstancesTableReferences),
          EquipmentInstanceData,
          PrefetchHooks Function({
            bool equipmentId,
            bool vehicleId,
            bool compartmentId,
            bool inspectionSchedulesRefs,
          })
        > {
  $$EquipmentInstancesTableTableManager(
    _$AppDatabase db,
    $EquipmentInstancesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$EquipmentInstancesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$EquipmentInstancesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$EquipmentInstancesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> equipmentId = const Value.absent(),
                Value<int?> vehicleId = const Value.absent(),
                Value<int?> compartmentId = const Value.absent(),
                Value<String?> identifier = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => EquipmentInstancesCompanion(
                id: id,
                equipmentId: equipmentId,
                vehicleId: vehicleId,
                compartmentId: compartmentId,
                identifier: identifier,
                notes: notes,
                isActive: isActive,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int equipmentId,
                Value<int?> vehicleId = const Value.absent(),
                Value<int?> compartmentId = const Value.absent(),
                Value<String?> identifier = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => EquipmentInstancesCompanion.insert(
                id: id,
                equipmentId: equipmentId,
                vehicleId: vehicleId,
                compartmentId: compartmentId,
                identifier: identifier,
                notes: notes,
                isActive: isActive,
                updatedAt: updatedAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$EquipmentInstancesTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            equipmentId = false,
            vehicleId = false,
            compartmentId = false,
            inspectionSchedulesRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (inspectionSchedulesRefs) db.inspectionSchedules,
              ],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (equipmentId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.equipmentId,
                            referencedTable: $$EquipmentInstancesTableReferences
                                ._equipmentIdTable(db),
                            referencedColumn:
                                $$EquipmentInstancesTableReferences
                                    ._equipmentIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (vehicleId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.vehicleId,
                            referencedTable: $$EquipmentInstancesTableReferences
                                ._vehicleIdTable(db),
                            referencedColumn:
                                $$EquipmentInstancesTableReferences
                                    ._vehicleIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (compartmentId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.compartmentId,
                            referencedTable: $$EquipmentInstancesTableReferences
                                ._compartmentIdTable(db),
                            referencedColumn:
                                $$EquipmentInstancesTableReferences
                                    ._compartmentIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (inspectionSchedulesRefs)
                    await $_getPrefetchedData<
                      EquipmentInstanceData,
                      $EquipmentInstancesTable,
                      InspectionScheduleData
                    >(
                      currentTable: table,
                      referencedTable: $$EquipmentInstancesTableReferences
                          ._inspectionSchedulesRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$EquipmentInstancesTableReferences(
                                db,
                                table,
                                p0,
                              ).inspectionSchedulesRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.instanceId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$EquipmentInstancesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EquipmentInstancesTable,
      EquipmentInstanceData,
      $$EquipmentInstancesTableFilterComposer,
      $$EquipmentInstancesTableOrderingComposer,
      $$EquipmentInstancesTableAnnotationComposer,
      $$EquipmentInstancesTableCreateCompanionBuilder,
      $$EquipmentInstancesTableUpdateCompanionBuilder,
      (EquipmentInstanceData, $$EquipmentInstancesTableReferences),
      EquipmentInstanceData,
      PrefetchHooks Function({
        bool equipmentId,
        bool vehicleId,
        bool compartmentId,
        bool inspectionSchedulesRefs,
      })
    >;
typedef $$InspectionSchedulesTableCreateCompanionBuilder =
    InspectionSchedulesCompanion Function({
      Value<int> id,
      required int instanceId,
      required String kind,
      required String title,
      Value<int?> intervalMonths,
      Value<DateTime?> lastDoneAt,
      required DateTime dueAt,
      Value<String> notes,
      Value<DateTime> updatedAt,
    });
typedef $$InspectionSchedulesTableUpdateCompanionBuilder =
    InspectionSchedulesCompanion Function({
      Value<int> id,
      Value<int> instanceId,
      Value<String> kind,
      Value<String> title,
      Value<int?> intervalMonths,
      Value<DateTime?> lastDoneAt,
      Value<DateTime> dueAt,
      Value<String> notes,
      Value<DateTime> updatedAt,
    });

final class $$InspectionSchedulesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $InspectionSchedulesTable,
          InspectionScheduleData
        > {
  $$InspectionSchedulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EquipmentInstancesTable _instanceIdTable(_$AppDatabase db) =>
      db.equipmentInstances.createAlias(
        $_aliasNameGenerator(
          db.inspectionSchedules.instanceId,
          db.equipmentInstances.id,
        ),
      );

  $$EquipmentInstancesTableProcessedTableManager get instanceId {
    final $_column = $_itemColumn<int>('instance_id')!;

    final manager = $$EquipmentInstancesTableTableManager(
      $_db,
      $_db.equipmentInstances,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_instanceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$InspectionLogTable, List<InspectionLogData>>
  _inspectionLogRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.inspectionLog,
    aliasName: $_aliasNameGenerator(
      db.inspectionSchedules.id,
      db.inspectionLog.scheduleId,
    ),
  );

  $$InspectionLogTableProcessedTableManager get inspectionLogRefs {
    final manager = $$InspectionLogTableTableManager(
      $_db,
      $_db.inspectionLog,
    ).filter((f) => f.scheduleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_inspectionLogRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$InspectionSchedulesTableFilterComposer
    extends Composer<_$AppDatabase, $InspectionSchedulesTable> {
  $$InspectionSchedulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalMonths => $composableBuilder(
    column: $table.intervalMonths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastDoneAt => $composableBuilder(
    column: $table.lastDoneAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$EquipmentInstancesTableFilterComposer get instanceId {
    final $$EquipmentInstancesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.instanceId,
      referencedTable: $db.equipmentInstances,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentInstancesTableFilterComposer(
            $db: $db,
            $table: $db.equipmentInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> inspectionLogRefs(
    Expression<bool> Function($$InspectionLogTableFilterComposer f) f,
  ) {
    final $$InspectionLogTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.inspectionLog,
      getReferencedColumn: (t) => t.scheduleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InspectionLogTableFilterComposer(
            $db: $db,
            $table: $db.inspectionLog,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$InspectionSchedulesTableOrderingComposer
    extends Composer<_$AppDatabase, $InspectionSchedulesTable> {
  $$InspectionSchedulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalMonths => $composableBuilder(
    column: $table.intervalMonths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastDoneAt => $composableBuilder(
    column: $table.lastDoneAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$EquipmentInstancesTableOrderingComposer get instanceId {
    final $$EquipmentInstancesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.instanceId,
      referencedTable: $db.equipmentInstances,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentInstancesTableOrderingComposer(
            $db: $db,
            $table: $db.equipmentInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InspectionSchedulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InspectionSchedulesTable> {
  $$InspectionSchedulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get intervalMonths => $composableBuilder(
    column: $table.intervalMonths,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastDoneAt => $composableBuilder(
    column: $table.lastDoneAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$EquipmentInstancesTableAnnotationComposer get instanceId {
    final $$EquipmentInstancesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.instanceId,
          referencedTable: $db.equipmentInstances,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EquipmentInstancesTableAnnotationComposer(
                $db: $db,
                $table: $db.equipmentInstances,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<T> inspectionLogRefs<T extends Object>(
    Expression<T> Function($$InspectionLogTableAnnotationComposer a) f,
  ) {
    final $$InspectionLogTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.inspectionLog,
      getReferencedColumn: (t) => t.scheduleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InspectionLogTableAnnotationComposer(
            $db: $db,
            $table: $db.inspectionLog,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$InspectionSchedulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InspectionSchedulesTable,
          InspectionScheduleData,
          $$InspectionSchedulesTableFilterComposer,
          $$InspectionSchedulesTableOrderingComposer,
          $$InspectionSchedulesTableAnnotationComposer,
          $$InspectionSchedulesTableCreateCompanionBuilder,
          $$InspectionSchedulesTableUpdateCompanionBuilder,
          (InspectionScheduleData, $$InspectionSchedulesTableReferences),
          InspectionScheduleData,
          PrefetchHooks Function({bool instanceId, bool inspectionLogRefs})
        > {
  $$InspectionSchedulesTableTableManager(
    _$AppDatabase db,
    $InspectionSchedulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$InspectionSchedulesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$InspectionSchedulesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$InspectionSchedulesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> instanceId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int?> intervalMonths = const Value.absent(),
                Value<DateTime?> lastDoneAt = const Value.absent(),
                Value<DateTime> dueAt = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => InspectionSchedulesCompanion(
                id: id,
                instanceId: instanceId,
                kind: kind,
                title: title,
                intervalMonths: intervalMonths,
                lastDoneAt: lastDoneAt,
                dueAt: dueAt,
                notes: notes,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int instanceId,
                required String kind,
                required String title,
                Value<int?> intervalMonths = const Value.absent(),
                Value<DateTime?> lastDoneAt = const Value.absent(),
                required DateTime dueAt,
                Value<String> notes = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => InspectionSchedulesCompanion.insert(
                id: id,
                instanceId: instanceId,
                kind: kind,
                title: title,
                intervalMonths: intervalMonths,
                lastDoneAt: lastDoneAt,
                dueAt: dueAt,
                notes: notes,
                updatedAt: updatedAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$InspectionSchedulesTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            instanceId = false,
            inspectionLogRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (inspectionLogRefs) db.inspectionLog,
              ],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (instanceId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.instanceId,
                            referencedTable:
                                $$InspectionSchedulesTableReferences
                                    ._instanceIdTable(db),
                            referencedColumn:
                                $$InspectionSchedulesTableReferences
                                    ._instanceIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (inspectionLogRefs)
                    await $_getPrefetchedData<
                      InspectionScheduleData,
                      $InspectionSchedulesTable,
                      InspectionLogData
                    >(
                      currentTable: table,
                      referencedTable: $$InspectionSchedulesTableReferences
                          ._inspectionLogRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$InspectionSchedulesTableReferences(
                                db,
                                table,
                                p0,
                              ).inspectionLogRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.scheduleId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$InspectionSchedulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InspectionSchedulesTable,
      InspectionScheduleData,
      $$InspectionSchedulesTableFilterComposer,
      $$InspectionSchedulesTableOrderingComposer,
      $$InspectionSchedulesTableAnnotationComposer,
      $$InspectionSchedulesTableCreateCompanionBuilder,
      $$InspectionSchedulesTableUpdateCompanionBuilder,
      (InspectionScheduleData, $$InspectionSchedulesTableReferences),
      InspectionScheduleData,
      PrefetchHooks Function({bool instanceId, bool inspectionLogRefs})
    >;
typedef $$InspectionLogTableCreateCompanionBuilder =
    InspectionLogCompanion Function({
      Value<int> id,
      required int scheduleId,
      required DateTime doneAt,
      Value<String> doneBy,
      Value<String> note,
    });
typedef $$InspectionLogTableUpdateCompanionBuilder =
    InspectionLogCompanion Function({
      Value<int> id,
      Value<int> scheduleId,
      Value<DateTime> doneAt,
      Value<String> doneBy,
      Value<String> note,
    });

final class $$InspectionLogTableReferences
    extends
        BaseReferences<_$AppDatabase, $InspectionLogTable, InspectionLogData> {
  $$InspectionLogTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $InspectionSchedulesTable _scheduleIdTable(_$AppDatabase db) =>
      db.inspectionSchedules.createAlias(
        $_aliasNameGenerator(
          db.inspectionLog.scheduleId,
          db.inspectionSchedules.id,
        ),
      );

  $$InspectionSchedulesTableProcessedTableManager get scheduleId {
    final $_column = $_itemColumn<int>('schedule_id')!;

    final manager = $$InspectionSchedulesTableTableManager(
      $_db,
      $_db.inspectionSchedules,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scheduleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$InspectionLogTableFilterComposer
    extends Composer<_$AppDatabase, $InspectionLogTable> {
  $$InspectionLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get doneAt => $composableBuilder(
    column: $table.doneAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get doneBy => $composableBuilder(
    column: $table.doneBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$InspectionSchedulesTableFilterComposer get scheduleId {
    final $$InspectionSchedulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scheduleId,
      referencedTable: $db.inspectionSchedules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InspectionSchedulesTableFilterComposer(
            $db: $db,
            $table: $db.inspectionSchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InspectionLogTableOrderingComposer
    extends Composer<_$AppDatabase, $InspectionLogTable> {
  $$InspectionLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get doneAt => $composableBuilder(
    column: $table.doneAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get doneBy => $composableBuilder(
    column: $table.doneBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$InspectionSchedulesTableOrderingComposer get scheduleId {
    final $$InspectionSchedulesTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.scheduleId,
          referencedTable: $db.inspectionSchedules,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$InspectionSchedulesTableOrderingComposer(
                $db: $db,
                $table: $db.inspectionSchedules,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$InspectionLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $InspectionLogTable> {
  $$InspectionLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get doneAt =>
      $composableBuilder(column: $table.doneAt, builder: (column) => column);

  GeneratedColumn<String> get doneBy =>
      $composableBuilder(column: $table.doneBy, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$InspectionSchedulesTableAnnotationComposer get scheduleId {
    final $$InspectionSchedulesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.scheduleId,
          referencedTable: $db.inspectionSchedules,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$InspectionSchedulesTableAnnotationComposer(
                $db: $db,
                $table: $db.inspectionSchedules,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$InspectionLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InspectionLogTable,
          InspectionLogData,
          $$InspectionLogTableFilterComposer,
          $$InspectionLogTableOrderingComposer,
          $$InspectionLogTableAnnotationComposer,
          $$InspectionLogTableCreateCompanionBuilder,
          $$InspectionLogTableUpdateCompanionBuilder,
          (InspectionLogData, $$InspectionLogTableReferences),
          InspectionLogData,
          PrefetchHooks Function({bool scheduleId})
        > {
  $$InspectionLogTableTableManager(_$AppDatabase db, $InspectionLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$InspectionLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$InspectionLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$InspectionLogTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> scheduleId = const Value.absent(),
                Value<DateTime> doneAt = const Value.absent(),
                Value<String> doneBy = const Value.absent(),
                Value<String> note = const Value.absent(),
              }) => InspectionLogCompanion(
                id: id,
                scheduleId: scheduleId,
                doneAt: doneAt,
                doneBy: doneBy,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int scheduleId,
                required DateTime doneAt,
                Value<String> doneBy = const Value.absent(),
                Value<String> note = const Value.absent(),
              }) => InspectionLogCompanion.insert(
                id: id,
                scheduleId: scheduleId,
                doneAt: doneAt,
                doneBy: doneBy,
                note: note,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$InspectionLogTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({scheduleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (scheduleId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.scheduleId,
                            referencedTable: $$InspectionLogTableReferences
                                ._scheduleIdTable(db),
                            referencedColumn:
                                $$InspectionLogTableReferences
                                    ._scheduleIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$InspectionLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InspectionLogTable,
      InspectionLogData,
      $$InspectionLogTableFilterComposer,
      $$InspectionLogTableOrderingComposer,
      $$InspectionLogTableAnnotationComposer,
      $$InspectionLogTableCreateCompanionBuilder,
      $$InspectionLogTableUpdateCompanionBuilder,
      (InspectionLogData, $$InspectionLogTableReferences),
      InspectionLogData,
      PrefetchHooks Function({bool scheduleId})
    >;
typedef $$UserAliasesTableCreateCompanionBuilder =
    UserAliasesCompanion Function({
      Value<int> id,
      required String alias,
      required int equipmentId,
      Value<DateTime> updatedAt,
    });
typedef $$UserAliasesTableUpdateCompanionBuilder =
    UserAliasesCompanion Function({
      Value<int> id,
      Value<String> alias,
      Value<int> equipmentId,
      Value<DateTime> updatedAt,
    });

final class $$UserAliasesTableReferences
    extends BaseReferences<_$AppDatabase, $UserAliasesTable, UserAliasData> {
  $$UserAliasesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EquipmentItemsTable _equipmentIdTable(_$AppDatabase db) =>
      db.equipmentItems.createAlias(
        $_aliasNameGenerator(db.userAliases.equipmentId, db.equipmentItems.id),
      );

  $$EquipmentItemsTableProcessedTableManager get equipmentId {
    final $_column = $_itemColumn<int>('equipment_id')!;

    final manager = $$EquipmentItemsTableTableManager(
      $_db,
      $_db.equipmentItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_equipmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$UserAliasesTableFilterComposer
    extends Composer<_$AppDatabase, $UserAliasesTable> {
  $$UserAliasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$EquipmentItemsTableFilterComposer get equipmentId {
    final $$EquipmentItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.equipmentId,
      referencedTable: $db.equipmentItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentItemsTableFilterComposer(
            $db: $db,
            $table: $db.equipmentItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserAliasesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserAliasesTable> {
  $$UserAliasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$EquipmentItemsTableOrderingComposer get equipmentId {
    final $$EquipmentItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.equipmentId,
      referencedTable: $db.equipmentItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentItemsTableOrderingComposer(
            $db: $db,
            $table: $db.equipmentItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserAliasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserAliasesTable> {
  $$UserAliasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$EquipmentItemsTableAnnotationComposer get equipmentId {
    final $$EquipmentItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.equipmentId,
      referencedTable: $db.equipmentItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.equipmentItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserAliasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserAliasesTable,
          UserAliasData,
          $$UserAliasesTableFilterComposer,
          $$UserAliasesTableOrderingComposer,
          $$UserAliasesTableAnnotationComposer,
          $$UserAliasesTableCreateCompanionBuilder,
          $$UserAliasesTableUpdateCompanionBuilder,
          (UserAliasData, $$UserAliasesTableReferences),
          UserAliasData,
          PrefetchHooks Function({bool equipmentId})
        > {
  $$UserAliasesTableTableManager(_$AppDatabase db, $UserAliasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$UserAliasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$UserAliasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$UserAliasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> alias = const Value.absent(),
                Value<int> equipmentId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserAliasesCompanion(
                id: id,
                alias: alias,
                equipmentId: equipmentId,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String alias,
                required int equipmentId,
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserAliasesCompanion.insert(
                id: id,
                alias: alias,
                equipmentId: equipmentId,
                updatedAt: updatedAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$UserAliasesTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({equipmentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (equipmentId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.equipmentId,
                            referencedTable: $$UserAliasesTableReferences
                                ._equipmentIdTable(db),
                            referencedColumn:
                                $$UserAliasesTableReferences
                                    ._equipmentIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$UserAliasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserAliasesTable,
      UserAliasData,
      $$UserAliasesTableFilterComposer,
      $$UserAliasesTableOrderingComposer,
      $$UserAliasesTableAnnotationComposer,
      $$UserAliasesTableCreateCompanionBuilder,
      $$UserAliasesTableUpdateCompanionBuilder,
      (UserAliasData, $$UserAliasesTableReferences),
      UserAliasData,
      PrefetchHooks Function({bool equipmentId})
    >;
typedef $$SyncMetaTableCreateCompanionBuilder =
    SyncMetaCompanion Function({
      Value<int> id,
      Value<int> lastPulledVersion,
      Value<DateTime?> lastPulledAt,
      Value<bool> localDirty,
    });
typedef $$SyncMetaTableUpdateCompanionBuilder =
    SyncMetaCompanion Function({
      Value<int> id,
      Value<int> lastPulledVersion,
      Value<DateTime?> lastPulledAt,
      Value<bool> localDirty,
    });

class $$SyncMetaTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPulledVersion => $composableBuilder(
    column: $table.lastPulledVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get localDirty => $composableBuilder(
    column: $table.localDirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPulledVersion => $composableBuilder(
    column: $table.lastPulledVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get localDirty => $composableBuilder(
    column: $table.localDirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lastPulledVersion => $composableBuilder(
    column: $table.lastPulledVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get localDirty => $composableBuilder(
    column: $table.localDirty,
    builder: (column) => column,
  );
}

class $$SyncMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetaTable,
          SyncMetaData,
          $$SyncMetaTableFilterComposer,
          $$SyncMetaTableOrderingComposer,
          $$SyncMetaTableAnnotationComposer,
          $$SyncMetaTableCreateCompanionBuilder,
          $$SyncMetaTableUpdateCompanionBuilder,
          (
            SyncMetaData,
            BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaData>,
          ),
          SyncMetaData,
          PrefetchHooks Function()
        > {
  $$SyncMetaTableTableManager(_$AppDatabase db, $SyncMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$SyncMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$SyncMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$SyncMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lastPulledVersion = const Value.absent(),
                Value<DateTime?> lastPulledAt = const Value.absent(),
                Value<bool> localDirty = const Value.absent(),
              }) => SyncMetaCompanion(
                id: id,
                lastPulledVersion: lastPulledVersion,
                lastPulledAt: lastPulledAt,
                localDirty: localDirty,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lastPulledVersion = const Value.absent(),
                Value<DateTime?> lastPulledAt = const Value.absent(),
                Value<bool> localDirty = const Value.absent(),
              }) => SyncMetaCompanion.insert(
                id: id,
                lastPulledVersion: lastPulledVersion,
                lastPulledAt: lastPulledAt,
                localDirty: localDirty,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetaTable,
      SyncMetaData,
      $$SyncMetaTableFilterComposer,
      $$SyncMetaTableOrderingComposer,
      $$SyncMetaTableAnnotationComposer,
      $$SyncMetaTableCreateCompanionBuilder,
      $$SyncMetaTableUpdateCompanionBuilder,
      (
        SyncMetaData,
        BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaData>,
      ),
      SyncMetaData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$VehiclesTableTableManager get vehicles =>
      $$VehiclesTableTableManager(_db, _db.vehicles);
  $$CompartmentsTableTableManager get compartments =>
      $$CompartmentsTableTableManager(_db, _db.compartments);
  $$EquipmentItemsTableTableManager get equipmentItems =>
      $$EquipmentItemsTableTableManager(_db, _db.equipmentItems);
  $$EquipmentAssignmentsTableTableManager get equipmentAssignments =>
      $$EquipmentAssignmentsTableTableManager(_db, _db.equipmentAssignments);
  $$QuizResultsTableTableManager get quizResults =>
      $$QuizResultsTableTableManager(_db, _db.quizResults);
  $$EquipmentInstancesTableTableManager get equipmentInstances =>
      $$EquipmentInstancesTableTableManager(_db, _db.equipmentInstances);
  $$InspectionSchedulesTableTableManager get inspectionSchedules =>
      $$InspectionSchedulesTableTableManager(_db, _db.inspectionSchedules);
  $$InspectionLogTableTableManager get inspectionLog =>
      $$InspectionLogTableTableManager(_db, _db.inspectionLog);
  $$UserAliasesTableTableManager get userAliases =>
      $$UserAliasesTableTableManager(_db, _db.userAliases);
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db, _db.syncMeta);
}
