// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'due_inspection_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DueInspectionEntry {

 InspectionSchedule get schedule; EquipmentInstance get instance; String get equipmentName; String? get equipmentImagePath; String? get vehicleName;
/// Create a copy of DueInspectionEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DueInspectionEntryCopyWith<DueInspectionEntry> get copyWith => _$DueInspectionEntryCopyWithImpl<DueInspectionEntry>(this as DueInspectionEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DueInspectionEntry&&(identical(other.schedule, schedule) || other.schedule == schedule)&&(identical(other.instance, instance) || other.instance == instance)&&(identical(other.equipmentName, equipmentName) || other.equipmentName == equipmentName)&&(identical(other.equipmentImagePath, equipmentImagePath) || other.equipmentImagePath == equipmentImagePath)&&(identical(other.vehicleName, vehicleName) || other.vehicleName == vehicleName));
}


@override
int get hashCode => Object.hash(runtimeType,schedule,instance,equipmentName,equipmentImagePath,vehicleName);

@override
String toString() {
  return 'DueInspectionEntry(schedule: $schedule, instance: $instance, equipmentName: $equipmentName, equipmentImagePath: $equipmentImagePath, vehicleName: $vehicleName)';
}


}

/// @nodoc
abstract mixin class $DueInspectionEntryCopyWith<$Res>  {
  factory $DueInspectionEntryCopyWith(DueInspectionEntry value, $Res Function(DueInspectionEntry) _then) = _$DueInspectionEntryCopyWithImpl;
@useResult
$Res call({
 InspectionSchedule schedule, EquipmentInstance instance, String equipmentName, String? equipmentImagePath, String? vehicleName
});


$InspectionScheduleCopyWith<$Res> get schedule;$EquipmentInstanceCopyWith<$Res> get instance;

}
/// @nodoc
class _$DueInspectionEntryCopyWithImpl<$Res>
    implements $DueInspectionEntryCopyWith<$Res> {
  _$DueInspectionEntryCopyWithImpl(this._self, this._then);

  final DueInspectionEntry _self;
  final $Res Function(DueInspectionEntry) _then;

/// Create a copy of DueInspectionEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? schedule = null,Object? instance = null,Object? equipmentName = null,Object? equipmentImagePath = freezed,Object? vehicleName = freezed,}) {
  return _then(_self.copyWith(
schedule: null == schedule ? _self.schedule : schedule // ignore: cast_nullable_to_non_nullable
as InspectionSchedule,instance: null == instance ? _self.instance : instance // ignore: cast_nullable_to_non_nullable
as EquipmentInstance,equipmentName: null == equipmentName ? _self.equipmentName : equipmentName // ignore: cast_nullable_to_non_nullable
as String,equipmentImagePath: freezed == equipmentImagePath ? _self.equipmentImagePath : equipmentImagePath // ignore: cast_nullable_to_non_nullable
as String?,vehicleName: freezed == vehicleName ? _self.vehicleName : vehicleName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of DueInspectionEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InspectionScheduleCopyWith<$Res> get schedule {
  
  return $InspectionScheduleCopyWith<$Res>(_self.schedule, (value) {
    return _then(_self.copyWith(schedule: value));
  });
}/// Create a copy of DueInspectionEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EquipmentInstanceCopyWith<$Res> get instance {
  
  return $EquipmentInstanceCopyWith<$Res>(_self.instance, (value) {
    return _then(_self.copyWith(instance: value));
  });
}
}


/// Adds pattern-matching-related methods to [DueInspectionEntry].
extension DueInspectionEntryPatterns on DueInspectionEntry {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DueInspectionEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DueInspectionEntry() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DueInspectionEntry value)  $default,){
final _that = this;
switch (_that) {
case _DueInspectionEntry():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DueInspectionEntry value)?  $default,){
final _that = this;
switch (_that) {
case _DueInspectionEntry() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( InspectionSchedule schedule,  EquipmentInstance instance,  String equipmentName,  String? equipmentImagePath,  String? vehicleName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DueInspectionEntry() when $default != null:
return $default(_that.schedule,_that.instance,_that.equipmentName,_that.equipmentImagePath,_that.vehicleName);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( InspectionSchedule schedule,  EquipmentInstance instance,  String equipmentName,  String? equipmentImagePath,  String? vehicleName)  $default,) {final _that = this;
switch (_that) {
case _DueInspectionEntry():
return $default(_that.schedule,_that.instance,_that.equipmentName,_that.equipmentImagePath,_that.vehicleName);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( InspectionSchedule schedule,  EquipmentInstance instance,  String equipmentName,  String? equipmentImagePath,  String? vehicleName)?  $default,) {final _that = this;
switch (_that) {
case _DueInspectionEntry() when $default != null:
return $default(_that.schedule,_that.instance,_that.equipmentName,_that.equipmentImagePath,_that.vehicleName);case _:
  return null;

}
}

}

/// @nodoc


class _DueInspectionEntry extends DueInspectionEntry {
  const _DueInspectionEntry({required this.schedule, required this.instance, required this.equipmentName, this.equipmentImagePath, this.vehicleName}): super._();
  

@override final  InspectionSchedule schedule;
@override final  EquipmentInstance instance;
@override final  String equipmentName;
@override final  String? equipmentImagePath;
@override final  String? vehicleName;

/// Create a copy of DueInspectionEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DueInspectionEntryCopyWith<_DueInspectionEntry> get copyWith => __$DueInspectionEntryCopyWithImpl<_DueInspectionEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DueInspectionEntry&&(identical(other.schedule, schedule) || other.schedule == schedule)&&(identical(other.instance, instance) || other.instance == instance)&&(identical(other.equipmentName, equipmentName) || other.equipmentName == equipmentName)&&(identical(other.equipmentImagePath, equipmentImagePath) || other.equipmentImagePath == equipmentImagePath)&&(identical(other.vehicleName, vehicleName) || other.vehicleName == vehicleName));
}


@override
int get hashCode => Object.hash(runtimeType,schedule,instance,equipmentName,equipmentImagePath,vehicleName);

@override
String toString() {
  return 'DueInspectionEntry(schedule: $schedule, instance: $instance, equipmentName: $equipmentName, equipmentImagePath: $equipmentImagePath, vehicleName: $vehicleName)';
}


}

/// @nodoc
abstract mixin class _$DueInspectionEntryCopyWith<$Res> implements $DueInspectionEntryCopyWith<$Res> {
  factory _$DueInspectionEntryCopyWith(_DueInspectionEntry value, $Res Function(_DueInspectionEntry) _then) = __$DueInspectionEntryCopyWithImpl;
@override @useResult
$Res call({
 InspectionSchedule schedule, EquipmentInstance instance, String equipmentName, String? equipmentImagePath, String? vehicleName
});


@override $InspectionScheduleCopyWith<$Res> get schedule;@override $EquipmentInstanceCopyWith<$Res> get instance;

}
/// @nodoc
class __$DueInspectionEntryCopyWithImpl<$Res>
    implements _$DueInspectionEntryCopyWith<$Res> {
  __$DueInspectionEntryCopyWithImpl(this._self, this._then);

  final _DueInspectionEntry _self;
  final $Res Function(_DueInspectionEntry) _then;

/// Create a copy of DueInspectionEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? schedule = null,Object? instance = null,Object? equipmentName = null,Object? equipmentImagePath = freezed,Object? vehicleName = freezed,}) {
  return _then(_DueInspectionEntry(
schedule: null == schedule ? _self.schedule : schedule // ignore: cast_nullable_to_non_nullable
as InspectionSchedule,instance: null == instance ? _self.instance : instance // ignore: cast_nullable_to_non_nullable
as EquipmentInstance,equipmentName: null == equipmentName ? _self.equipmentName : equipmentName // ignore: cast_nullable_to_non_nullable
as String,equipmentImagePath: freezed == equipmentImagePath ? _self.equipmentImagePath : equipmentImagePath // ignore: cast_nullable_to_non_nullable
as String?,vehicleName: freezed == vehicleName ? _self.vehicleName : vehicleName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of DueInspectionEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InspectionScheduleCopyWith<$Res> get schedule {
  
  return $InspectionScheduleCopyWith<$Res>(_self.schedule, (value) {
    return _then(_self.copyWith(schedule: value));
  });
}/// Create a copy of DueInspectionEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EquipmentInstanceCopyWith<$Res> get instance {
  
  return $EquipmentInstanceCopyWith<$Res>(_self.instance, (value) {
    return _then(_self.copyWith(instance: value));
  });
}
}

// dart format on
