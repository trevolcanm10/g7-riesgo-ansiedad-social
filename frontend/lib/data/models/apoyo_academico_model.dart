
import '../../domain/entities/apoyo_academico.dart';

int _asInt(dynamic value,String field) {
 if(value is num)return value.toInt();
 throw FormatException('La respuesta no contiene un $field válido.');
}
DateTime? _asDate(dynamic value) =>
 value is String&&value.isNotEmpty?DateTime.tryParse(value):null;
List<String> _asStrings(dynamic value) =>
 value is List?value.whereType<String>().toList():<String>[];

class AcademicResourceModel extends AcademicResource {
 const AcademicResourceModel({required super.id,required super.type,required super.title,
  required super.description,super.tags,super.courseCodes,super.modality,super.location,super.url,
  super.startAt,super.endAt,super.capacity,super.availableSeats});
 factory AcademicResourceModel.fromJson(Map<String,dynamic> json)=>AcademicResourceModel(
  id:_asInt(json['id'],'id'),type:json['type'] as String? ?? '',
  title:json['title'] as String? ?? '',description:json['description'] as String? ?? '',
  tags:_asStrings(json['tags']),courseCodes:_asStrings(json['courseCodes']),
  modality:json['modality'] as String?,location:json['location'] as String?,url:json['url'] as String?,
  startAt:_asDate(json['startAt']),endAt:_asDate(json['endAt']),
  capacity:(json['capacity'] as num?)?.toInt(),availableSeats:(json['availableSeats'] as num?)?.toInt());
}
class AcademicResourcePageModel {
 static AcademicResourcePage fromJson(Map<String,dynamic> json) {
  final page=json['pagination'] as Map<String,dynamic>? ?? {};
  final items=(json['items'] as List? ?? const [])
   .whereType<Map<String,dynamic>>().map(AcademicResourceModel.fromJson).toList();
  return AcademicResourcePage(items,(page['limit'] as num?)?.toInt() ?? 20,
   (page['offset'] as num?)?.toInt() ?? 0,(page['total'] as num?)?.toInt() ?? 0);
 }
}
class AvailabilitySlotModel extends AvailabilitySlot {
 const AvailabilitySlotModel(super.weekday,super.startTime,super.endTime);
 factory AvailabilitySlotModel.fromJson(Map<String,dynamic> json)=>AvailabilitySlotModel(
  _asInt(json['weekday'],'weekday'),json['startTime'] as String,json['endTime'] as String);
 Map<String,dynamic> toJson()=>{'weekday':weekday,'startTime':startTime,'endTime':endTime};
}
class AcademicPreferencesModel extends AcademicPreferences {
 const AcademicPreferencesModel({super.interests,super.courseCodes,super.availableSlots,
  super.preferredModalities,super.timeZone});
 factory AcademicPreferencesModel.fromJson(Map<String,dynamic> json)=>AcademicPreferencesModel(
  interests:_asStrings(json['interests']),courseCodes:_asStrings(json['courseCodes']),
  availableSlots:(json['availableSlots'] as List? ?? const [])
   .whereType<Map<String,dynamic>>().map(AvailabilitySlotModel.fromJson).toList(),
  preferredModalities:_asStrings(json['preferredModalities']),
  timeZone:json['timeZone'] as String? ?? 'America/Lima');
 static Map<String,dynamic> toRequestBody(AcademicPreferences p)=>{
  'interests':p.interests,'courseCodes':p.courseCodes,
  'availableSlots':p.availableSlots.map((e)=>{'weekday':e.weekday,'startTime':e.startTime,'endTime':e.endTime}).toList(),
  'preferredModalities':p.preferredModalities,'timeZone':p.timeZone};
}
class AcademicRecommendationModel {
 static AcademicRecommendation fromJson(Map<String,dynamic> json)=>AcademicRecommendation(
  AcademicResourceModel.fromJson(json['resource'] as Map<String,dynamic>),_asStrings(json['reasons']));
}
class WorkshopEnrollmentModel {
 static WorkshopEnrollment fromJson(Map<String,dynamic> json) {
  final workshop=json['workshop'] as Map<String,dynamic>? ?? {};
  return WorkshopEnrollment(resourceId:_asInt(json['resourceId'],'resourceId'),
   title:workshop['title'] as String? ?? '',description:workshop['description'] as String? ?? '',
   status:json['status'] as String? ?? 'ACTIVE',modality:workshop['modality'] as String?,
   location:workshop['location'] as String?,startAt:_asDate(workshop['startAt']),endAt:_asDate(workshop['endAt']),
   capacity:(workshop['capacity'] as num?)?.toInt(),availableSeats:(workshop['availableSeats'] as num?)?.toInt());
 }
}
