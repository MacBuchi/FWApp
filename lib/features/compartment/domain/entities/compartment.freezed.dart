// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'compartment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Compartment {

 int get id; int get vehicleId; String get label; int get position; int? get gridRow; int? get gridCol; int get gridColSpan; DateTime get updatedAt;
/// Create a copy of Compartment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompartmentCopyWith<Compartment> get copyWith => _$CompartmentCopyWithImpl<Compartment>(this as Compartment, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Compartment&&(identical(other.id, id) || other.id == id)&&(identical(other.vehicleId, vehicleId) || other.vehicleId == vehicleId)&&(identical(other.label, label) || other.label == label)&&(identical(other.position, position) || other.position == position)&&(identical(other.gridRow, gridRow) || other.gridRow == gridRow)&&(identical(other.gridCol, gridCol) || other.gridCol == gridCol)&&(identical(other.gridColSpan, gridColSpan) || other.gridColSpan == gridColSpan)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,vehicleId,label,position,gridRow,gridCol,gridColSpan,updatedAt);

@override
String toString() {
  return 'Compartment(id: $id, vehicleId: $vehicleId, label: $label, position: $position, gridRow: $gridRow, gridCol: $gridCol, gridColSpan: $gridColSpan, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $CompartmentCopyWith<$Res>  {
  factory $CompartmentCopyWith(Compartment value, $Res Function(Compartment) _then) = _$CompartmentCopyWithImpl;
@useResult
$Res call({
 int id, int vehicleId, String label, int position, int? gridRow, int? gridCol, int gridColSpan, DateTime updatedAt
});




}
/// @nodoc
class _$CompartmentCopyWithImpl<$Res>
    implements $CompartmentCopyWith<$Res> {
  _$CompartmentCopyWithImpl(this._self, this._then);

  final Compartment _self;
  final $Res Function(Compartment) _then;

/// Create a copy of Compartment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? vehicleId = null,Object? label = null,Object? position = null,Object? gridRow = freezed,Object? gridCol = freezed,Object? gridColSpan = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,vehicleId: null == vehicleId ? _self.vehicleId : vehicleId // ignore: cast_nullable_to_non_nullable
as int,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,gridRow: freezed == gridRow ? _self.gridRow : gridRow // ignore: cast_nullable_to_non_nullable
as int?,gridCol: freezed == gridCol ? _self.gridCol : gridCol // ignore: cast_nullable_to_non_nullable
as int?,gridColSpan: null == gridColSpan ? _self.gridColSpan : gridColSpan // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Compartment].
extension CompartmentPatterns on Compartment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Compartment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Compartment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Compartment value)  $default,){
final _that = this;
switch (_that) {
case _Compartment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Compartment value)?  $default,){
final _that = this;
switch (_that) {
case _Compartment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int vehicleId,  String label,  int position,  int? gridRow,  int? gridCol,  int gridColSpan,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Compartment() when $default != null:
return $default(_that.id,_that.vehicleId,_that.label,_that.position,_that.gridRow,_that.gridCol,_that.gridColSpan,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int vehicleId,  String label,  int position,  int? gridRow,  int? gridCol,  int gridColSpan,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Compartment():
return $default(_that.id,_that.vehicleId,_that.label,_that.position,_that.gridRow,_that.gridCol,_that.gridColSpan,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int vehicleId,  String label,  int position,  int? gridRow,  int? gridCol,  int gridColSpan,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Compartment() when $default != null:
return $default(_that.id,_that.vehicleId,_that.label,_that.position,_that.gridRow,_that.gridCol,_that.gridColSpan,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _Compartment implements Compartment {
  const _Compartment({required this.id, required this.vehicleId, required this.label, required this.position, this.gridRow, this.gridCol, required this.gridColSpan, required this.updatedAt});
  

@override final  int id;
@override final  int vehicleId;
@override final  String label;
@override final  int position;
@override final  int? gridRow;
@override final  int? gridCol;
@override final  int gridColSpan;
@override final  DateTime updatedAt;

/// Create a copy of Compartment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompartmentCopyWith<_Compartment> get copyWith => __$CompartmentCopyWithImpl<_Compartment>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Compartment&&(identical(other.id, id) || other.id == id)&&(identical(other.vehicleId, vehicleId) || other.vehicleId == vehicleId)&&(identical(other.label, label) || other.label == label)&&(identical(other.position, position) || other.position == position)&&(identical(other.gridRow, gridRow) || other.gridRow == gridRow)&&(identical(other.gridCol, gridCol) || other.gridCol == gridCol)&&(identical(other.gridColSpan, gridColSpan) || other.gridColSpan == gridColSpan)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,vehicleId,label,position,gridRow,gridCol,gridColSpan,updatedAt);

@override
String toString() {
  return 'Compartment(id: $id, vehicleId: $vehicleId, label: $label, position: $position, gridRow: $gridRow, gridCol: $gridCol, gridColSpan: $gridColSpan, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$CompartmentCopyWith<$Res> implements $CompartmentCopyWith<$Res> {
  factory _$CompartmentCopyWith(_Compartment value, $Res Function(_Compartment) _then) = __$CompartmentCopyWithImpl;
@override @useResult
$Res call({
 int id, int vehicleId, String label, int position, int? gridRow, int? gridCol, int gridColSpan, DateTime updatedAt
});




}
/// @nodoc
class __$CompartmentCopyWithImpl<$Res>
    implements _$CompartmentCopyWith<$Res> {
  __$CompartmentCopyWithImpl(this._self, this._then);

  final _Compartment _self;
  final $Res Function(_Compartment) _then;

/// Create a copy of Compartment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? vehicleId = null,Object? label = null,Object? position = null,Object? gridRow = freezed,Object? gridCol = freezed,Object? gridColSpan = null,Object? updatedAt = null,}) {
  return _then(_Compartment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,vehicleId: null == vehicleId ? _self.vehicleId : vehicleId // ignore: cast_nullable_to_non_nullable
as int,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,gridRow: freezed == gridRow ? _self.gridRow : gridRow // ignore: cast_nullable_to_non_nullable
as int?,gridCol: freezed == gridCol ? _self.gridCol : gridCol // ignore: cast_nullable_to_non_nullable
as int?,gridColSpan: null == gridColSpan ? _self.gridColSpan : gridColSpan // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
