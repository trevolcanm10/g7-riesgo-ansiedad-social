
import '../../../core/constants.dart';
import '../../models/apoyo_academico_model.dart';
import '../../../domain/entities/apoyo_academico.dart';
import 'api_service.dart';
class ApoyoRemoteDataSource {
 final ApiService api; static const _timeout=Duration(seconds:120);
 ApoyoRemoteDataSource(this.api);
 String _query(String base,Map<String,String> params)=>Uri.parse(base).replace(queryParameters:params).toString();
 Future<AcademicResourcePage> catalog({required int offset,required int limit,String? type,String? courseCode}) async {
  final q=<String,String>{'offset':'$offset','limit':'$limit'};
  if(type!=null&&type.isNotEmpty)q['type']=type;
  if(courseCode!=null&&courseCode.isNotEmpty)q['courseCode']=courseCode;
  return AcademicResourcePageModel.fromJson(await api.get(_query(AppConstants.apoyoResources,q),timeout:_timeout));
 }
 Future<AcademicResource> resource(int id) async=>AcademicResourceModel.fromJson(await api.get(AppConstants.apoyoResource(id),timeout:_timeout));
 Future<AcademicPreferences> preferences() async=>AcademicPreferencesModel.fromJson(await api.get(AppConstants.apoyoPreferences,timeout:_timeout));
 Future<AcademicPreferences> savePreferences(AcademicPreferences p) async=>AcademicPreferencesModel.fromJson(await api.put(AppConstants.apoyoPreferences,body:AcademicPreferencesModel.toRequestBody(p),timeout:_timeout));
 Future<List<AcademicRecommendation>> recommendations({int limit=10}) async {
  final j=await api.get(_query(AppConstants.apoyoRecommendations,{'limit':'$limit'}),timeout:_timeout);
  return (j['items'] as List? ?? const []).whereType<Map<String,dynamic>>().map(AcademicRecommendationModel.fromJson).toList();
 }
 Future<List<WorkshopEnrollment>> enrollments() async {
  final j=await api.get(AppConstants.apoyoEnrollments,timeout:_timeout);
  return (j['items'] as List? ?? const []).whereType<Map<String,dynamic>>().map(WorkshopEnrollmentModel.fromJson).toList();
 }
 Future<void> recordInteraction(int id,String type) async { await api.post(AppConstants.apoyoInteractions,timeout:_timeout,expectedStatus:201,body:{'resourceId':id,'eventType':type}); }
 Future<void> enroll(int id) async { await api.post(AppConstants.apoyoWorkshopEnroll(id),timeout:_timeout,expectedStatus:201); }
 Future<void> cancelEnrollment(int id) async { await api.delete(AppConstants.apoyoWorkshopEnroll(id),timeout:_timeout); }
}
