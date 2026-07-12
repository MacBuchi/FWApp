// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'inspection_schedule.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$InspectionSchedule {

 int get id; int get instanceId; InspectionKind get kind; String get title; int? get intervalMonths; DateTime? get lastDoneAt; DateTime get dueAt; String get notes; DateTime get updatedAt;
/// Create a copy of InspectionSchedule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InspectionScheduleCopyWith<InspectionSchedule> get copyWith => _$InspectionScheduleCopyWithImpl<InspectionSchedule>(this as InspectionSchedule, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InspectionSchedule&&(identical(other.id, id) || other.id == id)&&(identical(other.instanceId, instanceId) || other.instanceId == instanceId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.title, title) || other.title == title)&&(identical(other.intervalMonths, intervalMonths) || other.intervalMonths == intervalMonths)&&(identical(other.lastDoneAt, lastDoneAt) || other.lastDoneAt == lastDoneAt)&&(identical(other.dueAt, dueAt) || other.dueAt == dueAt)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,instanceId,kind,title,intervalMonths,lastDoneAt,dueAt,notes,updatedAt);

@override
String toString() {
  return 'InspectionSchedule(id: $id, instanceId: $instanceId, kind: $kind, title: $title, intervalMonths: $intervalMonths, lastDoneAt: $lastDoneAt, dueAt: $dueAt, notes: $notes, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $InspectionScheduleCopyWith<$Res>  {
  factory $InspectionScheduleCopyWith(InspectionSchedule value, $Res Function(InspectionSchedule) _then) = _$InspectionScheduleCopyWithImpl;
@useResult
$Res call({
 int id, int instanceId, InspectionKind kind, String title, int? intervalMonths, DateTime? lastDoneAt, DateTime dueAt, String notes, DateTime updatedAt
});




}
/// @nodoc
class _$InspectionScheduleCopyWithImpl<$Res>
    implements $InspectionScheduleCopyWith<$Res> {
  _$InspectionScheduleCopyWithImpl(this._self, this._then);

  final InspectionSchedule _self;
  final $Res Function(InspectionSchedule) _then;

/// Create a copy of InspectionSchedule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? instanceId = null,Object? kind = null,Object? title = null,Object? intervalMonths = freezed,Object? lastDoneAt = freezed,Object? dueAt = null,Object? notes = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,instanceId: null == instanceId ? _self.instanceId : instanceId // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as InspectionKind,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,intervalMonths: freezed == intervalMonths ? _self.intervalMonths : intervalMonths // ignore: cast_nullable_to_non_nullable
as int?,lastDoneAt: freezed == lastDoneAt ? _self.lastDoneAt : lastDoneAt // ignore: cast_nullable_to_non_nullable
as DateTime?,dueAt: null == dueAt ? _self.dueAt : dueAt // ignore: cast_nullable_to_non_nullable
as DateTime,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [InspectionSchedule].
extension InspectionSchedulePatterns on InspectionSchedule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InspectionSchedule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InspectionSchedule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InspectionSchedule value)  $default,){
final _that = this;
switch (_that) {
case _InspectionSchedule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InspectionSchedule value)?  $default,){
final _that = this;
switch (_that) {
case _InspectionSchedule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int instanceId,  InspectionKind kind,  String title,  int? intervalMonths,  DateTime? lastDoneAt,  DateTime dueAt,  String notes,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InspectionSchedule() when $default != null:
return $default(_that.id,_that.instanceId,_that.kind,_that.title,_that.intervalMonths,_that.lastDoneAt,_that.dueAt,_that.notes,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int instanceId,  InspectionKind kind,  String title,  int? intervalMonths,  DateTime? lastDoneAt,  DateTime dueAt,  String notes,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _InspectionSchedule():
return $default(_that.id,_that.instanceId,_that.kind,_that.title,_that.intervalMonths,_that.lastDoneAt,_that.dueAt,_that.notes,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int instanceId,  InspectionKind kind,  String title,  int? intervalMonths,  DateTime? lastDoneAt,  DateTime dueAt,  String notes,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _InspectionSchedule() when $default != null:
return $default(_that.id,_that.instanceId,_that.kind,_that.title,_that.intervalMonths,_that.lastDoneAt,_that.dueAt,_that.notes,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _InspectionSchedule extends InspectionSchedule {
  const _InspectionSchedule({required this.id, required this.instanceId, required this.kind, required this.title, this.intervalMonths, this.lastDoneAt, required this.dueAt, this.notes = '', required this.updatedAt}): super._();
  

@override final  int id;
@override final  int instanceId;
@override final  InspectionKind kind;
@override final  String title;
@override final  int? intervalMonths;
@override final  DateTime? lastDoneAt;
@override final  DateTime dueAt;
@override@JsonKey() final  String notes;
@override final  DateTime updatedAt;

/// Create a copy of InspectionSchedule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InspectionScheduleCopyWith<_InspectionSchedule> get copyWith => __$InspectionScheduleCopyWithImpl<_InspectionSchedule>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InspectionSchedule&&(identical(other.id, id) || other.id == id)&&(identical(other.instanceId, instanceId) || other.instanceId == instanceId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.title, title) || other.title == title)&&(identical(other.intervalMonths, intervalMonths) || other.intervalMonths == intervalMonths)&&(identical(other.lastDoneAt, lastDoneAt) || other.lastDoneAt == lastDoneAt)&&(identical(other.dueAt, dueAt) || other.dueAt == dueAt)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,instanceId,kind,title,intervalMonths,lastDoneAt,dueAt,notes,updatedAt);

@override
String toString() {
  return 'InspectionSchedule(id: $id, instanceId: $instanceId, kind: $kind, title: $title, intervalMonths: $intervalMonths, lastDoneAt: $lastDoneAt, dueAt: $dueAt, notes: $notes, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$InspectionScheduleCopyWith<$Res> implements $InspectionScheduleCopyWith<$Res> {
  factory _$InspectionScheduleCopyWith(_InspectionSchedule value, $Res Function(_InspectionSchedule) _then) = __$InspectionScheduleCopyWithImpl;
@override @useResult
$Res call({
 int id, int instanceId, InspectionKind kind, String title, int? intervalMonths, DateTime? lastDoneAt, DateTime dueAt, String notes, DateTime updatedAt
});




}
/// @nodoc
class __$InspectionScheduleCopyWithImpl<$Res>
    implements _$InspectionScheduleCopyWith<$Res> {
  __$InspectionScheduleCopyWithImpl(this._self, this._then);

  final _InspectionSchedule _self;
  final $Res Function(_InspectionSchedule) _then;

/// Create a copy of InspectionSchedule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? instanceId = null,Object? kind = null,Object? title = null,Object? intervalMonths = freezed,Object? lastDoneAt = freezed,Object? dueAt = null,Object? notes = null,Object? updatedAt = null,}) {
  return _then(_InspectionSchedule(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,instanceId: null == instanceId ? _self.instanceId : instanceId // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as InspectionKind,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,intervalMonths: freezed == intervalMonths ? _self.intervalMonths : intervalMonths // ignore: cast_nullable_to_non_nullable
as int?,lastDoneAt: freezed == lastDoneAt ? _self.lastDoneAt : lastDoneAt // ignore: cast_nullable_to_non_nullable
as DateTime?,dueAt: null == dueAt ? _self.dueAt : dueAt // ignore: cast_nullable_to_non_nullable
as DateTime,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
mixin _$InspectionLogEntry {

 int get id; int get scheduleId; DateTime get doneAt; String get doneBy; String get note;
/// Create a copy of InspectionLogEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InspectionLogEntryCopyWith<InspectionLogEntry> get copyWith => _$InspectionLogEntryCopyWithImpl<InspectionLogEntry>(this as InspectionLogEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InspectionLogEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.scheduleId, scheduleId) || other.scheduleId == scheduleId)&&(identical(other.doneAt, doneAt) || other.doneAt == doneAt)&&(identical(other.doneBy, doneBy) || other.doneBy == doneBy)&&(identical(other.note, note) || other.note == note));
}


@override
int get hashCode => Object.hash(runtimeType,id,scheduleId,doneAt,doneBy,note);

@override
String toString() {
  return 'InspectionLogEntry(id: $id, scheduleId: $scheduleId, doneAt: $doneAt, doneBy: $doneBy, note: $note)';
}


}

/// @nodoc
abstract mixin class $InspectionLogEntryCopyWith<$Res>  {
  factory $InspectionLogEntryCopyWith(InspectionLogEntry value, $Res Function(InspectionLogEntry) _then) = _$InspectionLogEntryCopyWithImpl;
@useResult
$Res call({
 int id, int scheduleId, DateTime doneAt, String doneBy, String note
});




}
/// @nodoc
class _$InspectionLogEntryCopyWithImpl<$Res>
    implements $InspectionLogEntryCopyWith<$Res> {
  _$InspectionLogEntryCopyWithImpl(this._self, this._then);

  final InspectionLogEntry _self;
  final $Res Function(InspectionLogEntry) _then;

/// Create a copy of InspectionLogEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? scheduleId = null,Object? doneAt = null,Object? doneBy = null,Object? note = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,scheduleId: null == scheduleId ? _self.scheduleId : scheduleId // ignore: cast_nullable_to_non_nullable
as int,doneAt: null == doneAt ? _self.doneAt : doneAt // ignore: cast_nullable_to_non_nullable
as DateTime,doneBy: null == doneBy ? _self.doneBy : doneBy // ignore: cast_nullable_to_non_nullable
as String,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [InspectionLogEntry].
extension InspectionLogEntryPatterns on InspectionLogEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InspectionLogEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InspectionLogEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InspectionLogEntry value)  $default,){
final _that = this;
switch (_that) {
case _InspectionLogEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InspectionLogEntry value)?  $default,){
final _that = this;
switch (_that) {
case _InspectionLogEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int scheduleId,  DateTime doneAt,  String doneBy,  String note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InspectionLogEntry() when $default != null:
return $default(_that.id,_that.scheduleId,_that.doneAt,_that.doneBy,_that.note);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int scheduleId,  DateTime doneAt,  String doneBy,  String note)  $default,) {final _that = this;
switch (_that) {
case _InspectionLogEntry():
return $default(_that.id,_that.scheduleId,_that.doneAt,_that.doneBy,_that.note);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int scheduleId,  DateTime doneAt,  String doneBy,  String note)?  $default,) {final _that = this;
switch (_that) {
case _InspectionLogEntry() when $default != null:
return $default(_that.id,_that.scheduleId,_that.doneAt,_that.doneBy,_that.note);case _:
  return null;

}
}

}

/// @nodoc


class _InspectionLogEntry implements InspectionLogEntry {
  const _InspectionLogEntry({required this.id, required this.scheduleId, required this.doneAt, this.doneBy = '', this.note = ''});
  

@override final  int id;
@override final  int scheduleId;
@override final  DateTime doneAt;
@override@JsonKey() final  String doneBy;
@override@JsonKey() final  String note;

/// Create a copy of InspectionLogEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InspectionLogEntryCopyWith<_InspectionLogEntry> get copyWith => __$InspectionLogEntryCopyWithImpl<_InspectionLogEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InspectionLogEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.scheduleId, scheduleId) || other.scheduleId == scheduleId)&&(identical(other.doneAt, doneAt) || other.doneAt == doneAt)&&(identical(other.doneBy, doneBy) || other.doneBy == doneBy)&&(identical(other.note, note) || other.note == note));
}


@override
int get hashCode => Object.hash(runtimeType,id,scheduleId,doneAt,doneBy,note);

@override
String toString() {
  return 'InspectionLogEntry(id: $id, scheduleId: $scheduleId, doneAt: $doneAt, doneBy: $doneBy, note: $note)';
}


}

/// @nodoc
abstract mixin class _$InspectionLogEntryCopyWith<$Res> implements $InspectionLogEntryCopyWith<$Res> {
  factory _$InspectionLogEntryCopyWith(_InspectionLogEntry value, $Res Function(_InspectionLogEntry) _then) = __$InspectionLogEntryCopyWithImpl;
@override @useResult
$Res call({
 int id, int scheduleId, DateTime doneAt, String doneBy, String note
});




}
/// @nodoc
class __$InspectionLogEntryCopyWithImpl<$Res>
    implements _$InspectionLogEntryCopyWith<$Res> {
  __$InspectionLogEntryCopyWithImpl(this._self, this._then);

  final _InspectionLogEntry _self;
  final $Res Function(_InspectionLogEntry) _then;

/// Create a copy of InspectionLogEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? scheduleId = null,Object? doneAt = null,Object? doneBy = null,Object? note = null,}) {
  return _then(_InspectionLogEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,scheduleId: null == scheduleId ? _self.scheduleId : scheduleId // ignore: cast_nullable_to_non_nullable
as int,doneAt: null == doneAt ? _self.doneAt : doneAt // ignore: cast_nullable_to_non_nullable
as DateTime,doneBy: null == doneBy ? _self.doneBy : doneBy // ignore: cast_nullable_to_non_nullable
as String,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
