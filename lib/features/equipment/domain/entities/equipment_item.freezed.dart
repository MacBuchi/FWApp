// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'equipment_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$EquipmentItem {

 int get id; String get name; String? get shortName; List<String> get equipmentFunctions; List<String> get deploymentScenarios; String get description; String? get imagePath; String? get trainingUrl; String? get libraryEquipmentId; bool get isCustom; Map<String, dynamic> get extraAttributes; List<String> get trainingQuestions; List<String> get typicalUse; DateTime get updatedAt;
/// Create a copy of EquipmentItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EquipmentItemCopyWith<EquipmentItem> get copyWith => _$EquipmentItemCopyWithImpl<EquipmentItem>(this as EquipmentItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EquipmentItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.shortName, shortName) || other.shortName == shortName)&&const DeepCollectionEquality().equals(other.equipmentFunctions, equipmentFunctions)&&const DeepCollectionEquality().equals(other.deploymentScenarios, deploymentScenarios)&&(identical(other.description, description) || other.description == description)&&(identical(other.imagePath, imagePath) || other.imagePath == imagePath)&&(identical(other.trainingUrl, trainingUrl) || other.trainingUrl == trainingUrl)&&(identical(other.libraryEquipmentId, libraryEquipmentId) || other.libraryEquipmentId == libraryEquipmentId)&&(identical(other.isCustom, isCustom) || other.isCustom == isCustom)&&const DeepCollectionEquality().equals(other.extraAttributes, extraAttributes)&&const DeepCollectionEquality().equals(other.trainingQuestions, trainingQuestions)&&const DeepCollectionEquality().equals(other.typicalUse, typicalUse)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,shortName,const DeepCollectionEquality().hash(equipmentFunctions),const DeepCollectionEquality().hash(deploymentScenarios),description,imagePath,trainingUrl,libraryEquipmentId,isCustom,const DeepCollectionEquality().hash(extraAttributes),const DeepCollectionEquality().hash(trainingQuestions),const DeepCollectionEquality().hash(typicalUse),updatedAt);

