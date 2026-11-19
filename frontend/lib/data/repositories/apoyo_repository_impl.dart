
import '../../domain/entities/apoyo_academico.dart';
import '../../domain/repositories/apoyo_repository.dart';
import '../datasources/remote/apoyo_remote_datasource.dart';
class ApoyoRepositoryImpl implements ApoyoRepository {
 final ApoyoRemoteDataSource source; ApoyoRepositoryImpl(this.source);
 @override Future<AcademicResourcePage> catalog({required int offset,required int limit,String? type,String? courseCode})=>source.catalog(offset:offset,limit:limit,type:type,courseCode:courseCode);
 @override Future<AcademicResource> resource(int id)=>source.resource(id);
 @override Future<AcademicPreferences> preferences()=>source.preferences();
 @override Future<AcademicPreferences> savePreferences(AcademicPreferences value)=>source.savePreferences(value);
 @override Future<List<AcademicRecommendation>> recommendations({int limit=10})=>source.recommendations(limit:limit);
 @override Future<List<WorkshopEnrollment>> enrollments()=>source.enrollments();
 @override Future<void> recordInteraction(int id,String eventType)=>source.recordInteraction(id,eventType);
 @override Future<void> enroll(int id)=>source.enroll(id);
 @override Future<void> cancelEnrollment(int id)=>source.cancelEnrollment(id);
}
