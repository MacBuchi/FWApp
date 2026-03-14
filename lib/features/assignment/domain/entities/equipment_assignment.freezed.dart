// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'equipment_assignment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$EquipmentAssignment {

 int get id; int get compartmentId; int get equipmentId; int get quantity; DateTime get updatedAt;
/// Create a copy of EquipmentAssignment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EquipmentAssignmentCopyWith<EquipmentAssignment> get copyWith => _$EquipmentAssignmentCopyWithImpl<EquipmentAssignment>(this as EquipmentAssignment, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EquipmentAssignment&&(identical(other.id, id) || other.id == id)&&(identical(other.compartmentId, compartmentId) || other.compartmentId == compartmentId)&&(identical(other.equipmentId, equipmentId) || other.equipmentId == equipmentId)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,compartmentId,equipmentId,quantity,updatedAt);

@override
String toString() {
  return 'EquipmentAssignment(id: $id, compartmentId: $compartmentId, equipmentId: $equipmentId, quantity: $quantity, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $EquipmentAssignmentCopyWith<$Res>  {
  factory $EquipmentAssignmentCopyWith(EquipmentAssignment value, $Res Function(EquipmentAssignment) _then) = _$EquipmentAssignmentCopyWithImpl;
@useResult
$Res call({
 int id, int compartmentId, int equipmentId, int quantity, DateTime updatedAt
});




}
/// @nodoc
class _$EquipmentAssignmentCopyWithImpl<$Res>
    implements $EquipmentAssignmentCopyWith<$Res> {
  _$EquipmentAssignmentCopyWithImpl(this._self, this._then);

  final EquipmentAssignment _self;
  final $Res Function(EquipmentAssignment) _then;

/// Create a copy of EquipmentAssignment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? compartmentId = null,Object? equipmentId = null,Object? quantity = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,compartmentId: null == compartmentId ? _self.compartmentId : compartmentId // ignore: cast_nullable_to_non_nullable
as int,equipmentId: null == equipmentId ? _self.equipmentId : equipmentId // ignore: cast_nullable_to_non_nullable
as int,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [EquipmentAssignment].
extension EquipmentAssignmentPatterns on EquipmentAssignment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EquipmentAssignment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EquipmentAssignment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EquipmentAssignment value)  $default,){
final _that = this;
switch (_that) {
case _EquipmentAssignment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EquipmentAssignment value)?  $default,){
final _that = this;
switch (_that) {
case _EquipmentAssignment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int compartmentId,  int equipmentId,  int quantity,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EquipmentAssignment() when $default != null:
return $default(_that.id,_that.compartmentId,_that.equipmentId,_that.quantity,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int compartmentId,  int equipmentId,  int quantity,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _EquipmentAssignment():
return $default(_that.id,_that.compartmentId,_that.equipmentId,_that.quantity,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int compartmentId,  int equipmentId,  int quantity,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _EquipmentAssignment() when $default != null:
return $default(_that.id,_that.compartmentId,_that.equipmentId,_that.quantity,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _EquipmentAssignment implements EquipmentAssignment {
  const _EquipmentAssignment({required this.id, required this.compartmentId, required this.equipmentId, required this.quantity, required this.updatedAt});
  

@override final  int id;
@override final  int compartmentId;
@override final  int equipmentId;
@override final  int quantity;
@override final  DateTime updatedAt;

/// Create a copy of EquipmentAssignment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EquipmentAssignmentCopyWith<_EquipmentAssignment> get copyWith => __$EquipmentAssignmentCopyWithImpl<_EquipmentAssignment>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EquipmentAssignment&&(identical(other.id, id) || other.id == id)&&(identical(other.compartmentId, compartmentId) || other.compartmentId == compartmentId)&&(identical(other.equipmentId, equipmentId) || other.equipmentId == equipmentId)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,compartmentId,equipmentId,quantity,updatedAt);

@override
String toString() {
  return 'EquipmentAssignment(id: $id, compartmentId: $compartmentId, equipmentId: $equipmentId, quantity: $quantity, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$EquipmentAssignmentCopyWith<$Res> implements $EquipmentAssignmentCopyWith<$Res> {
  factory _$EquipmentAssignmentCopyWith(_EquipmentAssignment value, $Res Function(_EquipmentAssignment) _then) = __$EquipmentAssignmentCopyWithImpl;
@override @useResult
$Res call({
 int id, int compartmentId, int equipmentId, int quantity, DateTime updatedAt
});




}
/// @nodoc
class __$EquipmentAssignmentCopyWithImpl<$Res>
    implements _$EquipmentAssignmentCopyWith<$Res> {
  __$EquipmentAssignmentCopyWithImpl(this._self, this._then);

  final _EquipmentAssignment _self;
  final $Res Function(_EquipmentAssignment) _then;

/// Create a copy of EquipmentAssignment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? compartmentId = null,Object? equipmentId = null,Object? quantity = null,Object? updatedAt = null,}) {
  return _then(_EquipmentAssignment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,compartmentId: null == compartmentId ? _self.compartmentId : compartmentId // ignore: cast_nullable_to_non_nullable
as int,equipmentId: null == equipmentId ? _self.equipmentId : equipmentId // ignore: cast_nullable_to_non_nullable
as int,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