@override
String toString() {
  return 'EquipmentItem(id: $id, name: $name, shortName: $shortName, equipmentFunctions: $equipmentFunctions, deploymentScenarios: $deploymentScenarios, description: $description, imagePath: $imagePath, trainingUrl: $trainingUrl, libraryEquipmentId: $libraryEquipmentId, isCustom: $isCustom, extraAttributes: $extraAttributes, trainingQuestions: $trainingQuestions, typicalUse: $typicalUse, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $EquipmentItemCopyWith<$Res>  {
  factory $EquipmentItemCopyWith(EquipmentItem value, $Res Function(EquipmentItem) _then) = _$EquipmentItemCopyWithImpl;
@useResult
$Res call({
 int id, String name, String? shortName, List<String> equipmentFunctions, List<String> deploymentScenarios, String description, String? imagePath, String? trainingUrl, String? libraryEquipmentId, bool isCustom, Map<String, dynamic> extraAttributes, List<String> trainingQuestions, List<String> typicalUse, DateTime updatedAt
});




}
/// @nodoc
class _$EquipmentItemCopyWithImpl<$Res>
    implements $EquipmentItemCopyWith<$Res> {
  _$EquipmentItemCopyWithImpl(this._self, this._then);

  final EquipmentItem _self;
  final $Res Function(EquipmentItem) _then;

/// Create a copy of EquipmentItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? shortName = freezed,Object? equipmentFunctions = null,Object? deploymentScenarios = null,Object? description = null,Object? imagePath = freezed,Object? trainingUrl = freezed,Object? libraryEquipmentId = freezed,Object? isCustom = null,Object? extraAttributes = null,Object? trainingQuestions = null,Object? typicalUse = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,shortName: freezed == shortName ? _self.shortName : shortName // ignore: cast_nullable_to_non_nullable
as String?,equipmentFunctions: null == equipmentFunctions ? _self.equipmentFunctions : equipmentFunctions // ignore: cast_nullable_to_non_nullable
as List<String>,deploymentScenarios: null == deploymentScenarios ? _self.deploymentScenarios : deploymentScenarios // ignore: cast_nullable_to_non_nullable
as List<String>,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,imagePath: freezed == imagePath ? _self.imagePath : imagePath // ignore: cast_nullable_to_non_nullable
as String?,trainingUrl: freezed == trainingUrl ? _self.trainingUrl : trainingUrl // ignore: cast_nullable_to_non_nullable
as String?,libraryEquipmentId: freezed == libraryEquipmentId ? _self.libraryEquipmentId : libraryEquipmentId // ignore: cast_nullable_to_non_nullable
as String?,isCustom: null == isCustom ? _self.isCustom : isCustom // ignore: cast_nullable_to_non_nullable
as bool,extraAttributes: null == extraAttributes ? _self.extraAttributes : extraAttributes // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,trainingQuestions: null == trainingQuestions ? _self.trainingQuestions : trainingQuestions // ignore: cast_nullable_to_non_nullable
as List<String>,typicalUse: null == typicalUse ? _self.typicalUse : typicalUse // ignore: cast_nullable_to_non_nullable
as List<String>,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [EquipmentItem].
extension EquipmentItemPatterns on EquipmentItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EquipmentItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EquipmentItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EquipmentItem value)  $default,){
final _that = this;
switch (_that) {
case _EquipmentItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EquipmentItem value)?  $default,){
final _that = this;
switch (_that) {
case _EquipmentItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  String? shortName,  List<String> equipmentFunctions,  List<String> deploymentScenarios,  String description,  String? imagePath,  String? trainingUrl,  String? libraryEquipmentId,  bool isCustom,  Map<String, dynamic> extraAttributes,  List<String> trainingQuestions,  List<String> typicalUse,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EquipmentItem() when $default != null:
return $default(_that.id,_that.name,_that.shortName,_that.equipmentFunctions,_that.deploymentScenarios,_that.description,_that.imagePath,_that.trainingUrl,_that.libraryEquipmentId,_that.isCustom,_that.extraAttributes,_that.trainingQuestions,_that.typicalUse,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  String? shortName,  List<String> equipmentFunctions,  List<String> deploymentScenarios,  String description,  String? imagePath,  String? trainingUrl,  String? libraryEquipmentId,  bool isCustom,  Map<String, dynamic> extraAttributes,  List<String> trainingQuestions,  List<String> typicalUse,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _EquipmentItem():
return $default(_that.id,_that.name,_that.shortName,_that.equipmentFunctions,_that.deploymentScenarios,_that.description,_that.imagePath,_that.trainingUrl,_that.libraryEquipmentId,_that.isCustom,_that.extraAttributes,_that.trainingQuestions,_that.typicalUse,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  String? shortName,  List<String> equipmentFunctions,  List<String> deploymentScenarios,  String description,  String? imagePath,  String? trainingUrl,  String? libraryEquipmentId,  bool isCustom,  Map<String, dynamic> extraAttributes,  List<String> trainingQuestions,  List<String> typicalUse,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _EquipmentItem() when $default != null:
return $default(_that.id,_that.name,_that.shortName,_that.equipmentFunctions,_that.deploymentScenarios,_that.description,_that.imagePath,_that.trainingUrl,_that.libraryEquipmentId,_that.isCustom,_that.extraAttributes,_that.trainingQuestions,_that.typicalUse,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _EquipmentItem implements EquipmentItem {
  const _EquipmentItem({required this.id, required this.name, this.shortName, required final  List<String> equipmentFunctions, required final  List<String> deploymentScenarios, required this.description, this.imagePath, this.trainingUrl, this.libraryEquipmentId, required this.isCustom, required final  Map<String, dynamic> extraAttributes, final  List<String> trainingQuestions = const [], final  List<String> typicalUse = const [], required this.updatedAt}): _equipmentFunctions = equipmentFunctions,_deploymentScenarios = deploymentScenarios,_extraAttributes = extraAttributes,_trainingQuestions = trainingQuestions,_typicalUse = typicalUse;
  

@override final  int id;
@override final  String name;
@override final  String? shortName;
 final  List<String> _equipmentFunctions;
@override List<String> get equipmentFunctions {
  if (_equipmentFunctions is EqualUnmodifiableListView) return _equipmentFunctions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_equipmentFunctions);
}

 final  List<String> _deploymentScenarios;
@override List<String> get deploymentScenarios {
  if (_deploymentScenarios is EqualUnmodifiableListView) return _deploymentScenarios;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_deploymentScenarios);
}

@override final  String description;
@override final  String? imagePath;
@override final  String? trainingUrl;
@override final  String? libraryEquipmentId;
@override final  bool isCustom;
 final  Map<String, dynamic> _extraAttributes;
@override Map<String, dynamic> get extraAttributes {
  if (_extraAttributes is EqualUnmodifiableMapView) return _extraAttributes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extraAttributes);
}

 final  List<String> _trainingQuestions;
@override@JsonKey() List<String> get trainingQuestions {
  if (_trainingQuestions is EqualUnmodifiableListView) return _trainingQuestions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_trainingQuestions);
}

 final  List<String> _typicalUse;
@override@JsonKey() List<String> get typicalUse {
  if (_typicalUse is EqualUnmodifiableListView) return _typicalUse;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_typicalUse);
}

@override final  DateTime updatedAt;

/// Create a copy of EquipmentItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EquipmentItemCopyWith<_EquipmentItem> get copyWith => __$EquipmentItemCopyWithImpl<_EquipmentItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EquipmentItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.shortName, shortName) || other.shortName == shortName)&&const DeepCollectionEquality().equals(other._equipmentFunctions, _equipmentFunctions)&&const DeepCollectionEquality().equals(other._deploymentScenarios, _deploymentScenarios)&&(identical(other.description, description) || other.description == description)&&(identical(other.imagePath, imagePath) || other.imagePath == imagePath)&&(identical(other.trainingUrl, trainingUrl) || other.trainingUrl == trainingUrl)&&(identical(other.libraryEquipmentId, libraryEquipmentId) || other.libraryEquipmentId == libraryEquipmentId)&&(identical(other.isCustom, isCustom) || other.isCustom == isCustom)&&const DeepCollectionEquality().equals(other._extraAttributes, _extraAttributes)&&const DeepCollectionEquality().equals(other._trainingQuestions, _trainingQuestions)&&const DeepCollectionEquality().equals(other._typicalUse, _typicalUse)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,shortName,const DeepCollectionEquality().hash(_equipmentFunctions),const DeepCollectionEquality().hash(_deploymentScenarios),description,imagePath,trainingUrl,libraryEquipmentId,isCustom,const DeepCollectionEquality().hash(_extraAttributes),const DeepCollectionEquality().hash(_trainingQuestions),const DeepCollectionEquality().hash(_typicalUse),updatedAt);

@override
String toString() {
  return 'EquipmentItem(id: $id, name: $name, shortName: $shortName, equipmentFunctions: $equipmentFunctions, deploymentScenarios: $deploymentScenarios, description: $description, imagePath: $imagePath, trainingUrl: $trainingUrl, libraryEquipmentId: $libraryEquipmentId, isCustom: $isCustom, extraAttributes: $extraAttributes, trainingQuestions: $trainingQuestions, typicalUse: $typicalUse, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$EquipmentItemCopyWith<$Res> implements $EquipmentItemCopyWith<$Res> {
  factory _$EquipmentItemCopyWith(_EquipmentItem value, $Res Function(_EquipmentItem) _then) = __$EquipmentItemCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, String? shortName, List<String> equipmentFunctions, List<String> deploymentScenarios, String description, String? imagePath, String? trainingUrl, String? libraryEquipmentId, bool isCustom, Map<String, dynamic> extraAttributes, List<String> trainingQuestions, List<String> typicalUse, DateTime updatedAt
});




}
/// @nodoc
class __$EquipmentItemCopyWithImpl<$Res>
    implements _$EquipmentItemCopyWith<$Res> {
  __$EquipmentItemCopyWithImpl(this._self, this._then);

  final _EquipmentItem _self;
  final $Res Function(_EquipmentItem) _then;

/// Create a copy of EquipmentItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? shortName = freezed,Object? equipmentFunctions = null,Object? deploymentScenarios = null,Object? description = null,Object? imagePath = freezed,Object? trainingUrl = freezed,Object? libraryEquipmentId = freezed,Object? isCustom = null,Object? extraAttributes = null,Object? trainingQuestions = null,Object? typicalUse = null,Object? updatedAt = null,}) {
  return _then(_EquipmentItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,shortName: freezed == shortName ? _self.shortName : shortName // ignore: cast_nullable_to_non_nullable
as String?,equipmentFunctions: null == equipmentFunctions ? _self._equipmentFunctions : equipmentFunctions // ignore: cast_nullable_to_non_nullable
as List<String>,deploymentScenarios: null == deploymentScenarios ? _self._deploymentScenarios : deploymentScenarios // ignore: cast_nullable_to_non_nullable
as List<String>,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,imagePath: freezed == imagePath ? _self.imagePath : imagePath // ignore: cast_nullable_to_non_nullable
as String?,trainingUrl: freezed == trainingUrl ? _self.trainingUrl : trainingUrl // ignore: cast_nullable_to_non_nullable
as String?,libraryEquipmentId: freezed == libraryEquipmentId ? _self.libraryEquipmentId : libraryEquipmentId // ignore: cast_nullable_to_non_nullable
as String?,isCustom: null == isCustom ? _self.isCustom : isCustom // ignore: cast_nullable_to_non_nullable
as bool,extraAttributes: null == extraAttributes ? _self._extraAttributes : extraAttributes // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,trainingQuestions: null == trainingQuestions ? _self._trainingQuestions : trainingQuestions // ignore: cast_nullable_to_non_nullable
as List<String>,typicalUse: null == typicalUse ? _self._typicalUse : typicalUse // ignore: cast_nullable_to_non_nullable
as List<String>,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
