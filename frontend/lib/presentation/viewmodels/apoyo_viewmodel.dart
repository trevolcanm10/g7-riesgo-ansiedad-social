
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/datasources/remote/api_service.dart';
import '../../domain/entities/apoyo_academico.dart';
import '../../domain/repositories/apoyo_repository.dart';
class ApoyoViewModel extends ChangeNotifier {
 final ApoyoRepository repository; ApoyoViewModel(this.repository);
 List<AcademicResource> resources=[]; List<AcademicRecommendation> suggestions=[];
 List<WorkshopEnrollment> myEnrollments=[]; AcademicPreferences preferences=const AcademicPreferences();
 bool loadingCatalog=false,loadingRecommendations=false,loadingEnrollments=false,loadingPreferences=false,savingPreferences=false;
 String? catalogError,recommendationsError,enrollmentsError,preferencesError,resourceError,actionError;
 int _offset=0,_total=0; static const int _pageSize=20; String? _type,_course;
 bool get hasMore=>resources.length<_total;
 void clearSession(){resources=[];suggestions=[];myEnrollments=[];preferences=const AcademicPreferences();catalogError=null;recommendationsError=null;enrollmentsError=null;preferencesError=null;resourceError=null;actionError=null;notifyListeners();}
 Future<AcademicResource?> loadResource(int id) async {
  resourceError=null;
  try { return await repository.resource(id); }
  catch(e) { resourceError=_message(e);notifyListeners();return null; }
 }
 Future<void> loadCatalog({bool more=false,String? type,String? courseCode}) async {
  if(loadingCatalog)return;
  if(!more){_offset=0;resources=[];_type=type;_course=courseCode;}
  loadingCatalog=true;catalogError=null;notifyListeners();
  try{final p=await repository.catalog(offset:_offset,limit:_pageSize,type:_type,courseCode:_course);resources=[...resources,...p.items];_offset=p.offset+p.items.length;_total=p.total;}
  catch(e){catalogError=_message(e);}finally{loadingCatalog=false;notifyListeners();}
 }
 Future<void> loadRecommendations() async {loadingRecommendations=true;recommendationsError=null;notifyListeners();try{suggestions=await repository.recommendations();}catch(e){recommendationsError=_message(e);}finally{loadingRecommendations=false;notifyListeners();}}
 Future<void> loadEnrollments() async {loadingEnrollments=true;enrollmentsError=null;notifyListeners();try{myEnrollments=await repository.enrollments();}catch(e){enrollmentsError=_message(e);}finally{loadingEnrollments=false;notifyListeners();}}
 Future<void> loadPreferences() async {loadingPreferences=true;preferencesError=null;notifyListeners();try{preferences=await repository.preferences();}catch(e){preferencesError=_message(e);}finally{loadingPreferences=false;notifyListeners();}}
 Future<bool> savePreferences(AcademicPreferences p) async {savingPreferences=true;preferencesError=null;notifyListeners();try{preferences=await repository.savePreferences(p);return true;}catch(e){preferencesError=_message(e);return false;}finally{savingPreferences=false;notifyListeners();}}
 Future<bool> enroll(int id) async {actionError=null;try{await repository.enroll(id);await Future.wait([loadCatalog(type:_type,courseCode:_course),loadEnrollments()]);return true;}catch(e){actionError=_message(e);notifyListeners();return false;}}
 Future<bool> cancelEnrollment(int id) async {actionError=null;try{await repository.cancelEnrollment(id);await Future.wait([loadCatalog(type:_type,courseCode:_course),loadEnrollments()]);return true;}catch(e){actionError=_message(e);enrollmentsError=actionError;notifyListeners();return false;}}
 Future<void> recordInteraction(int id,String type) async {try{await repository.recordInteraction(id,type);}catch(_){/* Non-blocking feedback event. */}}
 bool isEnrolled(int id)=>myEnrollments.any((e)=>e.resourceId==id);
 String _message(Object error){
  if(error is ApiException){if(error.statusCode==401)return 'Tu sesión venció. Vuelve a iniciar sesión.';if(error.statusCode==403)return 'Tu cuenta no tiene acceso a esta función.';
   if(error.statusCode==409)return error.mensaje.isNotEmpty?error.mensaje:'La actividad cambió o ya no tiene cupos disponibles.';
   if(error.statusCode>=500)return 'El servicio no está disponible ahora. Intenta de nuevo.';return error.mensaje;}
  if(error is TimeoutException)return 'El servicio está tardando en iniciar. Reintenta en un momento.';
  return 'No se pudo conectar con Apoyo Académico. Revisa tu conexión e inténtalo de nuevo.';
 }
}
