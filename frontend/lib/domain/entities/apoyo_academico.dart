
class AcademicResource {
 final int id;
 final String type, title, description;
 final List<String> tags, courseCodes;
 final String? modality, location, url;
 final DateTime? startAt, endAt;
 final int? capacity, availableSeats;
 const AcademicResource({required this.id,required this.type,required this.title,required this.description,
  this.tags=const [],this.courseCodes=const [],this.modality,this.location,this.url,this.startAt,this.endAt,
  this.capacity,this.availableSeats});
}
class AcademicResourcePage {
 final List<AcademicResource> items;
 final int limit,offset,total;
 const AcademicResourcePage(this.items,this.limit,this.offset,this.total);
}
class AvailabilitySlot {
 final int weekday;
 final String startTime,endTime;
 const AvailabilitySlot(this.weekday,this.startTime,this.endTime);
}
class AcademicPreferences {
 final List<String> interests,courseCodes,preferredModalities;
 final List<AvailabilitySlot> availableSlots;
 final String timeZone;
 const AcademicPreferences({this.interests=const [],this.courseCodes=const [],this.availableSlots=const [],
  this.preferredModalities=const [],this.timeZone='America/Lima'});
}
class AcademicRecommendation {
 final AcademicResource resource;
 final List<String> reasons;
 const AcademicRecommendation(this.resource,this.reasons);
}
class WorkshopEnrollment {
 final int resourceId;
 final String title,description,status;
 final String? modality,location;
 final DateTime? startAt,endAt;
 final int? capacity,availableSeats;
 const WorkshopEnrollment({required this.resourceId,required this.title,required this.description,required this.status,
  this.modality,this.location,this.startAt,this.endAt,this.capacity,this.availableSeats});
}
