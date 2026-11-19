
import '../entities/apoyo_academico.dart';
abstract class ApoyoRepository {
 Future<AcademicResourcePage> catalog({required int offset,required int limit,String? type,String? courseCode});
 Future<AcademicResource> resource(int id);
 Future<AcademicPreferences> preferences();
 Future<AcademicPreferences> savePreferences(AcademicPreferences preferences);
 Future<List<AcademicRecommendation>> recommendations({int limit = 10});
 Future<List<WorkshopEnrollment>> enrollments();
 Future<void> recordInteraction(int resourceId,String eventType);
 Future<void> enroll(int resourceId);
 Future<void> cancelEnrollment(int resourceId);
}
