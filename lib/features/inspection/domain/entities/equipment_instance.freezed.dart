// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'equipment_instance.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$EquipmentInstance {

 int get id; int get equipmentId; int? get vehicleId; int? get compartmentId; String? get identifier; String get notes; bool get isActive; DateTime get updatedAt;
/// Create a copy of EquipmentInstance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EquipmentInstanceCopyWith<EquipmentInstance> get copyWith => _$EquipmentInstanceCopyWithImpl<EquipmentInstance>(this as EquipmentInstance, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EquipmentInstance&&(identical(other.id, id) || other.id == id)&&(identical(other.equipmentId, equipmentId) || other.equipmentId == equipmentId)&&(identical(other.vehicleId, vehicleId) || other.vehicleId == vehicleId)&&(identical(other.compartmentId, compartmentId) || other.compartmentId == compartmentId)&&(identical(other.identifier, identifier) || other.identifier == identifier)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,equipmentId,vehicleId,compartmentId,identifier,notes,isActive,updatedAt);

@override
String toString() {
  return 'EquipmentInstance(id: $id, equipmentId: $equipmentId, vehicleId: $vehicleId, compartmentId: $compartmentId, identifier: $identifier, notes: $notes, isActive: $isActive, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $EquipmentInstanceCopyWith<$Res>  {
  factory $EquipmentInstanceCopyWith(EquipmentInstance value, $Res Function(EquipmentInstance) _then) = _$EquipmentInstanceCopyWithImpl;
@useResult
$Res call({
 int id, int equipmentId, int? vehicleId, int? compartmentId, String? identifier, String notes, bool isActive, DateTime updatedAt
});




}
/// @nodoc
class _$EquipmentInstanceCopyWithImpl<$Res>
    implements $EquipmentInstanceCopyWith<$Res> {
  _$EquipmentInstanceCopyWithImpl(this._self, this._then);

  final EquipmentInstance _self;
  final $Res Function(EquipmentInstance) _then;

/// Create a copy of EquipmentInstance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? equipmentId = null,Object? vehicleId = freezed,Object? compartmentId = freezed,Object? identifier = freezed,Object? notes = null,Object? isActive = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,equipmentId: null == equipmentId ? _self.equipmentId : equipmentId // ignore: cast_nullable_to_non_nullable
as int,vehicleId: freezed == vehicleId ? _self.vehicleId : vehicleId // ignore: cast_nullable_to_non_nullable
as int?,compartmentId: freezed == compartmentId ? _self.compartmentId : compartmentId // ignore: cast_nullable_to_non_nullable
as int?,identifier: freezed == identifier ? _self.identifier : identifier // ignore: cast_nullable_to_non_nullable
as String?,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [EquipmentInstance].
extension EquipmentInstancePatterns on EquipmentInstance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EquipmentInstance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EquipmentInstance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EquipmentInstance value)  $default,){
final _that = this;
switch (_that) {
case _EquipmentInstance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EquipmentInstance value)?  $default,){
final _that = this;
switch (_that) {
case _EquipmentInstance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int equipmentId,  int? vehicleId,  int? compartmentId,  String? identifier,  String notes,  bool isActive,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EquipmentInstance() when $default != null:
return $default(_that.id,_that.equipmentId,_that.vehicleId,_that.compartmentId,_that.identifier,_that.notes,_that.isActive,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int equipmentId,  int? vehicleId,  int? compartmentId,  String? identifier,  String notes,  bool isActive,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _EquipmentInstance():
return $default(_that.id,_that.equipmentId,_that.vehicleId,_that.compartmentId,_that.identifier,_that.notes,_that.isActive,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int equipmentId,  int? vehicleId,  int? compartmentId,  String? identifier,  String notes,  bool isActive,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _EquipmentInstance() when $default != null:
return $default(_that.id,_that.equipmentId,_that.vehicleId,_that.compartmentId,_that.identifier,_that.notes,_that.isActive,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _EquipmentInstance implements EquipmentInstance {
  const _EquipmentInstance({required this.id, required this.equipmentId, this.vehicleId, this.compartmentId, this.identifier, this.notes = '', this.isActive = true, required this.updatedAt});
  

@override final  int id;
@override final  int equipmentId;
@override final  int? vehicleId;
@override final  int? compartmentId;
@override final  String? identifier;
@override@JsonKey() final  String notes;
@override@JsonKey() final  bool isActive;
@override final  DateTime updatedAt;

/// Create a copy of EquipmentInstance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EquipmentInstanceCopyWith<_EquipmentInstance> get copyWith => __$EquipmentInstanceCopyWithImpl<_EquipmentInstance>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EquipmentInstance&&(identical(other.id, id) || other.id == id)&&(identical(other.equipmentId, equipmentId) || other.equipmentId == equipmentId)&&(identical(other.vehicleId, vehicleId) || other.vehicleId == vehicleId)&&(identical(other.compartmentId, compartmentId) || other.compartmentId == compartmentId)&&(identical(other.identifier, identifier) || other.identifier == identifier)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,equipmentId,vehicleId,compartmentId,identifier,notes,isActive,updatedAt);

@override
String toString() {
  return 'EquipmentInstance(id: $id, equipmentId: $equipmentId, vehicleId: $vehicleId, compartmentId: $compartmentId, identifier: $identifier, notes: $notes, isActive: $isActive, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$EquipmentInstanceCopyWith<$Res> implements $EquipmentInstanceCopyWith<$Res> {
  factory _$EquipmentInstanceCopyWith(_EquipmentInstance value, $Res Function(_EquipmentInstance) _then) = __$EquipmentInstanceCopyWithImpl;
@override @useResult
$Res call({
 int id, int equipmentId, int? vehicleId, int? compartmentId, String? identifier, String notes, bool isActive, DateTime updatedAt
});




}
/// @nodoc
class __$EquipmentInstanceCopyWithImpl<$Res>
    implements _$EquipmentInstanceCopyWith<$Res> {
  __$EquipmentInstanceCopyWithImpl(this._self, this._then);

  final _EquipmentInstance _self;
  final $Res Function(_EquipmentInstance) _then;

/// Create a copy of EquipmentInstance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? equipmentId = null,Object? vehicleId = freezed,Object? compartmentId = freezed,Object? identifier = freezed,Object? notes = null,Object? isActive = null,Object? updatedAt = null,}) {
  return _then(_EquipmentInstance(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,equipmentId: null == equipmentId ? _self.equipmentId : equipmentId // ignore: cast_nullable_to_non_nullable
as int,vehicleId: freezed == vehicleId ? _self.vehicleId : vehicleId // ignore: cast_nullable_to_non_nullable
as int?,compartmentId: freezed == compartmentId ? _self.compartmentId : compartmentId // ignore: cast_nullable_to_non_nullable
as int?,identifier: freezed == identifier ? _self.identifier : identifier // ignore: cast_nullable_to_non_nullable
as String?,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
